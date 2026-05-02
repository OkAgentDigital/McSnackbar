// DevToolsManager.swift
// Snackbar
//
// Created by DevStudio Integration
//

import Foundation
import Combine

/// Manages development tools configuration and synchronization with DevStudio
public class DevToolsManager: ObservableObject {
    public static let shared = DevToolsManager()
    
    @Published public private(set) var config: DevToolsConfig
    @Published public private(set) var isSyncing: Bool = false
    @Published public private(set) var lastSyncError: Error?
    
    private let devStudioConfigManager = DevStudioConfigManager.shared
    private let mcpClient = MCPClient.shared
    private var cancellables = Set<AnyCancellable>()
    
    private let snackbarDevToolsPath: String
    private let devStudioDevToolsPath: String
    
    public init() {
        // Initialize with default config
        self.config = DevToolsConfig.defaultConfig()
        
        // Set up paths
        self.snackbarDevToolsPath = ("~/.config/udos/snackbar-devtools.json" as NSString).expandingTildeInPath
        self.devStudioDevToolsPath = ("~/Code/DevStudio/configs/snackbar-devtools.json" as NSString).expandingTildeInPath
        
        // Load existing config if available
        self.loadConfig()
        
        // Set up MCP event listening
        self.setupMCPEventListening()
    }

    // MARK: - Configuration Management
    
    public func loadConfig() {
        do {
            let fileManager = FileManager.default
            
            // Try to load from Snackbar path first
            if fileManager.fileExists(atPath: snackbarDevToolsPath) {
                let data = try Data(contentsOf: URL(fileURLWithPath: snackbarDevToolsPath))
                let decodedConfig = try JSONDecoder().decode(DevToolsConfig.self, from: data)
                self.config = decodedConfig
                return
            }
            
            // Try to load from DevStudio path
            if fileManager.fileExists(atPath: devStudioDevToolsPath) {
                let data = try Data(contentsOf: URL(fileURLWithPath: devStudioDevToolsPath))
                let decodedConfig = try JSONDecoder().decode(DevToolsConfig.self, from: data)
                self.config = decodedConfig
                return
            }
            
        } catch {
            print("Error loading dev tools config: " + error.localizedDescription)
            // Keep default config if loading fails
        }
    }
    
    public func saveConfig(to path: String? = nil) throws {
        let targetPath = path ?? snackbarDevToolsPath
        let data = try JSONEncoder().encode(config)
        try data.write(to: URL(fileURLWithPath: targetPath), options: [.atomicWrite])
    }
    
    // MARK: - Synchronization
    
    public func syncWithDevStudio(completion: ((Result<Bool, Error>) -> Void)? = nil) {
        isSyncing = true
        lastSyncError = nil
        
        // Strategy:
        // 1. Try to load from DevStudio
        // 2. Merge with local changes
        // 3. Save back to both locations
        
        let devStudioPath = ("~/Code/DevStudio/configs/snackbar-devtools.json" as NSString).expandingTildeInPath
        
        do {
            // Load DevStudio config if it exists
            var devStudioConfig = config
            if FileManager.default.fileExists(atPath: devStudioPath) {
                let data = try Data(contentsOf: URL(fileURLWithPath: devStudioPath))
                devStudioConfig = try JSONDecoder().decode(DevToolsConfig.self, from: data)
            }
            
            // Merge configs (local changes take precedence for certain fields)
            let mergedConfig = mergeConfigs(devStudioConfig: devStudioConfig, localConfig: config)
            
            // Save to both locations
            try saveConfig(to: snackbarDevToolsPath)
            
            // Create DevStudio directory if it doesn't exist
            let devStudioDir = URL(fileURLWithPath: devStudioPath).deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: devStudioDir.path) {
                try FileManager.default.createDirectory(at: devStudioDir, withIntermediateDirectories: true)
            }
            
            try saveConfig(to: devStudioPath)
            
            // Update current config
            self.config = mergedConfig
            
            isSyncing = false
            completion?(.success(true))
            
        } catch {
            isSyncing = false
            lastSyncError = error
            completion?(.failure(error))
        }
    }
    
    private func mergeConfigs(devStudioConfig: DevToolsConfig, localConfig: DevToolsConfig) -> DevToolsConfig {
        var merged = devStudioConfig
        
        // Preserve local paths
        merged.paths = localConfig.paths
        
        // Merge agents (keep local enabled state)
        for (index, devAgent) in merged.agents.enumerated() {
            if let localAgentIndex = localConfig.agents.firstIndex(where: { $0.name == devAgent.name }) {
                merged.agents[index].isEnabled = localConfig.agents[localAgentIndex].isEnabled
            }
        }
        
        // Add any local agents that don't exist in DevStudio config
        for localAgent in localConfig.agents {
            if !merged.agents.contains(where: { $0.name == localAgent.name }) {
                merged.agents.append(localAgent)
            }
        }
        
        // Preserve local environment variables
        for (key, value) in localConfig.environment.variables {
            merged.environment.variables[key] = value
        }
        
        return merged
    }
    
    // MARK: - Tool Execution
    
    public func executeConsoleCommand(named name: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let command = config.getConsoleCommand(named: name) else {
            completion(.failure(NSError(domain: "DevTools", code: -1, userInfo: [NSLocalizedDescriptionKey: "Command not found"])))
            return
        }
        
        executeCommand(command.command, completion: completion)
    }
    
    public func executeCommand(_ command: String, completion: @escaping (Result<String, Error>) -> Void) {
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                process.waitUntilExit()
                
                if process.terminationStatus == 0 {
                    completion(.success(output))
                } else {
                    completion(.failure(NSError(domain: "DevTools", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: output])))
                }
            } else {
                completion(.failure(NSError(domain: "DevTools", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to read output"])))
            }
        } catch {
            completion(.failure(error))
        }
    }
    
    public func analyzeError(_ errorOutput: String) -> DevToolsConfig.ErrorPattern? {
        return config.getErrorPattern(forError: errorOutput)
    }
    
    // MARK: - Agent Management
    
    public func getEnabledAgents() -> [DevToolsConfig.AgentConfig] {
        return config.agents.filter { $0.isEnabled }
    }
    
    public func toggleAgent(named name: String) {
        if let index = config.agents.firstIndex(where: { $0.name == name }) {
            config.agents[index].isEnabled = !config.agents[index].isEnabled
        do {
            try saveConfig()
        } catch {
            print("Failed to save config: \(error)")
        }
        }
    }
    
    public func runAgent(named name: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let agent = getEnabledAgents().first(where: { $0.name == name }) else {
            completion(.failure(NSError(domain: "DevTools", code: -1, userInfo: [NSLocalizedDescriptionKey: "Agent not found or disabled"])))
            return
        }
        
        // Set up environment
        var environment = ProcessInfo.processInfo.environment
        for (key, value) in agent.environmentVariables {
            environment[key] = value
        }
        
        // Build full command
        var fullCommand = agent.executablePath
        if !agent.arguments.isEmpty {
            fullCommand += " " + agent.arguments.joined(separator: " ")
        }
        
        executeCommand(fullCommand, completion: completion)
    }
    
    // MARK: - MCP Integration
    
    private func setupMCPEventListening() {
        // Monitor MCP connection status
        mcpClient.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                
                if self.mcpClient.isConnected {
                    // Send current config to DevStudio when MCP connects
                    self.sendConfigViaMCP()
                }
            }
            .store(in: &cancellables)
    }
    
    private func sendConfigViaMCP() {
        guard mcpClient.isConnected else { return }
        
        do {
            let data = try JSONEncoder().encode(config)
            if let jsonString = String(data: data, encoding: .utf8) {
                let message: [String: Any] = [
                    "type": "devtools_config_update",
                    "client": "Snackbar",
                    "timestamp": Date().timeIntervalSince1970,
                    "config": jsonString
                ]
                
                if let messageData = try? JSONSerialization.data(withJSONObject: message, options: []),
                   let messageString = String(data: messageData, encoding: .utf8) {
                    
                    mcpClient.sendMessage(messageString) { result in
                        if case .failure(let error) = result {
                            print("Failed to send devtools config via MCP: " + error.localizedDescription)
                        }
                    }
                }
            }
        } catch {
            print("Failed to encode devtools config: " + error.localizedDescription)
        }
    }
    
    public func requestConfigFromDevStudio() {
        guard mcpClient.isConnected else {
            print("MCP not connected - cannot request config")
            return
        }
        
        let message: [String: Any] = [
            "type": "devtools_config_request",
            "client": "Snackbar",
            "timestamp": Date().timeIntervalSince1970
        ]
        
        do {
            let messageData = try JSONSerialization.data(withJSONObject: message, options: [])
            if let messageString = String(data: messageData, encoding: .utf8) {
                mcpClient.sendMessage(messageString)
            }
        } catch {
            print("Failed to create config request: " + error.localizedDescription)
        }
    }
    
    // MARK: - Utility Methods
    
    public func getEnvironmentSetupCommands() -> [String] {
        var commands: [String] = []
        
        // Add path extensions
        for path in config.environment.pathExtensions {
            commands.append("export PATH=\"$PATH:" + path + "\"")
        }
        
        // Add environment variables
        for (key, value) in config.environment.variables {
            commands.append("export " + key + "=\"" + value + "\"")
        }
        
        return commands
    }
    
    public func getXcodeBuildCommand(scheme: String, configuration: String = "Debug") -> String {
        var command = "xcodebuild -scheme " + scheme + " -configuration " + configuration
        
        // Add common flags
        for flag in config.compilation.commonFlags {
            command += " " + flag
        }
        
        // Add warning flags
        for flag in config.compilation.warningFlags {
            command += " " + flag
        }
        
        // Add framework search paths
        for path in config.compilation.frameworkSearchPaths {
            command += " -framework-search-paths " + path
        }
        
        return command
    }
}
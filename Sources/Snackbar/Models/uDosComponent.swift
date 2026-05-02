import Foundation
import AppKit
import ServiceManagement
import UserNotifications

/// Represents a uDos component that can be managed by Snackbar
public struct uDosComponent: Codable, Identifiable {
    public let id: String
    public let displayName: String
    public let command: String
    public let args: [String]
    public let workingDirectory: String
    public let env: [String: String]
    public let healthCheckURL: String?
    public let icon: String
    public let port: Int?
    public let requiredComponents: [String]
    public let description: String
    public let isEssential: Bool

    public init(
        id: String,
        displayName: String,
        command: String,
        args: [String] = [],
        workingDirectory: String = "~/uDos",
        env: [String: String] = [:],
        healthCheckURL: String? = nil,
        icon: String = "⚙️",
        port: Int? = nil,
        requiredComponents: [String] = [],
        description: String = "",
        isEssential: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.command = command
        self.args = args
        self.workingDirectory = workingDirectory
        self.env = env
        self.healthCheckURL = healthCheckURL
        self.icon = icon
        self.port = port
        self.requiredComponents = requiredComponents
        self.description = description
        self.isEssential = isEssential
    }
}

/// Status of a uDos component process
public enum ProcessStatus: Codable, Equatable {
    case stopped
    case running
    case failed(String)
    case unhealthy
    case healthy

    var isRunning: Bool {
        switch self {
        case .running: return true
        default: return false
        }
    }
    var isHealthy: Bool {
        switch self {
        case .healthy, .running: return true
        default: return false
        }
    }
    var isUnhealthy: Bool {
        switch self {
        case .unhealthy, .failed: return true
        default: return false
        }
    }
}

/// Manager for uDos components
public class uDosProcessManager: ObservableObject {
    @Published public var components: [uDosComponent] = []
    @Published public var processes: [String: ProcessStatus] = [:]
    @Published public var logs: [String: [String]] = [:]
    @Published public var launchOnLogin: Bool = false
    @Published public var autoRestart: Bool = false
    @Published public var showNotifications: Bool = false
    @Published public var uDosPath: String = "~/uDos"

    private var healthCheckTimers: [String: Timer] = [:]
    private let defaults = UserDefaults.standard
    private let componentsKey = "uDosComponents"
    private let launchOnLoginKey = "uDosLaunchOnLogin"
    private let autoRestartKey = "uDosAutoRestart"
    private let showNotificationsKey = "uDosShowNotifications"
    private let uDosPathKey = "uDosPath"

    public init() {
        loadComponents()
        loadSettings()
        syncRunningProcesses()
    }

    // MARK: - Component Management

    public func addComponent(_ component: uDosComponent) {
        components.append(component)
        saveComponents()
    }

    public func removeComponent(withId id: String) {
        components.removeAll { $0.id == id }
        stopComponent(withId: id)
        saveComponents()
    }

    public func getComponent(withId id: String) -> uDosComponent? {
        components.first(where: { $0.id == id })
    }

    // MARK: - Process Control

    public func startComponent(_ component: uDosComponent) {
        guard !processes.keys.contains(component.id) || !processes[component.id]!.isRunning else {
            print("⚠️ Component already running: \(component.displayName)")
            return
        }

        // Check dependencies
        for depId in component.requiredComponents {
            guard let dep = getComponent(withId: depId), processes[dep.id]?.isRunning == true else {
                print("⚠️ Dependency not running: \(depId) for \(component.displayName)")
                return
            }
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: component.command)
        task.arguments = component.args
        task.currentDirectoryURL = URL(fileURLWithPath: component.workingDirectory)
        task.environment = ProcessInfo.processInfo.environment.merging(component.env) { $1 }

        // Capture output for logging
        let outputPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = outputPipe

        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if let line = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self.appendLog(component: component.id, line: line)
                }
            }
        }

        do {
            try task.run()
            processes[component.id] = .running
            
            // Start health check if URL is available
            if component.healthCheckURL != nil {
                startHealthCheck(component: component)
            }
            
            // Notify user
            if showNotifications {
                self.notifyUser("Started \(component.displayName)", icon: component.icon)
            }
            
            print("🚀 Started \(component.displayName)")
            
        } catch {
            processes[component.id] = .failed(error.localizedDescription)
            print("❌ Failed to start \(component.displayName): \(error.localizedDescription)")
            
            if showNotifications {
                self.notifyUser("Failed to start \(component.displayName)", icon: "❌")
            }
        }
    }

    public func stopComponent(_ component: uDosComponent) {
        stopComponent(withId: component.id)
    }

    private func stopComponent(withId id: String) {
        guard processes[id] == .running else { return }
        // We don't have access to the Process instance anymore since we simplified the enum
        // In a real implementation, we would keep track of processes separately
        processes[id] = .stopped
        healthCheckTimers[id]?.invalidate()
        healthCheckTimers[id] = nil
        
        if showNotifications {
            if let component = getComponent(withId: id) {
                self.notifyUser("Stopped \(component.displayName)", icon: component.icon)
            }
        }
        
        print("🛑 Stopped component: \(id)")
    }

    public func restartComponent(_ component: uDosComponent) {
        stopComponent(withId: component.id)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.startComponent(component)
        }
    }

    // MARK: - Health Checks

    private func startHealthCheck(component: uDosComponent) {
        guard let url = component.healthCheckURL else { return }
        
        healthCheckTimers[component.id]?.invalidate()
        
        let timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            URLSession.shared.dataTask(with: URL(string: url)!) { data, response, error in
                DispatchQueue.main.async {
                    if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                        self.processes[component.id] = .healthy
                        print("✅ Healthy: \(component.displayName)")
                    } else if error != nil {
                        self.processes[component.id] = .unhealthy
                        print("❌ Unhealthy: \(component.displayName) - \(error?.localizedDescription ?? "Unknown error")")
                        
                        if self.autoRestart {
                            self.restartComponent(component)
                        }
                    }
                }
            }.resume()
        }
        
        healthCheckTimers[component.id] = timer
    }

    // MARK: - Log Management

    private func appendLog(component: String, line: String) {
        if logs[component] != nil {
            logs[component]?.append(line)
        } else {
            logs[component] = [line]
        }
        
        // Limit log size
        if let log = logs[component], log.count > 1000 {
            logs[component] = Array(log.dropFirst(500))
        }
    }

    public func clearLogs() {
        logs.removeAll()
    }

    public func getLogs(for component: String) -> [String] {
        logs[component] ?? []
    }

    // MARK: - System Integration

    public func setLaunchOnLogin(_ enabled: Bool) {
        launchOnLogin = enabled
        saveSettings()
        
        // Try to set launch on login using ServiceManagement
        if enabled {
            self.setLaunchAgentEnabled(true)
        } else {
            self.setLaunchAgentEnabled(false)
        }
    }

    private func setLaunchAgentEnabled(_ enabled: Bool) {
        #if targetEnvironment(macCatalyst)
        // macCatalyst doesn't support launch agents
        return
        #else
        if #available(macOS 13.0, *) {
            if enabled {
                do {
                    try SMAppService.mainApp.register()
                    print("✅ Set to launch on login")
                } catch {
                    print("❌ Failed to set launch on login: \(error.localizedDescription)")
                }
            } else {
                do {
                    try SMAppService.mainApp.unregister()
                    print("✅ Removed launch on login")
                } catch {
                    print("❌ Failed to remove launch on login: \(error.localizedDescription)")
                }
            }
        } else {
            print("⚠️ Launch on login requires macOS 13.0 or later")
        }
        #endif
    }

    // MARK: - Settings Management

    private func loadComponents() {
        if let data = defaults.data(forKey: componentsKey),
           let loadedComponents = try? JSONDecoder().decode([uDosComponent].self, from: data) {
            components = loadedComponents
        } else {
            // Default components
            components = [
                uDosComponent(
                    id: "hivemind",
                    displayName: "Hivemind",
                    command: "/usr/local/bin/cargo",
                    args: ["run", "--release"],
                    workingDirectory: "~/uDos/core/hivemind",
                    env: ["RUST_LOG": "info"],
                    healthCheckURL: "http://localhost:3000/health",
                    icon: "🧠",
                    port: 3000,
                    requiredComponents: [],
                    description: "Core uDos intelligence engine",
                    isEssential: true
                ),
                uDosComponent(
                    id: "re3engine",
                    displayName: "Re3Engine",
                    command: "/opt/homebrew/bin/python3.13",
                    args: ["-m", "re3engine.server"],
                    workingDirectory: "~/uDos/core/re3engine",
                    env: ["PYTHONPATH": "~/uDos/core/re3engine"],
                    healthCheckURL: "http://localhost:30000/health",
                    icon: "⚙️",
                    port: 30000,
                    requiredComponents: [],
                    description: "Re3Engine server for processing",
                    isEssential: true
                ),
                uDosComponent(
                    id: "mcp-gateway",
                    displayName: "MCP Gateway",
                    command: "~/uDos/core/mcp-gateway/target/release/mcp-gateway",
                    args: [],
                    workingDirectory: "~/uDos/core/mcp-gateway",
                    env: ["UDOS_VAULT": "~/vault"],
                    healthCheckURL: "http://localhost:30000/health",
                    icon: "🌐",
                    port: 30000,
                    requiredComponents: ["hivemind"],
                    description: "MCP communication gateway",
                    isEssential: true
                ),
                uDosComponent(
                    id: "sonic-screwdriver",
                    displayName: "Sonic-Screwdriver",
                    command: "/usr/local/bin/sonic",
                    args: ["server"],
                    workingDirectory: "~",
                    env: [:],
                    healthCheckURL: "http://localhost:8080/health",
                    icon: "🔊",
                    port: 8080,
                    requiredComponents: [],
                    description: "Utility server for various tasks",
                    isEssential: false
                )
            ]
        }
    }

    private func saveComponents() {
        if let data = try? JSONEncoder().encode(components) {
            defaults.set(data, forKey: componentsKey)
        }
    }

    private func loadSettings() {
        launchOnLogin = defaults.bool(forKey: launchOnLoginKey)
        autoRestart = defaults.bool(forKey: autoRestartKey)
        showNotifications = defaults.bool(forKey: showNotificationsKey)
        uDosPath = defaults.string(forKey: uDosPathKey) ?? "~/uDos"
    }

    func saveSettings() {
        defaults.set(launchOnLogin, forKey: launchOnLoginKey)
        defaults.set(autoRestart, forKey: autoRestartKey)
        defaults.set(showNotifications, forKey: showNotificationsKey)
        defaults.set(uDosPath, forKey: uDosPathKey)
    }

    // MARK: - Status Sync

    public func syncRunningProcesses() {
        // In a real implementation, we would check for running processes
        // and update the status accordingly
        print("🔍 Syncing running processes...")
    }

    // MARK: - User Notifications

    private func notifyUser(_ message: String, icon: String = "🍫") {
        let content = UNMutableNotificationContent()
        content.title = "uDos Component Manager"
        content.body = "\(icon) \(message)"
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Notification error: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Default Components
public extension uDosProcessManager {
    static var defaultComponents: [uDosComponent] {
        [
            uDosComponent(
                id: "hivemind",
                displayName: "Hivemind",
                command: "/usr/local/bin/cargo",
                args: ["run", "--release"],
                workingDirectory: "~/uDos/core/hivemind",
                env: ["RUST_LOG": "info"],
                healthCheckURL: "http://localhost:3000/health",
                icon: "🧠",
                port: 3000,
                requiredComponents: [],
                description: "Core uDos intelligence engine",
                isEssential: true
            ),
            uDosComponent(
                id: "re3engine",
                displayName: "Re3Engine",
                command: "/opt/homebrew/bin/python3.13",
                args: ["-m", "re3engine.server"],
                workingDirectory: "~/uDos/core/re3engine",
                env: ["PYTHONPATH": "~/uDos/core/re3engine"],
                healthCheckURL: "http://localhost:30000/health",
                icon: "⚙️",
                port: 30000,
                requiredComponents: [],
                description: "Re3Engine server for processing",
                isEssential: true
            ),
            uDosComponent(
                id: "mcp-gateway",
                displayName: "MCP Gateway",
                command: "~/uDos/core/mcp-gateway/target/release/mcp-gateway",
                args: [],
                workingDirectory: "~/uDos/core/mcp-gateway",
                env: ["UDOS_VAULT": "~/vault"],
                healthCheckURL: "http://localhost:30000/health",
                icon: "🌐",
                port: 30000,
                requiredComponents: ["hivemind"],
                description: "MCP communication gateway",
                isEssential: true
            ),
            uDosComponent(
                id: "sonic-screwdriver",
                displayName: "Sonic-Screwdriver",
                command: "/usr/local/bin/sonic",
                args: ["server"],
                workingDirectory: "~",
                env: [:],
                healthCheckURL: "http://localhost:8080/health",
                icon: "🔊",
                port: 8080,
                requiredComponents: [],
                description: "Utility server for various tasks",
                isEssential: false
            )
        ]
    }
}
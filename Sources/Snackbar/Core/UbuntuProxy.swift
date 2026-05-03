// UbuntuProxy.swift
// Snackbar
//
// SSH-based proxy for communicating with the Ubuntu server (wizard@192.168.20.11).
// Provides health checks and command forwarding to Ollama and Hivemind on the remote server.
//
// Created by DevStudio Integration

import Foundation

/// SSH-based proxy for the Ubuntu backend server.
/// Reads SSH config from ~/.ssh/config and connects to wizard@192.168.20.11.
public class UbuntuProxy: ObservableObject {
    public static let shared = UbuntuProxy()

    @Published public private(set) var ollamaStatus: UbuntuBackendStatus = .unknown
    @Published public private(set) var hivemindStatus: UbuntuBackendStatus = .unknown
    @Published public private(set) var lastChecked: Date?
    @Published public private(set) var isReachable: Bool = false

    private let sshHost: String
    private let sshUser: String
    private let sshPort: Int
    private let sshIdentityFile: String
    private let ollamaPort: Int
    private let hivemindPort: Int
    private let session: URLSession
    private var healthCheckTimer: Timer?

    public init(
        sshHost: String? = nil,
        sshUser: String? = nil,
        sshPort: Int? = nil,
        sshIdentityFile: String? = nil,
        ollamaPort: Int? = nil,
        hivemindPort: Int? = nil
    ) {
        // Try to load from ConfigManager first
        let configManager = ConfigManager.shared
        let sshConfig = configManager.getUbuntuSSHConfig()
        let hivemindConfig = configManager.getHivemindConfig()

        self.sshHost = sshHost ?? sshConfig.host
        self.sshUser = sshUser ?? sshConfig.user
        self.sshPort = sshPort ?? sshConfig.port
        self.sshIdentityFile = (sshIdentityFile ?? sshConfig.identityFile as NSString).expandingTildeInPath
        self.ollamaPort = ollamaPort ?? 11434
        self.hivemindPort = hivemindPort ?? hivemindConfig.port


        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 10
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public API

    /// Start periodic health checks.
    public func startMonitoring() {
        performHealthCheck()
        healthCheckTimer?.invalidate()
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            self?.performHealthCheck()
        }
    }

    /// Stop health checks.
    public func stopMonitoring() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
    }

    /// Perform a full health check of the Ubuntu backend.
    public func performHealthCheck() {
        checkSSHConnectivity()
        checkOllamaHealth()
        checkHivemindHealth()
    }

    /// Check if the Ubuntu server is reachable via SSH.
    public func checkSSHConnectivity() {
        let result = runSSHCommand("echo 'pong'")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if result.success && result.stdout?.trimmingCharacters(in: .whitespacesAndNewlines) == "pong" {
                self.isReachable = true
            } else {
                self.isReachable = false
            }
            self.lastChecked = Date()
        }
    }

    /// Check Ollama health on the Ubuntu server.
    public func checkOllamaHealth() {
        let result = runSSHCommand("curl -s http://localhost:\(ollamaPort)/api/tags | head -c 200")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if result.success, let stdout = result.stdout, !stdout.isEmpty {
                if let data = stdout.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let models = json["models"] as? [Any] {
                    self.ollamaStatus = .connected("\(models.count) models")
                } else {
                    self.ollamaStatus = .connected("responding")
                }
            } else {
                self.ollamaStatus = .unreachable(result.stderr ?? "unknown error")
            }
        }
    }

    /// Check Hivemind health on the Ubuntu server.
    public func checkHivemindHealth() {
        let result = runSSHCommand("curl -s http://localhost:\(hivemindPort)/health | head -c 200")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if result.success, let stdout = result.stdout, !stdout.isEmpty {
                self.hivemindStatus = .connected("responding")
            } else {
                self.hivemindStatus = .unreachable(result.stderr ?? "unknown error")
            }
        }
    }

    /// Forward a prompt to Ollama on the Ubuntu server.
    /// - Parameter prompt: The prompt to send to Ollama.
    /// - Returns: The LLM response text.
    public func forwardToOllama(prompt: String, model: String = "tinyllama") async -> Result<String, UbuntuError> {
        let escapedPrompt = prompt
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")

        let curlCommand = """
        curl -s -X POST http://localhost:\(ollamaPort)/api/generate \
          -H "Content-Type: application/json" \
          -d '{"model":"\(model)","prompt":"\(escapedPrompt)","stream":false}' | \
          python3 -c "import sys,json; print(json.load(sys.stdin).get('response',''))"
        """

        let result = runSSHCommand(curlCommand)
        if result.success, let stdout = result.stdout, !stdout.isEmpty {
            return .success(stdout.trimmingCharacters(in: .whitespacesAndNewlines))
        } else {
            return .failure(.sshError(result.stderr ?? "No response from Ollama"))
        }
    }

    /// Forward an MCP request to Hivemind on the Ubuntu server.
    /// - Parameters:
    ///   - method: The MCP method to call.
    ///   - params: The parameters as a JSON string.
    /// - Returns: The MCP response as a string.
    public func forwardToHivemind(method: String, params: String = "{}") async -> Result<String, UbuntuError> {
        let escapedParams = params
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")

        let curlCommand = """
        curl -s -X POST http://localhost:\(hivemindPort)/mcp \
          -H "Content-Type: application/json" \
          -d '{"jsonrpc":"2.0","method":"\(method)","params":\(escapedParams),"id":"\(UUID().uuidString)"}'
        """

        let result = runSSHCommand(curlCommand)
        if result.success, let stdout = result.stdout, !stdout.isEmpty {
            return .success(stdout.trimmingCharacters(in: .whitespacesAndNewlines))
        } else {
            return .failure(.sshError(result.stderr ?? "No response from Hivemind"))
        }
    }

    /// Run a shell command on the Ubuntu server via SSH.
    /// - Parameter command: The command to run.
    /// - Returns: SSHResult with stdout, stderr, and success status.
    public func runSSHCommand(_ command: String) -> SSHResult {
        let task = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        task.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        task.arguments = [
            "-i", sshIdentityFile,
            "-p", "\(sshPort)",
            "-o", "StrictHostKeyChecking=accept-new",
            "-o", "ConnectTimeout=5",
            "\(sshUser)@\(sshHost)",
            command
        ]
        task.standardOutput = outputPipe
        task.standardError = errorPipe

        do {
            try task.run()
            task.waitUntilExit()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

            let stdout = String(data: outputData, encoding: .utf8)
            let stderr = String(data: errorData, encoding: .utf8)

            return SSHResult(
                success: task.terminationStatus == 0,
                stdout: stdout,
                stderr: stderr,
                exitCode: task.terminationStatus
            )
        } catch {
            return SSHResult(
                success: false,
                stdout: nil,
                stderr: error.localizedDescription,
                exitCode: -1
            )
        }
    }

    /// Get a human-readable summary of the Ubuntu backend status.
    public func getStatusSummary() -> String {
        var lines: [String] = []
        lines.append("🌐 Ubuntu Backend Status")
        lines.append("──────────────────")
        lines.append("SSH: \(isReachable ? "✅ reachable" : "❌ unreachable")")
        lines.append("Ollama: \(ollamaStatus.displayText)")
        lines.append("Hivemind: \(hivemindStatus.displayText)")
        if let lastChecked = lastChecked {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            lines.append("Last checked: \(formatter.localizedString(for: lastChecked, relativeTo: Date()))")
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Supporting Types

/// Status of an Ubuntu backend service.
public enum UbuntuBackendStatus: Equatable {
    case unknown
    case connected(String)
    case unreachable(String)
    case notConfigured

    var displayText: String {
        switch self {
        case .unknown:
            return "⏳ checking..."
        case .connected(let detail):
            return "✅ \(detail)"
        case .unreachable(let error):
            return "❌ \(error)"
        case .notConfigured:
            return "⏹️  not configured"
        }
    }

    var isHealthy: Bool {
        if case .connected = self { return true }
        return false
    }
}

/// Result of an SSH command execution.
public struct SSHResult {
    public let success: Bool
    public let stdout: String?
    public let stderr: String?
    public let exitCode: Int32
}

/// Errors from Ubuntu proxy operations.
public enum UbuntuError: Error, LocalizedError {
    case sshError(String)
    case timeout
    case connectionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .sshError(let msg):
            return "SSH error: \(msg)"
        case .timeout:
            return "Connection to Ubuntu server timed out"
        case .connectionFailed(let msg):
            return "Failed to connect: \(msg)"
        }
    }
}

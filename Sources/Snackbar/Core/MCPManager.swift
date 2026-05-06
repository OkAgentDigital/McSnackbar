import Foundation
#if canImport(AppKit)
import AppKit
#endif

/// 🧠 MCP Manager — manages the local HivemindRust process and Xcode MCP bridge.
///
/// Responsibilities:
/// - Start/stop/restart HivemindRust binary on port 3010
/// - Expose Xcode MCP bridge (xcrun mcpbridge) status
/// - Health checks for all MCP endpoints
/// - Acts as the system handler for MCP connections in the uDos ecosystem
///
/// Port Map:
///   8765  — Snackbar's own MCP server (tools, spool, snacks)
///   3010  — HivemindRust MCP gateway (LLM, tool orchestration)
///   30000 — Legacy HivemindRust (deprecated, use 3010)
///
class MCPManager: ObservableObject {
    static let shared = MCPManager()

    // MARK: - Published State

    @Published private(set) var hivemindStatus: MCPProcessStatus = .stopped
    @Published private(set) var xcodeBridgeStatus: MCPProcessStatus = .stopped
    @Published private(set) var ubuntuMCPStatus: MCPProcessStatus = .unknown
    @Published private(set) var hivemindPID: Int32 = 0
    @Published private(set) var lastHealthCheck: Date?
    @Published private(set) var hivemindPort: UInt16 = 3010
    @Published private(set) var xcodeBridgeAvailable: Bool = false

    // MARK: - Constants

    private let hivemindDefaultPort: UInt16 = 3010
    private let healthCheckInterval: TimeInterval = 10.0

    private var hivemindProcess: Process?
    private var healthCheckTimer: Timer?
    private let fileManager = FileManager.default
    private let hivemindClient = HivemindClient.shared

    private init() {
        checkXcodeBridgeAvailability()
    }

    // MARK: - HivemindRust Process Management

    /// Start HivemindRust on the configured port (default 3010).
    func startHivemind(port: UInt16 = 3010) {
        guard hivemindStatus != .running else {
            print("⚠️ HivemindRust already running on port \(hivemindPort)")
            return
        }

        hivemindPort = port

        // Try to find the HivemindRust binary
        guard let binaryPath = findHivemindBinary() else {
            DispatchQueue.main.async {
                self.hivemindStatus = .error("Binary not found")
            }
            print("❌ HivemindRust binary not found. Build it first: cd ~/Code/OkAgentDigital/Hivemind && cargo build --release")
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = ["--port", "\(port)"]
        process.currentDirectoryURL = URL(fileURLWithPath: NSString(string: "~/Code/OkAgentDigital/Hivemind").expandingTildeInPath)

        // Set environment for the process
        var env = ProcessInfo.processInfo.environment
        env["RUST_LOG"] = "info"
        env["HIVEMIND_PORT"] = "\(port)"
        process.environment = env

        // Pipe output for logging
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // Read output in background
        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if let line = String(data: data, encoding: .utf8), !line.isEmpty {
                print("🧠 Hivemind: \(line.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
        }
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if let line = String(data: data, encoding: .utf8), !line.isEmpty {
                print("🧠 Hivemind [!]: \(line.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
        }

        process.terminationHandler = { [weak self] proc in
            DispatchQueue.main.async {
                self?.hivemindStatus = .stopped
                self?.hivemindPID = 0
                print("🧠 HivemindRust process exited (code: \(proc.terminationStatus))")
            }
        }

        do {
            try process.run()
            hivemindProcess = process
            hivemindPID = process.processIdentifier

            DispatchQueue.main.async {
                self.hivemindStatus = .running
            }

            print("✅ HivemindRust started on port \(port) (PID: \(process.processIdentifier))")

            // Wait a moment then verify it's listening
            DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.checkPort(port: port) { isListening in
                    if isListening {
                        print("✅ HivemindRust confirmed listening on :\(port)")
                        DispatchQueue.main.async {
                            self?.hivemindStatus = .running
                        }
                    } else {
                        print("⚠️ HivemindRust started but not yet listening on :\(port)")
                    }
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.hivemindStatus = .error(error.localizedDescription)
            }
            print("❌ Failed to start HivemindRust: \(error.localizedDescription)")
        }
    }

    /// Stop HivemindRust process.
    func stopHivemind() {
        guard let process = hivemindProcess, process.isRunning else {
            // Try by PID
            if hivemindPID > 0 {
                kill(hivemindPID, SIGTERM)
                DispatchQueue.main.async {
                    self.hivemindStatus = .stopped
                    self.hivemindPID = 0
                }
                print("🛑 HivemindRust (PID: \(hivemindPID)) sent SIGTERM")
                return
            }
            print("⚠️ No HivemindRust process to stop")
            return
        }

        process.terminate()
        hivemindProcess = nil
        hivemindPID = 0

        DispatchQueue.main.async {
            self.hivemindStatus = .stopped
        }
        print("🛑 HivemindRust stopped")
    }

    /// Restart HivemindRust on the configured port.
    func restartHivemind(port: UInt16 = 3010) {
        print("🔄 Restarting HivemindRust on port \(port)...")
        stopHivemind()
        // Give it a moment to release the port
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.startHivemind(port: port)
        }
    }

    // MARK: - Xcode MCP Bridge

    /// Check if Xcode's MCP bridge (xcrun mcpbridge) is available.
    private func checkXcodeBridgeAvailability() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        task.arguments = ["--find", "mcpbridge"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()
            xcodeBridgeAvailable = task.terminationStatus == 0
        } catch {
            xcodeBridgeAvailable = false
        }
    }

    /// Get the status of the Xcode MCP bridge as a JSON-RPC compatible description.
    func getXcodeBridgeInfo() -> [String: Any] {
        [
            "available": xcodeBridgeAvailable,
            "status": xcodeBridgeStatus.displayText
        ]
    }

    /// List all MCP servers known to the system (from .mcp.json / Claude config).
    func listConfiguredMCPServers() -> [[String: String]] {
        var servers: [[String: String]] = []

        // Check .mcp.json in project
        let mcpPaths = [
            "~/Code/Apps/Snackbar/.mcp.json",
            "~/Code/OkAgentDigital/.mcp.json",
            "~/.config/udos/mcp.json"
        ]

        for path in mcpPaths {
            let expanded = NSString(string: path).expandingTildeInPath
            if let data = try? Data(contentsOf: URL(fileURLWithPath: expanded)),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let mcpServers = json["mcpServers"] as? [String: Any] {
                for (name, config) in mcpServers {
                    if let configDict = config as? [String: Any],
                       let type = configDict["type"] as? String,
                       let url = configDict["url"] as? String {
                        servers.append(["name": name, "type": type, "url": url])
                    }
                }
            }
        }

        return servers
    }

    // MARK: - Ubuntu MCP

    /// Check if the Ubuntu server's MCP endpoint is reachable.
    func checkUbuntuMCP(host: String = "192.168.20.11", port: Int = 3010) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        task.arguments = [
            "-o", "StrictHostKeyChecking=accept-new",
            "-o", "ConnectTimeout=3",
            "wizard@\(host)",
            "curl -s -o /dev/null -w '%{http_code}' http://localhost:\(port)/health 2>/dev/null || echo 'unreachable'"
        ]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()

            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

            DispatchQueue.main.async {
                let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
                if task.terminationStatus == 0 && trimmed == "200" {
                    self.ubuntuMCPStatus = .running
                } else if task.terminationStatus == 0 {
                    self.ubuntuMCPStatus = .stopped
                } else {
                    self.ubuntuMCPStatus = .stopped
                }
                self.lastHealthCheck = Date()
            }
        } catch {
            DispatchQueue.main.async {
                self.ubuntuMCPStatus = .error(error.localizedDescription)
                self.lastHealthCheck = Date()
            }
        }
    }

    // MARK: - Health Checks

    /// Start periodic health checks for all MCP endpoints.
    func startHealthChecks() {
        performHealthCheck()
        healthCheckTimer?.invalidate()
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: healthCheckInterval, repeats: true) { [weak self] _ in
            self?.performHealthCheck()
        }
    }

    /// Stop health checks.
    func stopHealthChecks() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
    }

    /// Perform a health check on all services.
    func performHealthCheck() {
        // Check Hivemind port
        checkPort(port: hivemindPort) { [weak self] isListening in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if isListening {
                    if self.hivemindStatus != .running {
                        self.hivemindStatus = .running
                    }
                } else {
                    if self.hivemindStatus == .running {
                        self.hivemindStatus = .stopped
                    }
                }
                self.lastHealthCheck = Date()
            }
        }

        // Check Ubuntu MCP (async)
        checkUbuntuMCP()
    }

    // MARK: - MCP Server Configuration

    /// Generate the Xcode MCP configuration JSON for connecting to Snackbar
    /// and HivemindRust.
    func generateXcodeMCPConfig() -> String {
        let config: [String: Any] = [
            "mcpServers": [
                "snackbar": [
                    "type": "http",
                    "url": "http://localhost:8765"
                ],
                "hivemind": [
                    "type": "http",
                    "url": "http://localhost:\(hivemindPort)"
                ]
            ]
        ]

        if let data = try? JSONSerialization.data(withJSONObject: config, options: .prettyPrinted),
           let json = String(data: data, encoding: .utf8) {
            return json
        }
        return "{}"
    }

    /// Write Xcode MCP config to the appropriate location for Xcode to discover.
    func writeXcodeMCPConfig() -> Bool {
        let config = generateXcodeMCPConfig()

        // Xcode reads MCP configs from:
        // ~/Library/Developer/Xcode/MCP/  (Xcode 17+)
        let xcodeMCPDir = NSString(string: "~/Library/Developer/Xcode/MCP").expandingTildeInPath
        let configPath = "\(xcodeMCPDir)/snackbar.json"

        do {
            try fileManager.createDirectory(atPath: xcodeMCPDir, withIntermediateDirectories: true)
            try config.write(toFile: configPath, atomically: true, encoding: .utf8)
            print("✅ Xcode MCP config written to \(configPath)")
            return true
        } catch {
            print("❌ Failed to write Xcode MCP config: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Remote Peer Connection
    
    /// Connect to a remote Snackbar peer's MCP server discovered via Bonjour.
    /// - Parameter peer: The peer to connect to.
    func connectToPeer(_ peer: SnackbarPeer) {
        print("🔗 Connecting to remote Snackbar peer: \(peer.name) at \(peer.mcpURL)")
        
        // Update HivemindClient to point to the remote peer
        if peer.hasMCPServer {
            hivemindClient.baseURL = peer.mcpURL
            hivemindClient.connect()
            print("✅ Connected to remote MCP server: \(peer.mcpURL)")
        }
        
        if peer.hasHivemindGateway {
            print("ℹ️ Remote Hivemind gateway available at: \(peer.hiveURL)")
        }
    }
    
    /// Disconnect from a remote peer and revert to local.
    func disconnectFromPeer() {
        hivemindClient.baseURL = "http://localhost:3010"
        hivemindClient.connect()
        print("🔄 Reverted to local Hivemind gateway")
    }
    
    /// Try to find an available port starting from the preferred port.
    /// This allows multiple instances on the same machine to use different ports
    /// if the default is taken (though the singleton lock should prevent this).
    func findAvailablePort(preferred: UInt16) -> UInt16 {
        var port = preferred
        let maxAttempts = 100
        for _ in 0..<maxAttempts {
            let semaphore = DispatchSemaphore(value: 0)
            var available = false
            checkPort(port: port) { isListening in
                available = !isListening
                semaphore.signal()
            }
            _ = semaphore.wait(timeout: .now() + 2.0)
            if available { return port }
            port += 1
        }
        return preferred // fallback
    }

    // MARK: - Status Summary

    /// Get a human-readable summary of all MCP statuses.
    func getStatusSummary() -> String {
        var lines: [String] = []
        lines.append("🧠 MCP Manager Status")
        lines.append("─────────────────────")
        lines.append("HivemindRust (:\(hivemindPort)): \(hivemindStatus.displayText)")
        lines.append("Xcode Bridge:           \(xcodeBridgeStatus.displayText)")
        lines.append("Ubuntu MCP:             \(ubuntuMCPStatus.displayText)")
        if let last = lastHealthCheck {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            lines.append("Last check:             \(formatter.localizedString(for: last, relativeTo: Date()))")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    /// Find the HivemindRust binary in likely locations.
    private func findHivemindBinary() -> String? {
        let candidates = [
            "~/Code/OkAgentDigital/Hivemind/target/release/hivemind-rust",
            "~/Code/OkAgentDigital/Hivemind/target/debug/hivemind-rust",
            "~/Code/OkAgentDigital/Hivemind/target/debug/hivemind",
            "~/.cargo/bin/hivemind-rust",
            "/usr/local/bin/hivemind-rust",
            "/opt/homebrew/bin/hivemind-rust"
        ]

        for path in candidates {
            let expanded = NSString(string: path).expandingTildeInPath
            if fileManager.isExecutableFile(atPath: expanded) {
                return expanded
            }
        }

        return nil
    }

    /// Check if a TCP port is listening.
    private func checkPort(port: UInt16, completion: @escaping (Bool) -> Void) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        task.arguments = ["-i", ":\(port)", "-P", "-t"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            completion(!output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } catch {
            completion(false)
        }
    }
}

// MARK: - Supporting Types

/// Status of an MCP-managed process.
enum MCPProcessStatus: Equatable {
    case running
    case stopped
    case error(String)
    case unknown

    var displayText: String {
        switch self {
        case .running:    return "✅ Running"
        case .stopped:    return "⏹️  Stopped"
        case .error(let e): return "❌ \(e)"
        case .unknown:    return "⏳ Unknown"
        }
    }

    static func == (lhs: MCPProcessStatus, rhs: MCPProcessStatus) -> Bool {
        switch (lhs, rhs) {
        case (.running, .running), (.stopped, .stopped), (.unknown, .unknown):
            return true
        case (.error(let a), .error(let b)):
            return a == b
        default:
            return false
        }
    }
}

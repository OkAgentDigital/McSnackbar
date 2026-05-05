import Foundation
import Network
#if canImport(AppKit)
import AppKit
#endif

/// Snackbar's own MCP server on port 8765.
/// Exposes tools and resources for agents (Re3engine, Narrator, Hivemind).
class MCPServer: ObservableObject {
    static let shared = MCPServer()
    
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var port: UInt16 = 8765
    
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.snackbar.mcp.server", qos: .userInitiated)
    
    private init() {}
    
    // MARK: - Start / Stop
    
    func start() {
        guard !isRunning else { return }
        
        do {
            let params = NWParameters.tcp
            listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
            listener?.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    switch state {
                    case .ready:
                        self?.isRunning = true
                        print("✅ MCP Server running on port \(self?.port ?? 8765)")
                    case .failed(let error):
                        self?.isRunning = false
                        print("❌ MCP Server failed: \(error)")
                    default:
                        break
                    }
                }
            }
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }
            listener?.start(queue: queue)
        } catch {
            print("❌ MCP Server: Failed to start: \(error)")
        }
    }
    
    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
        print("🛑 MCP Server stopped")
    }
    
    // MARK: - Connection Handling
    
    private func handleConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                self.receiveRequest(on: connection)
            case .failed(let error):
                print("❌ MCP Connection failed: \(error)")
            default:
                break
            }
        }
        connection.start(queue: queue)
    }
    
    /// HTTP header terminator as Data for byte-level searching.
    private let httpHeaderTerminator = Data("\r\n\r\n".utf8)
    
    private func receiveRequest(on connection: NWConnection) {
        receiveAllData(on: connection, buffer: Data())
    }
    
    /// Accumulate TCP data until we have a complete HTTP request or raw JSON payload.
    /// Uses byte-level header parsing to avoid String/Data index mismatches.
    private func receiveAllData(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            
            var accumulated = buffer
            if let data = data, !data.isEmpty {
                accumulated.append(data)
            }
            
            // --- Fast path: check if accumulated data is already valid JSON ---
            // This handles raw JSON-RPC over UDS or nc (no HTTP framing)
            if accumulated.first == 0x7b || accumulated.first == 0x5b { // '{' or '['
                if (try? JSONSerialization.jsonObject(with: accumulated)) != nil {
                    self.handleRequest(accumulated, on: connection)
                    return
                }
            }
            
            // --- HTTP path: look for \r\n\r\n header terminator ---
            if let headerEndRange = accumulated.range(of: httpHeaderTerminator) {
                let headerEndOffset = headerEndRange.upperBound
                let headerBytes = accumulated[..<headerEndOffset]
                let bodyBytes = accumulated[headerEndOffset...]
                
                // Parse Content-Length from header bytes
                let contentLength = parseContentLength(from: headerBytes)
                
                if let expectedLength = contentLength {
                    if bodyBytes.count >= expectedLength {
                        // We have the complete body — extract exactly Content-Length bytes
                        let body = bodyBytes[..<(bodyBytes.startIndex + expectedLength)]
                        self.handleRequest(Data(body), on: connection)
                        return
                    }
                    // Need more data — bodyBytes.count < expectedLength
                } else {
                    // No Content-Length header — use whatever we have after headers
                    self.handleRequest(Data(bodyBytes), on: connection)
                    return
                }
            }
            
            // --- Need more data ---
            if isComplete || error != nil {
                // Connection closed — try to handle what we have
                self.handleRequest(accumulated, on: connection)
            } else {
                // Read more data
                self.receiveAllData(on: connection, buffer: accumulated)
            }
        }
    }
    
    /// Parse Content-Length value from raw HTTP header bytes.
    private func parseContentLength(from headerData: Data) -> Int? {
        guard let headerStr = String(data: headerData, encoding: .utf8) else { return nil }
        for line in headerStr.split(separator: "\r\n") {
            let lower = line.lowercased()
            if lower.hasPrefix("content-length:") {
                let value = line.split(separator: ":").last?
                    .trimmingCharacters(in: .whitespaces)
                return value.flatMap { Int($0) }
            }
        }
        return nil
    }
    
    // MARK: - Request Handling
    
    private func handleRequest(_ data: Data, on connection: NWConnection) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let method = json["method"] as? String else {
            sendError(connection, id: "0", code: -32700, message: "Parse error")
            return
        }
        
        handleJSONRPC(connection, id: json["id"] as? String ?? "1", method: method, params: json["params"] as? [String: Any] ?? [:])
    }
    
    private func handleJSONRPC(_ connection: NWConnection, id: String, method: String, params: [String: Any]) {
        switch method {
        case "initialize":
            handleInitialize(connection, id: id)
        case "tools/list":
            handleToolsList(connection, id: id)
        case "tools/call":
            handleToolsCall(connection, id: id, params: params)
        case "resources/list":
            handleResourcesList(connection, id: id)
        case "resources/read":
            handleResourcesRead(connection, id: id, params: params)
        case "ping":
            sendResult(connection, id: id, result: ["pong": true])
        default:
            sendError(connection, id: id, code: -32601, message: "Method not found: \(method)")
        }
    }
    
    // MARK: - MCP Methods
    
    private func handleInitialize(_ connection: NWConnection, id: String) {
        sendResult(connection, id: id, result: [
            "protocolVersion": "2024-11-05",
            "capabilities": [
                "tools": ["listChanged": true],
                "resources": ["listChanged": true]
            ],
            "serverInfo": [
                "name": "Snackbar MCP Server",
                "version": "2.0.0"
            ]
        ])
    }
    
    private func handleToolsList(_ connection: NWConnection, id: String) {
        let tools: [[String: Any]] = [
            [
                "name": "snack_run",
                "description": "Execute a snack by ID",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "id": ["type": "string", "description": "Snack ID to run"],
                        "params": ["type": "object", "description": "Input parameters"]
                    ],
                    "required": ["id"]
                ]
            ],
            [
                "name": "snack_list",
                "description": "List all installed snacks",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "user": ["type": "boolean", "description": "Include user snacks"],
                        "system": ["type": "boolean", "description": "Include system snacks"]
                    ]
                ]
            ],
            [
                "name": "snack_show",
                "description": "Show snack definition",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "id": ["type": "string", "description": "Snack ID or name"]
                    ],
                    "required": ["id"]
                ]
            ],
            [
                "name": "feed_recent",
                "description": "Get recent spool entries",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "limit": ["type": "number", "description": "Max entries"],
                        "tag": ["type": "string", "description": "Filter by tag"]
                    ]
                ]
            ],
            [
                "name": "feed_search",
                "description": "Search spool entries",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "query": ["type": "string", "description": "Search query"],
                        "since": ["type": "string", "description": "ISO8601 date filter"]
                    ],
                    "required": ["query"]
                ]
            ],
            [
                "name": "feed_stats",
                "description": "Aggregated snack statistics",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "snack_id": ["type": "string", "description": "Snack ID"],
                        "last_hours": ["type": "number", "description": "Period in hours"]
                    ],
                    "required": ["snack_id"]
                ]
            ],
            [
                "name": "nugget_list",
                "description": "List all nuggets",
                "inputSchema": ["type": "object", "properties": [:]]
            ],
            [
                "name": "nugget_info",
                "description": "Show nugget metadata",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "id": ["type": "string", "description": "Nugget ID"]
                    ],
                    "required": ["id"]
                ]
            ],
            [
                "name": "rules_list",
                "description": "List automation rules",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "enabled": ["type": "boolean", "description": "Filter by enabled"]
                    ]
                ]
            ],
            [
                "name": "mcp_start",
                "description": "Start the local HivemindRust MCP gateway on port 3010",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "port": ["type": "number", "description": "Port (default: 3010)"]
                    ]
                ]
            ],
            [
                "name": "mcp_stop",
                "description": "Stop the local HivemindRust MCP gateway",
                "inputSchema": ["type": "object", "properties": [:]]
            ],
            [
                "name": "mcp_restart",
                "description": "Restart the local HivemindRust MCP gateway",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "port": ["type": "number", "description": "Port (default: 3010)"]
                    ]
                ]
            ],
            [
                "name": "mcp_status",
                "description": "Get MCP manager status (Hivemind, Xcode bridge, Ubuntu)",
                "inputSchema": ["type": "object", "properties": [:]]
            ],
            [
                "name": "mcp_generate_xcode_config",
                "description": "Generate Xcode MCP server configuration JSON",
                "inputSchema": ["type": "object", "properties": [:]]
            ],
            [
                "name": "mcp_write_xcode_config",
                "description": "Write Xcode MCP config to ~/Library/Developer/Xcode/MCP/",
                "inputSchema": ["type": "object", "properties": [:]]
            ],
            [
                "name": "vault_read",
                "description": "Read a Vault resource by URI",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "path": ["type": "string", "description": "Resource URI (e.g. vault://config, secrets://OPENAI_KEY)"]
                    ],
                    "required": ["path"]
                ]
            ],
            [
                "name": "vault_list",
                "description": "List all available Vault resources",
                "inputSchema": ["type": "object", "properties": [:]]
            ],
            [
                "name": "vault_secret_read",
                "description": "Read a secret by key name",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "key": ["type": "string", "description": "Secret key name"]
                    ],
                    "required": ["key"]
                ]
            ]
        ]
        
        sendResult(connection, id: id, result: ["tools": tools])
    }
    private func handleToolsCall(_ connection: NWConnection, id: String, params: [String: Any]) {
        guard let name = params["name"] as? String else {
            sendError(connection, id: id, code: -32602, message: "Missing tool name")
            return
        }
        let arguments = params["arguments"] as? [String: Any] ?? [:]
        
        switch name {
        case "snack_run":
            handleSnackRun(connection, id: id, arguments: arguments)
        case "snack_list":
            handleSnackList(connection, id: id)
        case "snack_show":
            handleSnackShow(connection, id: id, arguments: arguments)
        case "feed_recent":
            handleFeedRecent(connection, id: id, arguments: arguments)
        case "feed_search":
            handleFeedSearch(connection, id: id, arguments: arguments)
        case "feed_stats":
            handleFeedStats(connection, id: id, arguments: arguments)
        case "nugget_list":
            handleNuggetList(connection, id: id)
        case "nugget_info":
            handleNuggetInfo(connection, id: id, arguments: arguments)
        case "rules_list":
            handleRulesList(connection, id: id, arguments: arguments)
        case "mcp_start":
            handleMCPStart(connection, id: id, arguments: arguments)
        case "mcp_stop":
            handleMCPStop(connection, id: id, arguments: arguments)
        case "mcp_restart":
            handleMCPRestart(connection, id: id, arguments: arguments)
        case "mcp_status":
            handleMCPStatus(connection, id: id)
        case "mcp_generate_xcode_config":
            handleMCPGenerateConfig(connection, id: id)
        case "mcp_write_xcode_config":
            handleMCPWriteConfig(connection, id: id)
        case "vault_read":
            handleVaultRead(connection, id: id, arguments: arguments)
        case "vault_list":
            handleVaultList(connection, id: id)
        case "vault_secret_read":
            handleVaultSecretRead(connection, id: id, arguments: arguments)
        default:
            sendError(connection, id: id, code: -32601, message: "Tool not found: \(name)")
        }
    }
    
    // MARK: - Tool Implementations
    
    // MARK: - MCP Management Tools
    
    private func handleMCPStart(_ connection: NWConnection, id: String, arguments: [String: Any]) {
        let port = arguments["port"] as? UInt16 ?? UInt16(3010)
        MCPManager.shared.startHivemind(port: port)
        sendResult(connection, id: id, result: [
            "success": true,
            "message": "HivemindRust starting on port \(port)",
            "pid": Int(MCPManager.shared.hivemindPID)
        ])
    }
    
    private func handleMCPStop(_ connection: NWConnection, id: String, arguments: [String: Any]) {
        MCPManager.shared.stopHivemind()
        sendResult(connection, id: id, result: [
            "success": true,
            "message": "HivemindRust stopped"
        ])
    }
    
    private func handleMCPRestart(_ connection: NWConnection, id: String, arguments: [String: Any]) {
        let port = arguments["port"] as? UInt16 ?? UInt16(3010)
        MCPManager.shared.restartHivemind(port: port)
        sendResult(connection, id: id, result: [
            "success": true,
            "message": "HivemindRust restarting on port \(port)"
        ])
    }
    
    private func handleMCPStatus(_ connection: NWConnection, id: String) {
        let manager = MCPManager.shared
        sendResult(connection, id: id, result: [
            "hivemind": [
                "status": manager.hivemindStatus.displayText,
                "pid": Int(manager.hivemindPID),
                "port": Int(manager.hivemindPort)
            ],
            "xcode_bridge": [
                "available": manager.xcodeBridgeAvailable,
                "status": manager.xcodeBridgeStatus.displayText
            ],
            "ubuntu_mcp": [
                "status": manager.ubuntuMCPStatus.displayText
            ],
            "last_health_check": manager.lastHealthCheck?.ISO8601Format() ?? ""
        ])
    }
    
    private func handleMCPGenerateConfig(_ connection: NWConnection, id: String) {
        let configJSON = MCPManager.shared.generateXcodeMCPConfig()
        sendResult(connection, id: id, result: [
            "config": configJSON,
            "message": "Add this to Xcode's MCP settings or ~/Library/Developer/Xcode/MCP/snackbar.json"
        ])
    }
    
    private func handleMCPWriteConfig(_ connection: NWConnection, id: String) {
        let success = MCPManager.shared.writeXcodeMCPConfig()
        sendResult(connection, id: id, result: [
            "success": success,
            "message": success ? "Xcode MCP config written. Restart Xcode to pick it up." : "Failed to write config."
        ])
    }
    
    // MARK: - Vault Resource Tools
    
    private func handleVaultRead(_ connection: NWConnection, id: String, arguments: [String: Any]) {
        guard let path = arguments["path"] as? String else {
            sendError(connection, id: id, code: -32602, message: "Missing path")
            return
        }
        let vault = VaultResourceProvider.shared
        if let content = vault.getContent(for: path) {
            sendResult(connection, id: id, result: ["contents": content, "uri": path])
        } else {
            sendError(connection, id: id, code: -32000, message: "Resource not found: \(path)")
        }
    }
    
    private func handleVaultList(_ connection: NWConnection, id: String) {
        let resources = VaultResourceProvider.shared.getResourceList()
        sendResult(connection, id: id, result: ["resources": resources])
    }
    
    private func handleVaultSecretRead(_ connection: NWConnection, id: String, arguments: [String: Any]) {
        guard let key = arguments["key"] as? String else {
            sendError(connection, id: id, code: -32602, message: "Missing key")
            return
        }
        if let value = VaultResourceProvider.shared.getSecret(key: key) {
            sendResult(connection, id: id, result: ["key": key, "value": value])
        } else {
            sendError(connection, id: id, code: -32000, message: "Secret not found: \(key)")
        }
    }
    
    // MARK: - Snack Tools
    
    private func handleSnackRun(_ connection: NWConnection, id: String, arguments: [String: Any]) {
        guard let snackId = arguments["id"] as? String else {
            sendError(connection, id: id, code: -32602, message: "Missing snack id")
            return
        }
        
        let snackManager = SnackManager.shared
        if let snack = snackManager.getSnack(byId: snackId) {
            let executor = SnackExecutor()
            let result = executor.execute(snack: snack, inputs: arguments["params"] as? [String: String])
            
            sendResult(connection, id: id, result: [
                "success": result.exitCode == 0,
                "output": result.output,
                "exit_code": Int(result.exitCode),
                "duration_ms": result.durationMs
            ])
        } else {
            sendError(connection, id: id, code: -32000, message: "Snack not found: \(snackId)")
        }
    }
    
    private func handleSnackList(_ connection: NWConnection, id: String) {
        let snacks = SnackManager.shared.listSnacks()
        let snackList = snacks.map { snack -> [String: Any] in
            [
                "id": snack.id,
                "name": snack.name,
                "emoji": snack.emoji,
                "runtime": snack.runtime,
                "tags": snack.tags
            ]
        }
        sendResult(connection, id: id, result: ["snacks": snackList])
    }
    
    private func handleSnackShow(_ connection: NWConnection, id: String, arguments: [String: Any]) {
        guard let snackId = arguments["id"] as? String else {
            sendError(connection, id: id, code: -32602, message: "Missing snack id")
            return
        }
        
        if let snack = SnackManager.shared.getSnack(byId: snackId) {
            sendResult(connection, id: id, result: snack.toDictionary())
        } else {
            sendError(connection, id: id, code: -32000, message: "Snack not found: \(snackId)")
        }
    }
    
    private func handleFeedRecent(_ connection: NWConnection, id: String, arguments: [String: Any]) {
        let limit = arguments["limit"] as? Int ?? 10
        let tag = arguments["tag"] as? String
        let entries = SpoolManager.shared.readRecent(limit: limit, tag: tag)
        sendResult(connection, id: id, result: ["entries": entries.map { $0.toDictionary() }])
    }
    
    private func handleFeedSearch(_ connection: NWConnection, id: String, arguments: [String: Any]) {
        guard let query = arguments["query"] as? String else {
            sendError(connection, id: id, code: -32602, message: "Missing query")
            return
        }
        let since = arguments["since"] as? String
        let entries = SpoolManager.shared.search(query: query, since: since)
        sendResult(connection, id: id, result: ["entries": entries.map { $0.toDictionary() }])
    }
    
    private func handleFeedStats(_ connection: NWConnection, id: String, arguments: [String: Any]) {
        guard let snackId = arguments["snack_id"] as? String else {
            sendError(connection, id: id, code: -32602, message: "Missing snack_id")
            return
        }
        let lastHours = arguments["last_hours"] as? Int ?? 24
        let stats = SpoolManager.shared.stats(snackId: snackId, lastHours: lastHours)
        sendResult(connection, id: id, result: stats)
    }
    
    private func handleNuggetList(_ connection: NWConnection, id: String) {
        let nuggets = NuggetManager.shared.nuggets.map { nugget -> [String: Any] in
            [
                "id": nugget.id,
                "name": nugget.name,
                "version": nugget.version,
                "size": nugget.sizeFormatted,
                "packed_at": nugget.packedAt
            ]
        }
        sendResult(connection, id: id, result: ["nuggets": nuggets])
    }
    
    private func handleNuggetInfo(_ connection: NWConnection, id: String, arguments: [String: Any]) {
        guard let nuggetId = arguments["id"] as? String else {
            sendError(connection, id: id, code: -32602, message: "Missing nugget id")
            return
        }
        
        if let info = NuggetManager.shared.info(nuggetId: nuggetId) {
            sendResult(connection, id: id, result: [
                "id": info.id,
                "name": info.name,
                "original_id": info.originalId,
                "version": info.version,
                "size_bytes": info.sizeBytes,
                "size_formatted": info.sizeFormatted,
                "packed_at": info.packedAt,
                "packed_by": info.packedBy,
                "checksum": info.checksum
            ])
        } else {
            sendError(connection, id: id, code: -32000, message: "Nugget not found: \(nuggetId)")
        }
    }
    
    private func handleRulesList(_ connection: NWConnection, id: String, arguments: [String: Any]) {
        let enabledOnly = arguments["enabled"] as? Bool ?? false
        let rules = enabledOnly ? RulesManager.shared.getEnabledRules() : RulesManager.shared.rules
        sendResult(connection, id: id, result: ["rules": rules.map { $0.toDictionary() }])
    }
    
    // MARK: - Resources
    
    private func handleResourcesList(_ connection: NWConnection, id: String) {
        var resources: [[String: Any]] = [
            ["uri": "spool://recent", "name": "Recent Spool Entries", "description": "Live stream of new spool entries"],
            ["uri": "snacks://", "name": "All Snacks", "description": "List of all installed snacks"],
            ["uri": "nuggets://", "name": "All Nuggets", "description": "List of all nuggets"],
            ["uri": "rules://", "name": "Current Rules", "description": "Current automation rule set"],
            ["uri": "vault://config", "name": "Vault Configuration", "description": "uDos Vault config.yaml"],
            ["uri": "vault://recipes", "name": "Vault Recipes", "description": "uDos Vault recipes.yaml"],
            ["uri": "mcp://status", "name": "MCP Manager Status", "description": "Hivemind/Xcode/Ubuntu MCP status"],
            ["uri": "mcp://xcode-config", "name": "Xcode MCP Configuration", "description": "Xcode MCP server config"]
        ]
        
        // Add vault resources if accessible
        if VaultResourceProvider.shared.isAccessible {
            let vaultResources = VaultResourceProvider.shared.getResourceList()
            for vaultRes in vaultResources {
                if let uri = vaultRes["uri"], let name = vaultRes["name"] {
                    resources.append(["uri": uri, "name": name, "description": "Vault resource"])
                }
            }
        }
        
        sendResult(connection, id: id, result: ["resources": resources])
    }
    
    private func handleResourcesRead(_ connection: NWConnection, id: String, params: [String: Any]) {
        guard let uri = params["uri"] as? String else {
            sendError(connection, id: id, code: -32602, message: "Missing URI")
            return
        }
        
        switch uri {
        case "spool://recent":
            let entries = SpoolManager.shared.readRecent(limit: 20)
            let data = (try? JSONSerialization.data(withJSONObject: entries.map { $0.toDictionary() }, options: .prettyPrinted)) ?? Data()
            sendResult(connection, id: id, result: ["contents": String(data: data, encoding: .utf8) ?? "[]"])
        case "snacks://":
            let snacks = SnackManager.shared.listSnacks()
            let data = (try? JSONSerialization.data(withJSONObject: snacks.map { $0.toDictionary() }, options: .prettyPrinted)) ?? Data()
            sendResult(connection, id: id, result: ["contents": String(data: data, encoding: .utf8) ?? "[]"])
        case "nuggets://":
            let nuggets = NuggetManager.shared.nuggets
            let data = (try? JSONEncoder().encode(nuggets)) ?? Data()
            sendResult(connection, id: id, result: ["contents": String(data: data, encoding: .utf8) ?? "[]"])
        case "rules://":
            let rules = RulesManager.shared.rules
            let data = (try? JSONEncoder().encode(RuleContainer(rules: rules))) ?? Data()
            sendResult(connection, id: id, result: ["contents": String(data: data, encoding: .utf8) ?? "{}"])
        case "mcp://status":
            sendResult(connection, id: id, result: ["contents": MCPManager.shared.getStatusSummary()])
        case "mcp://xcode-config":
            sendResult(connection, id: id, result: ["contents": MCPManager.shared.generateXcodeMCPConfig()])
        case let uri where uri.hasPrefix("vault://"):
            if let contents = VaultResourceProvider.shared.getContent(for: uri) {
                sendResult(connection, id: id, result: ["contents": contents, "uri": uri])
            } else {
                sendError(connection, id: id, code: -32000, message: "Resource not found: \(uri)")
            }
        default:
            sendError(connection, id: id, code: -32000, message: "Resource not found: \(uri)")
        }
    }
    
    // MARK: - Response Helpers
    
    private func sendResult(_ connection: NWConnection, id: String, result: Any) {
        let response: [String: Any] = [
            "jsonrpc": "2.0",
            "id": id,
            "result": result
        ]
        sendResponse(connection, response)
    }
    
    private func sendError(_ connection: NWConnection, id: String, code: Int, message: String) {
        let response: [String: Any] = [
            "jsonrpc": "2.0",
            "id": id,
            "error": [
                "code": code,
                "message": message
            ]
        ]
        sendResponse(connection, response)
    }
    
    private func sendResponse(_ connection: NWConnection, _ response: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: response) else { return }
        // Build proper HTTP response with Content-Length
        let body = String(data: data, encoding: .utf8) ?? "{}"
        let httpResponse = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
        guard let responseData = httpResponse.data(using: .utf8) else { return }
        connection.send(content: responseData, completion: .contentProcessed({ _ in }))
    }
}

// MARK: - Dictionary Helpers

extension SpoolEntry {
    func toDictionary() -> [String: Any] {
        [
            "reply_id": reply_id,
            "thread_id": thread_id,
            "timestamp": timestamp,
            "source": source,
            "user_id": user_id,
            "compartment": compartment,
            "prompt": prompt,
            "output": output,
            "tags": tags,
            "metadata": [
                "event_type": metadata.event_type,
                "snack_id": metadata.snack_id,
                "snack_name": metadata.snack_name,
                "runtime": metadata.runtime,
                "duration_ms": metadata.duration_ms,
                "exit_code": Int(metadata.exit_code)
            ]
        ]
    }
}

extension Rule {
    func toDictionary() -> [String: Any] {
        [
            "id": id,
            "name": name,
            "enabled": enabled,
            "trigger": [
                "type": trigger.type.rawValue,
                "snack_id": trigger.snack_id as Any,
                "condition": trigger.condition as Any,
                "cron": trigger.cron as Any,
                "path": trigger.path as Any
            ],
            "action": [
                "type": action.type.rawValue,
                "snack_id": action.snack_id as Any
            ]
        ]
    }
}

import Foundation
import Network

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
    
    private func receiveRequest(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            
            if let data = data, !data.isEmpty {
                self.handleRequest(data, on: connection)
            }
            
            if !isComplete {
                self.receiveRequest(on: connection)
            } else {
                connection.cancel()
            }
        }
    }
    
    // MARK: - Request Handling
    
    private func handleRequest(_ data: Data, on connection: NWConnection) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let method = json["method"] as? String else {
            sendError(connection, code: -32700, message: "Parse error")
            return
        }
        
        let id = json["id"] as? String ?? "1"
        let params = json["params"] as? [String: Any] ?? [:]
        
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
        default:
            sendError(connection, id: id, code: -32601, message: "Tool not found: \(name)")
        }
    }
    
    // MARK: - Tool Implementations
    
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
        let resources: [[String: Any]] = [
            ["uri": "spool://recent", "name": "Recent Spool Entries", "description": "Live stream of new spool entries"],
            ["uri": "snacks://", "name": "All Snacks", "description": "List of all installed snacks"],
            ["uri": "nuggets://", "name": "All Nuggets", "description": "List of all nuggets"],
            ["uri": "rules://", "name": "Current Rules", "description": "Current automation rule set"]
        ]
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
        let httpResponse = """
        HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: \(data.count)\r\n\r\n
        """
        guard var headerData = httpResponse.data(using: .utf8) else { return }
        headerData.append(data)
        connection.send(content: headerData, completion: .contentProcessed({ _ in }))
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

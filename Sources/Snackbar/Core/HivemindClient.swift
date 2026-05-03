// HivemindClient.swift
// Snackbar
//
// HTTP MCP client for communicating with HivemindRust (the local MCP gateway).
// Uses JSON-RPC 2.0 over HTTP to discover and call tools.
//
// Created by DevStudio Integration

import Foundation
import Combine

/// HTTP MCP client for HivemindRust communication.
/// Talks to the local HivemindRust server at http://localhost:30000/mcp
/// using JSON-RPC 2.0 protocol.
public class HivemindClient: ObservableObject {
    public static let shared = HivemindClient()

    @Published public private(set) var isConnected: Bool = false
    @Published public private(set) var connectionStatus: String = "Disconnected"
    @Published public private(set) var availableTools: [MCPTool] = []
    @Published public private(set) var lastResponse: String = ""
    @Published public private(set) var serverVersion: String = ""

    private let baseURL: String
    private let session: URLSession
    private var healthCheckTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    public init(baseURL: String? = nil) {
        // Try to load from ConfigManager first
        let configManager = ConfigManager.shared
        let hivemindConfig = configManager.getHivemindConfig()
        self.baseURL = baseURL ?? "http://localhost:\(hivemindConfig.port)"

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    // MARK: - Connection Management

    /// Start health checks and attempt initial connection.
    public func connect() {
        connectionStatus = "Connecting..."
        performHealthCheck()

        // Start periodic health checks
        healthCheckTimer?.invalidate()
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.performHealthCheck()
        }
    }

    /// Stop health checks and disconnect.
    public func disconnect() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
        isConnected = false
        connectionStatus = "Disconnected"
    }

    // MARK: - MCP JSON-RPC Methods

    /// Initialize an MCP session.
    public func initialize() async -> Result<MCPInitializeResponse, MCPError> {
        let request = MCPRequest(method: "initialize", params: [:])
        return await sendRequest(request)
    }

    /// List all available tools from HivemindRust.
    public func listTools() async -> Result<[MCPTool], MCPError> {
        let request = MCPRequest(method: "tools/list", params: [:])

        return await withCheckedContinuation { continuation in
            sendRequest(request) { (result: Result<MCPToolListResponse, MCPError>) in
                switch result {
                case .success(let response):
                    self.availableTools = response.tools
                    continuation.resume(returning: .success(response.tools))
                case .failure(let error):
                    continuation.resume(returning: .failure(error))
                }
            }
        }
    }

    /// Call a specific tool with arguments.
    public func callTool(name: String, arguments: [String: Any] = [:]) async -> Result<String, MCPError> {
        let params: [String: Any] = [
            "name": name,
            "arguments": arguments
        ]
        let request = MCPRequest(method: "tools/call", params: params)

        return await withCheckedContinuation { continuation in
            sendRequest(request) { (result: Result<MCPToolCallResponse, MCPError>) in
                switch result {
                case .success(let response):
                    let text = response.content
                        .compactMap { $0.text }
                        .joined(separator: "\n")
                    self.lastResponse = text
                    continuation.resume(returning: .success(text))
                case .failure(let error):
                    continuation.resume(returning: .failure(error))
                }
            }
        }
    }

    /// Ping the server to check connectivity.
    public func ping() async -> Bool {
        let request = MCPRequest(method: "ping", params: [:])
        let result: Result<MCPEmptyResponse, MCPError> = await sendRequest(request)
        return result.isSuccess
    }

    /// Get the server status.
    public func getStatus() async -> Result<String, MCPError> {
        return await callTool(name: "get_status")
    }

    /// Execute a Snackbar snack via HivemindRust.
    public func runSnack(id: String, name: String? = nil) async -> Result<String, MCPError> {
        var arguments: [String: Any] = ["snack_id": id]
        if let name = name {
            arguments["snack_name"] = name
        }
        return await callTool(name: "run_snack", arguments: arguments)
    }

    /// List available snacks from HivemindRust.
    public func listSnacks() async -> Result<String, MCPError> {
        return await callTool(name: "list_snacks")
    }

    /// Get Snackbar status from HivemindRust.
    public func getSnackbarStatus() async -> Result<String, MCPError> {
        return await callTool(name: "snackbar_status")
    }

    /// Get Ubuntu backend status from HivemindRust.
    public func getUbuntuStatus() async -> Result<String, MCPError> {
        return await callTool(name: "ubuntu_status")
    }

    // MARK: - Private Methods

    private func performHealthCheck() {
        guard let url = URL(string: "\(baseURL)/health") else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }

                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    self.isConnected = true
                    self.connectionStatus = "Connected"

                    if let data = data,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let version = json["version"] as? String {
                        self.serverVersion = version
                    }

                    // Fetch tools if we haven't yet
                    if self.availableTools.isEmpty {
                        Task { [weak self] in
                            _ = await self?.listTools()
                        }
                    }
                } else {
                    self.isConnected = false
                    self.connectionStatus = "Disconnected"
                    self.serverVersion = ""
                }
            }
        }.resume()
    }

    /// Generic JSON-RPC request sender.
    private func sendRequest<T: Decodable>(_ request: MCPRequest, completion: @escaping (Result<T, MCPError>) -> Void) {
        guard let url = URL(string: "\(baseURL)/mcp") else {
            completion(.failure(.invalidURL))
            return
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Snackbar/1.0", forHTTPHeaderField: "User-Agent")

        do {
            let body: [String: Any] = [
                "jsonrpc": "2.0",
                "method": request.method,
                "params": request.params,
                "id": UUID().uuidString
            ]
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(.encodingError(error)))
            return
        }

        session.dataTask(with: urlRequest) { data, response, error in
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }

            guard let data = data else {
                completion(.failure(.noData))
                return
            }

            do {
                let decoder = JSONDecoder()
                // First check for JSON-RPC error response
                if let errorResponse = try? decoder.decode(MCPErrorResponse.self, from: data),
                   let errorObj = errorResponse.error {
                    completion(.failure(.rpcError(code: errorObj.code, message: errorObj.message)))
                    return
                }

                let rpcResponse = try decoder.decode(MCPResponse<T>.self, from: data)
                if let result = rpcResponse.result {
                    completion(.success(result))
                } else if let errorObj = rpcResponse.error {
                    completion(.failure(.rpcError(code: errorObj.code, message: errorObj.message)))
                } else {
                    completion(.failure(.noData))
                }
            } catch {
                completion(.failure(.decodingError(error)))
            }
        }.resume()
    }

    /// Async wrapper for sendRequest.
    private func sendRequest<T: Decodable>(_ request: MCPRequest) async -> Result<T, MCPError> {
        return await withCheckedContinuation { continuation in
            sendRequest(request) { (result: Result<T, MCPError>) in
                continuation.resume(returning: result)
            }
        }
    }
}

// MARK: - MCP Protocol Types

/// A JSON-RPC request to the MCP server.
public struct MCPRequest {
    public let method: String
    public let params: [String: Any]

    public init(method: String, params: [String: Any] = [:]) {
        self.method = method
        self.params = params
    }
}

/// Generic JSON-RPC response wrapper.
public struct MCPResponse<T: Decodable>: Decodable {
    public let jsonrpc: String
    public let result: T?
    public let error: MCPErrorDetail?
    public let id: String?
}

/// JSON-RPC error detail.
public struct MCPErrorDetail: Decodable {
    public let code: Int
    public let message: String
}

/// JSON-RPC error response.
public struct MCPErrorResponse: Decodable {
    public let jsonrpc: String?
    public let error: MCPErrorDetail?
    public let id: String?
}

/// An MCP tool definition.
public struct MCPTool: Codable, Identifiable {
    public let name: String
    public let description: String
    public let inputSchema: [String: Any]?

    public var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name, description
        case inputSchema
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        inputSchema = try? container.decode([String: Any].self, forKey: .inputSchema)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        if let schema = inputSchema {
            try container.encode(schema, forKey: .inputSchema)
        }
    }
}

/// Response from tools/list.
public struct MCPToolListResponse: Decodable {
    public let tools: [MCPTool]
}

/// Response from tools/call.
public struct MCPToolCallResponse: Decodable {
    public let content: [MCPContent]
    public let isError: Bool?
}

/// Content block from a tool call response.
public struct MCPContent: Decodable {
    public let type: String?
    public let text: String?
}

/// Response from initialize.
public struct MCPInitializeResponse: Decodable {
    public let protocolVersion: String?
    public let capabilities: [String: Any]?
    public let serverInfo: [String: String]?

    enum CodingKeys: String, CodingKey {
        case protocolVersion, capabilities, serverInfo
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        protocolVersion = try? container.decode(String.self, forKey: .protocolVersion)
        capabilities = try? container.decode([String: Any].self, forKey: .capabilities)
        serverInfo = try? container.decode([String: String].self, forKey: .serverInfo)
    }
}

/// Empty response (for ping).
public struct MCPEmptyResponse: Decodable {}

// MARK: - Error Types

public enum MCPError: Error, LocalizedError {
    case invalidURL
    case encodingError(Error)
    case networkError(Error)
    case decodingError(Error)
    case noData
    case rpcError(code: Int, message: String)
    case notConnected

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid MCP server URL"
        case .encodingError(let error):
            return "Failed to encode request: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .noData:
            return "No data received from server"
        case .rpcError(let code, let message):
            return "RPC error (\(code)): \(message)"
        case .notConnected:
            return "Not connected to Hivemind server"
        }
    }
}

// MARK: - Helper Extensions

extension Result {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}

// MARK: - Custom JSON Decoding for [String: Any]

extension KeyedDecodingContainer {
    func decode(_ type: [String: Any].Type, forKey key: KeyedDecodingContainer.Key) throws -> [String: Any] {
        let container = try self.nestedContainer(keyedBy: AnyCodingKey.self, forKey: key)
        return try container.decode([String: Any].self)
    }
}

extension UnkeyedDecodingContainer {
    mutating func decode(_ type: [String: Any].Type) throws -> [String: Any] {
        let container = try self.nestedContainer(keyedBy: AnyCodingKey.self)
        return try container.decode([String: Any].self)
    }
}

struct AnyCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) { self.stringValue = stringValue; self.intValue = nil }
    init?(intValue: Int) { self.stringValue = "\(intValue)"; self.intValue = intValue }

    init(_ string: String) { self.stringValue = string; self.intValue = nil }
}

extension KeyedDecodingContainer where Key == AnyCodingKey {
    func decode(_ type: [String: Any].Type) throws -> [String: Any] {
        var dict = [String: Any]()
        for key in self.allKeys {
            if let boolVal = try? self.decode(Bool.self, forKey: key) {
                dict[key.stringValue] = boolVal
            } else if let intVal = try? self.decode(Int.self, forKey: key) {
                dict[key.stringValue] = intVal
            } else if let doubleVal = try? self.decode(Double.self, forKey: key) {
                dict[key.stringValue] = doubleVal
            } else if let stringVal = try? self.decode(String.self, forKey: key) {
                dict[key.stringValue] = stringVal
            } else if let nestedDict = try? self.decode([String: Any].self, forKey: key) {
                dict[key.stringValue] = nestedDict
            } else if let nestedArray = try? self.decode([Any].self, forKey: key) {
                dict[key.stringValue] = nestedArray
            }
        }
        return dict
    }
}

extension KeyedDecodingContainer where Key == AnyCodingKey {
    func decode(_ type: [Any].Type) throws -> [Any] {
        var array = [Any]()
        var container = try self.nestedUnkeyedContainer(forKey: AnyCodingKey("_"))
        while !container.isAtEnd {
            if let boolVal = try? container.decode(Bool.self) {
                array.append(boolVal)
            } else if let intVal = try? container.decode(Int.self) {
                array.append(intVal)
            } else if let doubleVal = try? container.decode(Double.self) {
                array.append(doubleVal)
            } else if let stringVal = try? container.decode(String.self) {
                array.append(stringVal)
            } else if let nestedDict = try? container.decode([String: Any].self) {
                array.append(nestedDict)
            }
        }
        return array
    }
}

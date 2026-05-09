// MCPClient.swift
// Snackbar
//
// Actor-based HTTP MCP client for communicating with Re3Engine's HTTP MCP server.
// Uses JSON-RPC 2.0 over HTTP to discover and call Xcode tools.
//
// Created by DevStudio Integration

import Foundation

// MARK: - JSON-RPC 2.0 Types

/// A JSON-RPC 2.0 request.
struct MCPRequest: Encodable {
    let jsonrpc = "2.0"
    let method: String
    let params: AnyEncodable?
    let id: Int

    enum CodingKeys: String, CodingKey {
        case jsonrpc, method, params, id
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(jsonrpc, forKey: .jsonrpc)
        try container.encode(method, forKey: .method)
        try container.encodeIfPresent(params, forKey: .params)
        try container.encode(id, forKey: .id)
    }
}

/// A JSON-RPC 2.0 response.
struct MCPResponse: Decodable {
    let jsonrpc: String
    let id: Int?
    let result: AnyDecodable?
    let error: MCPErrorResponse?
}

/// A JSON-RPC 2.0 error object.
struct MCPErrorResponse: Decodable, LocalizedError {
    let code: Int
    let message: String
    let data: AnyDecodable?

    var errorDescription: String? { "MCP error \(code): \(message)" }
}

/// A tool descriptor returned by tools/list.
public struct MCPTool: Identifiable, Codable, Sendable {
    public let id: String
    public let name: String
    public let description: String
    public let inputSchema: AnyDecodable?

    public init(name: String, description: String, inputSchema: AnyDecodable? = nil) {
        self.id = name
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
    }

    enum CodingKeys: String, CodingKey {
        case name, description, inputSchema
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        id = name
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        inputSchema = try container.decodeIfPresent(AnyDecodable.self, forKey: .inputSchema)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encodeIfPresent(inputSchema, forKey: .inputSchema)
    }
}

// MARK: - Dynamic JSON Helpers

/// Wraps any Encodable value for use in JSON-RPC params.
public struct AnyEncodable: Encodable {
    public let value: Encodable
    public init(_ value: Encodable) { self.value = value }

    public func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
}

/// Wraps any Decodable value for use in JSON-RPC results.
public struct AnyDecodable: Decodable, Sendable {
    public let value: Any

    public init(_ value: Any) { self.value = value }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) { value = intVal }
        else if let doubleVal = try? container.decode(Double.self) { value = doubleVal }
        else if let boolVal = try? container.decode(Bool.self) { value = boolVal }
        else if let stringVal = try? container.decode(String.self) { value = stringVal }
        else if let arrayVal = try? container.decode([AnyDecodable].self) { value = arrayVal.map(\.value) }
        else if let dictVal = try? container.decode([String: AnyDecodable].self) { value = dictVal.mapValues(\.value) }
        else { value = [String: Any]() }
    }
}

// MARK: - Errors

public enum MCPClientError: LocalizedError, Sendable {
    case invalidURL
    case invalidResponse
    case emptyResponse
    case serverError(String)
    case notConnected
    case transportError(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:      return "Invalid MCP server URL"
        case .invalidResponse: return "Invalid response from MCP server"
        case .emptyResponse:   return "Empty response from MCP server"
        case .serverError(let m): return "MCP server error: \(m)"
        case .notConnected:    return "Not connected to MCP server"
        case .transportError(let e): return "Transport error: \(e.localizedDescription)"
        }
    }
}

// MARK: - MCP Client Actor

/// Actor-based HTTP MCP client for Re3Engine communication.
/// Talks to Re3Engine's HTTP MCP server at http://localhost:3011/mcp
/// using JSON-RPC 2.0 protocol.
///
/// Provides Xcode build, test, clean, open, and project management tools
/// via Re3Engine's MCP bridge.
public actor MCPClient {
    public static let shared = MCPClient()

    public private(set) var isConnected: Bool = false
    public private(set) var connectionStatus: String = "Disconnected"
    public private(set) var availableTools: [MCPTool] = []
    public private(set) var serverVersion: String = ""

    public var baseURL: String
    private let session: URLSession
    private var requestId: Int = 1

    public init(baseURL: String? = nil) {
        self.baseURL = baseURL ?? "http://localhost:3011"
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    // MARK: - Health Check

    /// Check if the Re3Engine HTTP MCP server is reachable.
    /// - Returns: `true` if the server responds with 200.
    @discardableResult
    public func performHealthCheck() async -> Bool {
        guard let url = URL(string: "\(baseURL)/health") else {
            connectionStatus = "Invalid URL"
            return false
        }

        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                isConnected = false
                connectionStatus = "Server not ready"
                return false
            }

            isConnected = true
            connectionStatus = "Connected"

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let version = json["version"] as? String {
                serverVersion = version
            }

            return true
        } catch {
            isConnected = false
            connectionStatus = "Error: \(error.localizedDescription)"
            return false
        }
    }

    /// Convenience: check health without updating state.
    public func isHealthy() async -> Bool {
        guard let url = URL(string: "\(baseURL)/health") else { return false }
        do {
            let (_, response) = try await session.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    // MARK: - MCP Methods

    /// Initialize the MCP session.
    /// - Returns: The server capabilities dictionary.
    public func initialize() async throws -> [String: Any] {
        let response = try await sendRequest(method: "initialize", params: nil)
        if let result = response.result?.value as? [String: Any] {
            return result
        }
        throw MCPClientError.invalidResponse
    }

    /// List available tools from the MCP server.
    /// - Returns: The list of available tools.
    @discardableResult
    public func listTools() async throws -> [MCPTool] {
        let response = try await sendRequest(method: "tools/list", params: nil)
        if let result = response.result?.value as? [String: Any],
           let toolsArray = result["tools"] as? [[String: Any]] {
            let tools = toolsArray.compactMap { dict -> MCPTool? in
                guard let name = dict["name"] as? String else { return nil }
                return MCPTool(
                    name: name,
                    description: dict["description"] as? String ?? "",
                    inputSchema: dict["inputSchema"].map { AnyDecodable($0) }
                )
            }
            availableTools = tools
            return tools
        }
        throw MCPClientError.invalidResponse
    }

    /// Call a tool on the MCP server.
    /// - Parameters:
    ///   - name: The tool name (e.g., "xcode_build", "xcode_test")
    ///   - arguments: The tool arguments as a dictionary
    /// - Returns: The text content of the tool response.
    public func callTool(name: String, arguments: [String: Any] = [:]) async throws -> String {
        let params: [String: Any] = [
            "name": name,
            "arguments": arguments
        ]
        let response = try await sendRequest(method: "tools/call", params: params)

        if let result = response.result?.value as? [String: Any] {
            // Standard MCP content array format
            if let content = result["content"] as? [[String: Any]],
               let firstContent = content.first,
               let text = firstContent["text"] as? String {
                return text
            }
            // Direct text response
            if let text = result["text"] as? String {
                return text
            }
        }

        throw MCPClientError.invalidResponse
    }

    /// Send a skill trigger request to the MCP server.
    /// - Parameters:
    ///   - skillName: The skill name (e.g., "xcode_build", "chat")
    ///   - args: Optional JSON-encoded arguments string
    /// - Returns: The response text.
    public func triggerSkill(_ skillName: String, args: String? = nil) async throws -> String {
        var urlComponents = URLComponents(string: "\(baseURL)/mcp/skill")!
        var queryItems = [URLQueryItem(name: "name", value: skillName)]
        if let args = args {
            queryItems.append(URLQueryItem(name: "args", value: args))
        }
        urlComponents.queryItems = queryItems

        guard let url = urlComponents.url else {
            throw MCPClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60

        let (data, _) = try await session.data(for: request)

        if let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let text = result["result"] as? String {
                return text
            }
            if let error = result["error"] as? String {
                throw MCPClientError.serverError(error)
            }
        }

        return String(data: data, encoding: .utf8) ?? ""
    }

    // MARK: - Convenience Methods

    /// Get the installed Xcode version.
    public func xcodeVersion() async throws -> String {
        try await callTool(name: "xcode_version")
    }

    /// Build an Xcode project.
    /// - Parameters:
    ///   - project: Path to .xcodeproj or .xcworkspace
    ///   - scheme: The scheme to build
    /// - Returns: Build output.
    public func xcodeBuild(project: String, scheme: String) async throws -> String {
        try await callTool(name: "xcode_build", arguments: [
            "project": project,
            "scheme": scheme
        ])
    }

    /// Run tests in an Xcode project.
    /// - Parameters:
    ///   - project: Path to .xcodeproj or .xcworkspace
    ///   - scheme: The scheme to test
    /// - Returns: Test results.
    public func xcodeTest(project: String, scheme: String) async throws -> String {
        try await callTool(name: "xcode_test", arguments: [
            "project": project,
            "scheme": scheme
        ])
    }

    /// Clean an Xcode project.
    /// - Parameter project: Path to .xcodeproj or .xcworkspace
    /// - Returns: Clean output.
    public func xcodeClean(project: String) async throws -> String {
        try await callTool(name: "xcode_clean", arguments: [
            "project": project
        ])
    }

    /// Open an Xcode project.
    /// - Parameter project: Path to .xcodeproj or .xcworkspace
    /// - Returns: Open result.
    public func xcodeOpen(project: String) async throws -> String {
        try await callTool(name: "xcode_open", arguments: [
            "project": project
        ])
    }

    /// List available schemes in an Xcode project.
    /// - Parameter project: Path to .xcodeproj or .xcworkspace
    /// - Returns: List of schemes.
    public func xcodeListSchemes(project: String) async throws -> String {
        try await callTool(name: "xcode_list_schemes", arguments: [
            "project": project
        ])
    }

    /// Get build settings for an Xcode project.
    /// - Parameters:
    ///   - project: Path to .xcodeproj or .xcworkspace
    ///   - scheme: Optional scheme name
    /// - Returns: Build settings.
    public func xcodeBuildSettings(project: String, scheme: String? = nil) async throws -> String {
        var args: [String: Any] = ["project": project]
        if let scheme = scheme {
            args["scheme"] = scheme
        }
        return try await callTool(name: "xcode_build_settings", arguments: args)
    }

    // MARK: - Internal

    /// Send a JSON-RPC 2.0 request to the MCP server.
    private func sendRequest(method: String, params: Any?) async throws -> MCPResponse {
        let currentId = requestId
        requestId += 1

        let requestBody = MCPRequest(
            method: method,
            params: params.map { AnyEncodable(AnyEncodableBox(value: $0)) },
            id: currentId
        )

        guard let url = URL(string: "\(baseURL)/mcp") else {
            throw MCPClientError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 60

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(requestBody)

        let (data, _) = try await session.data(for: urlRequest)

        let decoder = JSONDecoder()
        let response = try decoder.decode(MCPResponse.self, from: data)

        if let error = response.error {
            throw MCPClientError.serverError(error.message)
        }

        return response
    }
}

// MARK: - Internal Helpers

/// Wraps an arbitrary value for Encodable conformance.
struct AnyEncodableBox: Encodable {
    let value: Any

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let intVal as Int:           try container.encode(intVal)
        case let doubleVal as Double:     try container.encode(doubleVal)
        case let boolVal as Bool:         try container.encode(boolVal)
        case let stringVal as String:     try container.encode(stringVal)
        case let arrayVal as [Any]:       try container.encode(arrayVal.map(AnyEncodableBox.init))
        case let dictVal as [String: Any]: try container.encode(dictVal.mapValues(AnyEncodableBox.init))
        default:
            try container.encodeNil()
        }
    }
}

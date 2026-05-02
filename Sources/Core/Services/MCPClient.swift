// MCPClient.swift
// Snackbar
//
// Created by DevStudio Integration
//

import Foundation
import Combine
import Network

/// Message Control Protocol (MCP) Client for real-time communication with DevStudio
public class MCPClient: ObservableObject {
    public static let shared = MCPClient()
    
    @Published public private(set) var isConnected: Bool = false
    @Published public private(set) var connectionStatus: String = "Disconnected"
    
    private var connection: NWConnection?
    private var queue: DispatchQueue
    private var cancellables = Set<AnyCancellable>()
    private let socketPath: String
    
    public init(socketPath: String = "~/.local/share/udos/mcp/socket") {
        self.socketPath = (socketPath as NSString).expandingTildeInPath
        self.queue = DispatchQueue(label: "com.udos.snackbar.mcp")
    }

    // MARK: - Connection Management
    
    public func connect() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            self.disconnect() // Disconnect any existing connection
            
            // Create Unix domain socket connection
            // NWProtocolUnix might not be available in all SDK versions
            /*
            let tcpOptions = NWProtocolTCP.Options()
            let unixOptions = NWProtocolUnix.Options()
            */
            
            // Use Unix domain socket for local communication
            let connection = NWConnection(
                to: .unix(path: self.socketPath),
                using: .tcp // Fallback to TCP if .unix parameter/type is unavailable
            )
            
            self.connection = connection
            
            // Set up state update handler
            connection.stateUpdateHandler = { [weak self] newState in
                guard let self = self else { return }
                
                switch newState {
                case .ready:
                    self.handleConnectionReady()
                case .failed(let error):
                    self.handleConnectionFailed(error: error)
                case .cancelled:
                    self.handleConnectionCancelled()
                default:
                    break
                }
            }
            
            // Set up receive handler
            self.setupReceiveHandler()
            
            // Start connection
            connection.start(queue: self.queue)
            
            // Update status
            DispatchQueue.main.async {
                self.connectionStatus = "Connecting..."
            }
        }
    }
    
    public func disconnect() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            self.connection?.cancel()
            self.connection = nil
            
            DispatchQueue.main.async {
                self.isConnected = false
                self.connectionStatus = "Disconnected"
            }
        }
    }
    
    // MARK: - Message Sending
    
    public func sendMessage(_ message: String, completion: ((Result<String, Error>) -> Void)? = nil) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            guard self.isConnected else {
                DispatchQueue.main.async {
                    completion?(.failure(NSError(domain: "MCP", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not connected"])))
                }
                return
            }
            
            guard let data = message.data(using: .utf8) else {
                DispatchQueue.main.async {
                    completion?(.failure(NSError(domain: "MCP", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode message"])))
                }
                return
            }
            
            // Add MCP protocol header
            let mcpMessage = self.wrapInMCPProtocol(message: message)
            guard let mcpData = mcpMessage.data(using: .utf8) else {
                DispatchQueue.main.async {
                    completion?(.failure(NSError(domain: "MCP", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode MCP message"])))
                }
                return
            }
            
            // Send the message
            self.connection?.send(
                content: mcpData,
                completion: NWConnection.SendCompletion.contentProcessed({ [weak self] error in
                    guard let self = self else { return }
                    
                    if let error = error {
                        DispatchQueue.main.async {
                            completion?(.failure(error))
                        }
                        return
                    }
                    
                    // Message sent successfully, now wait for response
                    DispatchQueue.main.async {
                        self.connectionStatus = "Message sent, waiting for response..."
                    }
                })
            )
        }
    }
    
    public func sendSkillCommand(_ skillName: String, arguments: [String] = [], completion: ((Result<String, Error>) -> Void)? = nil) {
        let command = arguments.isEmpty ? skillName : "" + skillName + " " + arguments.joined(separator: " ")
        sendMessage(command, completion: completion)
    }
    
    // MARK: - Private Methods
    
    private func handleConnectionReady() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.isConnected = true
            self.connectionStatus = "Connected"
            
            // Send initial handshake
            let handshake = self.createHandshakeMessage()
            self.sendMessage(handshake) { result in
                if case .failure(let error) = result {
                    self.connectionStatus = "Handshake failed: " + error.localizedDescription
                } else {
                    self.connectionStatus = "Ready"
                }
            }
        }
    }
    
    private func handleConnectionFailed(error: Error) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.isConnected = false
            self.connectionStatus = "Connection failed: " + error.localizedDescription
            
            // Attempt to reconnect after delay
            DispatchQueue.global().asyncAfter(deadline: .now() + 5.0) { [weak self] in
                self?.connect()
            }
        }
    }
    
    private func handleConnectionCancelled() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.isConnected = false
            self.connectionStatus = "Connection cancelled"
        }
    }
    
    private func setupReceiveHandler() {
        connection?.receive(
            minimumIncompleteLength: 1,
            maximumLength: 65536,
            completion: { [weak self] (data, context, isComplete, error) in
                guard let self = self else { return }
                
                if let error = error {
                    DispatchQueue.main.async {
                        self.connectionStatus = "Receive error: " + error.localizedDescription
                    }
                    return
                }
                
                if let data = data, !data.isEmpty {
                    if let message = String(data: data, encoding: .utf8) {
                        self.handleIncomingMessage(message)
                    }
                }
                
                // Continue receiving
                if isComplete {
                    self.setupReceiveHandler()
                }
            }
        )
    }
    
    private func handleIncomingMessage(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Parse MCP message
            if let parsedMessage = self.parseMCPMessage(message) {
                self.connectionStatus = "Received: " + parsedMessage.content
                
                // Handle different message types
                switch parsedMessage.type {
                case "response":
                    self.handleResponseMessage(parsedMessage)
                case "event":
                    self.handleEventMessage(parsedMessage)
                case "error":
                    self.handleErrorMessage(parsedMessage)
                default:
                    self.connectionStatus = "Unknown message type: " + parsedMessage.type
                }
            } else {
                self.connectionStatus = "Failed to parse message: " + message
            }
        }
    }
    
    private func handleResponseMessage(_ message: MCPMessage) {
        // Handle response from DevStudio
        print("MCP Response: " + message.content)
        
        // Notify any waiting callers
        // In a real implementation, you would have a more sophisticated
        // request/response matching system
    }
    
    private func handleEventMessage(_ message: MCPMessage) {
        // Handle events from DevStudio
        print("MCP Event: " + message.content)
        
        // Parse event data
        if let eventData = try? JSONSerialization.jsonObject(with: message.content.data(using: .utf8)!, options: []) as? [String: Any] {
            if let eventType = eventData["type"] as? String {
                switch eventType {
                case "skill_completed":
                    self.handleSkillCompletedEvent(eventData)
                case "status_update":
                    self.handleStatusUpdateEvent(eventData)
                default:
                    print("Unknown event type: " + eventType)
                }
            }
        }
    }
    
    private func handleErrorMessage(_ message: MCPMessage) {
        self.connectionStatus = "Error: " + message.content
        print("MCP Error: " + message.content)
    }
    
    private func handleSkillCompletedEvent(_ eventData: [String: Any]) {
        if let skillName = eventData["skill"] as? String,
           let success = eventData["success"] as? Bool {
            let message = "Skill '" + skillName + "' completed: " + (success ? "success" : "failure")
            self.connectionStatus = message
            
            // Show notification
            self.showNotification(title: "DevStudio Skill", message: message)
        }
    }
    
    private func handleStatusUpdateEvent(_ eventData: [String: Any]) {
        if let status = eventData["status"] as? String {
            self.connectionStatus = "DevStudio: " + status
        }
    }
    
    // MARK: - MCP Protocol Methods
    
    private func createHandshakeMessage() -> String {
        let handshake: [String: Any] = [
            "type": "handshake",
            "client": "Snackbar",
            "version": "1.0",
            "timestamp": Date().timeIntervalSince1970,
            "capabilities": ["skill_execution", "event_listening"]
        ]
        
        return self.wrapInMCPProtocol(message: self.dictionaryToJSON(handshake))
    }
    
    private func wrapInMCPProtocol(message: String) -> String {
        // MCP protocol format:
        // [HEADER][LENGTH][MESSAGE]
        // Where HEADER is "MCP1" (4 bytes)
        // LENGTH is the message length as 4-byte big-endian integer
        // MESSAGE is the actual JSON message
        
        let header = "MCP1"
        let length = String(format: "%08d", message.utf8.count)
        
        return header + length + message
    }
    
    private func parseMCPMessage(_ rawMessage: String) -> MCPMessage? {
        // Check minimum length (header + length field)
        guard rawMessage.utf8.count >= 12 else {
            return nil
        }
        
        // Extract header
        let headerIndex = rawMessage.index(rawMessage.startIndex, offsetBy: 4)
        let header = String(rawMessage[..<headerIndex])
        
        // Verify header
        guard header == "MCP1" else {
            return nil
        }
        
        // Extract length
        let lengthEndIndex = rawMessage.index(rawMessage.startIndex, offsetBy: 8)
        let lengthStartIndex = rawMessage.index(rawMessage.startIndex, offsetBy: 4)
        let lengthString = String(rawMessage[lengthStartIndex..<lengthEndIndex])
        
        guard let length = Int(lengthString) else {
            return nil
        }
        
        // Extract message content
        let contentStartIndex = rawMessage.index(rawMessage.startIndex, offsetBy: 12)
        let contentEndIndex = rawMessage.index(contentStartIndex, offsetBy: length, limitedBy: rawMessage.endIndex) ?? rawMessage.endIndex
        let content = String(rawMessage[contentStartIndex..<contentEndIndex])
        
        // Parse JSON content
        if let jsonData = content.data(using: .utf8),
           let messageDict = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
            
            return MCPMessage(
                type: messageDict["type"] as? String ?? "unknown",
                content: content,
                rawData: messageDict
            )
        }
        
        return nil
    }
    
    private func dictionaryToJSON(_ dict: [String: Any]) -> String {
        if let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: []),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        return "{}"
    }
    
    private func showNotification(title: String, message: String) {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = message
        notification.soundName = NSUserNotificationDefaultSoundName
        
        NSUserNotificationCenter.default.deliver(notification)
    }
}

// MARK: - MCP Message Model

public struct MCPMessage {
    public let type: String
    public let content: String
    public let rawData: [String: Any]
    
    public init(type: String, content: String, rawData: [String: Any]) {
        self.type = type
        self.content = content
        self.rawData = rawData
    }
}

// MARK: - MCP Client Extension for DevStudioSkillTrigger

// extension DevStudioSkillTrigger {
//    public func sendViaMCP(_ skillName: String, arguments: [String] = [], completion: ((Result<String, Error>) -> Void)? = nil) {
//        let mcpClient = MCPClient.shared
//        
//        guard mcpClient.isConnected else {
//            completion?(.failure(NSError(domain: "MCP", code: -1, userInfo: [NSLocalizedDescriptionKey: "MCP not connected"])))
//            return
//        }
//        
//        let command = arguments.isEmpty ? skillName : skillName + " " + arguments.joined(separator: " ")
//        mcpClient.sendSkillCommand(skillName, arguments: arguments, completion: completion)
//    }
// }
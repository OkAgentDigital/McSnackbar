// DevStudioSkillTrigger.swift
// Snackbar
//
// Created by DevStudio Integration
//

import Foundation

public class DevStudioSkillTrigger {
    public static let shared = DevStudioSkillTrigger()
    
    private let vibeExecutablePath: String
    private let mcpSocketPath: String
    
    public init(vibeExecutablePath: String = "/usr/local/bin/vibe", mcpSocketPath: String = "~/.local/share/udos/mcp/socket") {
        self.vibeExecutablePath = vibeExecutablePath
        self.mcpSocketPath = mcpSocketPath
    }

    // MARK: - Skill Triggering via CLI
    public func runSkill(command: String, completion: @escaping (Result<String, Error>) -> Void) {
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: vibeExecutablePath)
        process.arguments = command.components(separatedBy: " ")
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
                    completion(.failure(NSError(domain: "DevStudioSkill", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: output])))
                }
            } else {
                completion(.failure(NSError(domain: "DevStudioSkill", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to read output"])))
            }
        } catch {
            completion(.failure(error))
        }
    }

    // MARK: - MCP Communication
    public func sendViaMCP(_ skillName: String, arguments: [String] = [], completion: ((Result<String, Error>) -> Void)? = nil) {
        let mcpClient = MCPClient.shared
        
        guard mcpClient.isConnected else {
            completion?(.failure(NSError(domain: "MCP", code: -1, userInfo: [NSLocalizedDescriptionKey: "MCP not connected"])))
            return
        }
        
        mcpClient.sendSkillCommand(skillName, arguments: arguments, completion: completion)
    }

    public func sendMCPMessage(_ message: String, completion: @escaping (Result<String, Error>) -> Void) {
        // Expand tilde in path
        let expandedSocketPath = (mcpSocketPath as NSString).expandingTildeInPath
        
        // Create a socket connection
        let socket = FileHandle(forReadingAtPath: expandedSocketPath) ?? FileHandle(forWritingAtPath: expandedSocketPath)
        
        guard let socket = socket else {
            completion(.failure(NSError(domain: "MCP", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to open socket"])))
            return
        }
        
        // Write message to socket
        if let data = message.data(using: .utf8) {
            socket.write(data)
            
            // Read response
            let responseData = socket.readDataToEndOfFile()
            if let response = String(data: responseData, encoding: .utf8) {
                completion(.success(response))
            } else {
                completion(.failure(NSError(domain: "MCP", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to read response"])))
            }
        } else {
            completion(.failure(NSError(domain: "MCP", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode message"])))
        }
    }

    // MARK: - Convenience Methods
    public func triggerVAULTRUN(vaultName: String, useMCP: Bool = true, completion: @escaping (Result<String, Error>) -> Void) {
        if useMCP {
            sendViaMCP("VAULTRUN", arguments: [vaultName], completion: completion)
        } else {
            runSkill(command: "VAULTRUN " + vaultName, completion: completion)
        }
    }

    public func triggerNoteTaker(title: String, content: String, useMCP: Bool = true, completion: @escaping (Result<String, Error>) -> Void) {
        let safeTitle = title.replacingOccurrences(of: " ", with: "-")
        let safeContent = content.replacingOccurrences(of: " ", with: "-")
        
        if useMCP {
            sendViaMCP("note-taker", arguments: ["--title", safeTitle, "--content", safeContent], completion: completion)
        } else {
            runSkill(command: "note-taker --title " + safeTitle + " --content " + safeContent, completion: completion)
        }
    }

    public func triggerVaultTidy(useMCP: Bool = true, completion: @escaping (Result<String, Error>) -> Void) {
        if useMCP {
            sendViaMCP("vault-tidy", completion: completion)
        } else {
            runSkill(command: "vault-tidy", completion: completion)
        }
    }
}
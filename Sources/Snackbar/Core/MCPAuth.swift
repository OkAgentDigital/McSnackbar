// MCPAuth.swift
// Snackbar
//
// Keychain-based authentication for MCP servers.
// Stores and retrieves bearer tokens using the macOS Keychain,
// and provides request validation middleware for MCP endpoints.
//
// Created by DevStudio Integration

import Foundation
import Security

/// Keychain-based authentication manager for MCP servers.
/// Provides token generation, storage, and validation.
public class MCPAuth: ObservableObject {
    public static let shared = MCPAuth()

    // MARK: - Published State

    /// Whether authentication is enabled for MCP servers.
    @Published public private(set) var isAuthEnabled: Bool = false

    /// The current bearer token (if auth is enabled).
    @Published public private(set) var bearerToken: String = ""

    /// The shared secret for Bonjour peer connections.
    @Published public private(set) var peerSecret: String = ""

    // MARK: - Keychain Constants

    private let keychainService = "com.udos.Snackbar.MCPAuth"
    private let tokenAccount = "mcp-bearer-token"
    private let peerSecretAccount = "mcp-peer-secret"
    private let authEnabledAccount = "mcp-auth-enabled"

    private init() {
        loadFromKeychain()
    }

    // MARK: - Public API

    /// Enable authentication and generate a new bearer token.
    /// - Returns: The generated token.
    @discardableResult
    public func enableAuth() -> String {
        let token = generateToken()
        bearerToken = token
        isAuthEnabled = true
        saveToKeychain()
        print("🔐 MCP Auth enabled — token generated")
        return token
    }

    /// Disable authentication and clear the token.
    public func disableAuth() {
        bearerToken = ""
        isAuthEnabled = false
        saveToKeychain()
        print("🔐 MCP Auth disabled")
    }

    /// Regenerate the bearer token (keeps auth enabled).
    /// - Returns: The new token.
    @discardableResult
    public func regenerateToken() -> String {
        let token = generateToken()
        bearerToken = token
        isAuthEnabled = true
        saveToKeychain()
        print("🔐 MCP Auth token regenerated")
        return token
    }

    /// Validate an incoming request's Authorization header.
    /// - Parameter authorizationHeader: The value of the Authorization header.
    /// - Returns: True if the token is valid or auth is disabled.
    public func validateRequest(authorizationHeader: String?) -> Bool {
        guard isAuthEnabled else { return true }
        guard let header = authorizationHeader else { return false }

        // Support "Bearer <token>" format
        let prefix = "Bearer "
        guard header.hasPrefix(prefix) else { return false }

        let token = String(header.dropFirst(prefix.count))
        return token == bearerToken
    }

    /// Generate or regenerate the peer shared secret.
    /// - Returns: The peer secret.
    @discardableResult
    public func generatePeerSecret() -> String {
        let secret = generateToken(length: 16)
        peerSecret = secret
        saveToKeychain()
        print("🔐 MCP peer secret generated")
        return secret
    }

    /// Validate a peer connection using the shared secret.
    /// - Parameter receivedSecret: The secret received from the peer.
    /// - Returns: True if the secret matches.
    public func validatePeer(receivedSecret: String) -> Bool {
        guard !peerSecret.isEmpty else { return true } // No secret = no validation
        return receivedSecret == peerSecret
    }

    // MARK: - Keychain Operations

    private func saveToKeychain() {
        // Save bearer token
        if !bearerToken.isEmpty {
            saveKeychainItem(account: tokenAccount, data: bearerToken.data(using: .utf8)!)
        }
        // Save peer secret
        if !peerSecret.isEmpty {
            saveKeychainItem(account: peerSecretAccount, data: peerSecret.data(using: .utf8)!)
        }
        // Save auth enabled flag
        let enabledData = isAuthEnabled ? Data([1]) : Data([0])
        saveKeychainItem(account: authEnabledAccount, data: enabledData)
    }

    private func loadFromKeychain() {
        // Load bearer token
        if let data = loadKeychainItem(account: tokenAccount),
           let token = String(data: data, encoding: .utf8) {
            bearerToken = token
        }

        // Load peer secret
        if let data = loadKeychainItem(account: peerSecretAccount),
           let secret = String(data: data, encoding: .utf8) {
            peerSecret = secret
        }

        // Load auth enabled flag
        if let data = loadKeychainItem(account: authEnabledAccount) {
            isAuthEnabled = data.first == 1
        }
    }

    private func saveKeychainItem(account: String, data: Data) {
        // Delete existing item first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new item
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    private func loadKeychainItem(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    // MARK: - Helpers

    /// Generate a cryptographically random token.
    private func generateToken(length: Int = 32) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        guard status == errSecSuccess else {
            // Fallback to UUID-based token if random generation fails
            return UUID().uuidString.replacingOccurrences(of: "-", with: "")
        }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }
}

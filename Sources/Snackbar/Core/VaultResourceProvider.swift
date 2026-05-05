import Foundation

/// 📚 Vault Resource Provider — exposes uDos Vault, Secret Store, and Vendor/Library
/// resources as MCP-accessible content for agents (Xcode, Claude, Hivemind).
///
/// Resource URIs:
///   vault://config            — Vault config.yaml
///   vault://recipes           — Vault recipes.yaml
///   vault://docs/*            — Documents in Vault/docs/
///   vault://feeds/*           — Spool feeds in Vault/feeds/
///   vault://inbox/*           — Inbox items
///   vault://outbox/*          — Outbox items
///   vault://scripts/*         — Scripts in Vault/scripts/
///   vault://specs/*           — Specifications
///   vault://binder/*          — Binder collections
///   secrets://*               — Secret store (from Vault .secrets/)
///   vendor://resources/*      — Vendor/Library resources
///
class VaultResourceProvider: ObservableObject {
    static let shared = VaultResourceProvider()

    @Published private(set) var vaultPath: String = ""
    @Published private(set) var isAccessible: Bool = false

    private let fileManager = FileManager.default

    private init() {
        discoverVault()
    }

    /// Discover the Vault location — checks standard paths.
    private func discoverVault() {
        let candidates = [
            NSString(string: "~/Vault").expandingTildeInPath,
            NSString(string: "~/Documents/Vault").expandingTildeInPath,
            NSString(string: "~/iCloud/Vault").expandingTildeInPath
        ]

        for path in candidates {
            if fileManager.fileExists(atPath: "\(path)/config.yaml") {
                vaultPath = path
                isAccessible = true
                return
            }
        }

        // Fallback: just check if ~/Vault exists
        let defaultPath = NSString(string: "~/Vault").expandingTildeInPath
        if fileManager.fileExists(atPath: defaultPath) {
            vaultPath = defaultPath
            isAccessible = true
        }
    }

    // MARK: - Vault Resources

    /// Get the Vault configuration.
    func getConfig() -> String? {
        return readFile("\(vaultPath)/config.yaml")
    }

    /// Get the recipes file.
    func getRecipes() -> String? {
        return readFile("\(vaultPath)/recipes.yaml")
    }

    /// Get a document from Vault/docs/ by path.
    func getDocument(path: String) -> String? {
        return readFile("\(vaultPath)/docs/\(path)")
    }

    /// Get a feed entry.
    func getFeed(path: String) -> String? {
        return readFile("\(vaultPath)/feeds/\(path)")
    }

    /// Get inbox contents.
    func getInbox() -> [String] {
        return listDirectory("\(vaultPath)/inbox")
    }

    /// Get outbox contents.
    func getOutbox() -> [String] {
        return listDirectory("\(vaultPath)/outbox")
    }

    /// Get a script from Vault/scripts/.
    func getScript(path: String) -> String? {
        return readFile("\(vaultPath)/scripts/\(path)")
    }

    /// Get a spec document.
    func getSpec(path: String) -> String? {
        return readFile("\(vaultPath)/specs/\(path)")
    }

    /// Get a binder collection.
    func getBinder(path: String) -> String? {
        return readFile("\(vaultPath)/binder/\(path)")
    }

    /// List all items in a Vault subdirectory.
    func listDirectory(_ dirPath: String) -> [String] {
        guard fileManager.fileExists(atPath: dirPath),
              let contents = try? fileManager.contentsOfDirectory(atPath: dirPath) else {
            return []
        }
        return contents.sorted()
    }

    // MARK: - Secret Store

    /// Read a secret value. Secrets stored in Vault/.secrets/ or env vars.
    func getSecret(key: String) -> String? {
        // First try environment variable
        if let envValue = ProcessInfo.processInfo.environment[key.uppercased()] {
            return envValue
        }

        // Then try Vault/.secrets/ directory
        let secretsPath = "\(vaultPath)/.secrets"
        if let value = readFile("\(secretsPath)/\(key)") {
            return value.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return nil
    }

    /// List all available secret keys.
    func listSecretKeys() -> [String] {
        let secretsPath = "\(vaultPath)/.secrets"
        guard fileManager.fileExists(atPath: secretsPath),
              let contents = try? fileManager.contentsOfDirectory(atPath: secretsPath) else {
            return []
        }
        return contents.sorted()
    }

    // MARK: - Full Listing

    /// Get a complete listing of all Vault contents (for MCP resource list).
    func getResourceList() -> [[String: String]] {
        guard isAccessible else { return [] }

        var resources: [[String: String]] = []

        // Top-level files
        resources.append(["uri": "vault://config", "name": "Vault Config"])
        resources.append(["uri": "vault://recipes", "name": "Vault Recipes"])

        // Directories
        let dirs = ["docs", "feeds", "inbox", "outbox", "scripts", "specs", "binder"]
        for dir in dirs {
            let items = listDirectory("\(vaultPath)/\(dir)")
            for item in items {
                resources.append([
                    "uri": "vault://\(dir)/\(item)",
                    "name": "Vault/\(dir)/\(item)"
                ])
            }
        }

        // Secrets
        for key in listSecretKeys() {
            resources.append(["uri": "secrets://\(key)", "name": "Secret: \(key)"])
        }

        return resources
    }

    // MARK: - Resource Content

    /// Get the content for any vault:// URI.
    func getContent(for uri: String) -> String? {
        // Parse vault://path
        guard let components = URL(string: uri) else { return nil }

        switch components.scheme {
        case "vault":
            return getVaultContent(path: components.host ?? "", resource: components.path)
        case "secrets":
            return getSecret(key: components.host ?? "")
        case "vendor":
            return getVendorResource(path: (components.host ?? "") + components.path)
        default:
            return nil
        }
    }

    private func getVaultContent(path: String, resource: String) -> String? {
        let fullPath = resource.isEmpty ? path : "\(path)\(resource)"
        switch fullPath {
        case "config":    return getConfig()
        case "recipes":   return getRecipes()
        default:
            return readFile("\(vaultPath)/\(fullPath)")
        }
    }

    // MARK: - Vendor / Library Resources

    /// Get a Vendor/Library resource path.
    private func getVendorResource(path: String) -> String? {
        let searchPaths = [
            NSString(string: "~/Code/Vendor/\(path)").expandingTildeInPath,
            NSString(string: "~/Library/\(path)").expandingTildeInPath,
            "/usr/local/share/\(path)"
        ]

        for fullPath in searchPaths {
            if fileManager.fileExists(atPath: fullPath) {
                return try? String(contentsOfFile: fullPath)
            }
        }
        return nil
    }

    // MARK: - Helpers

    private func readFile(_ path: String) -> String? {
        guard fileManager.fileExists(atPath: path) else { return nil }
        return try? String(contentsOfFile: path)
    }
}

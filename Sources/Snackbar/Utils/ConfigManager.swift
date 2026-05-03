import Foundation

class ConfigManager {
    static let shared = ConfigManager()
    
    private var config: [String: Any] = [:]
    private let projectName: String
    
    init(projectName: String = "Snackbar") {
        self.projectName = projectName
        loadConfig()
    }
    
    private func loadConfig() {
        let fileManager = FileManager.default
        let homeDirectory = fileManager.homeDirectoryForCurrentUser.path
        let centralConfigPath = "\(homeDirectory)/Code/Projects/\(projectName)/config/config.yaml"
        let localConfigPath = "\(fileManager.currentDirectoryPath)/config.yaml"
        
        let configPath: String
        if fileManager.fileExists(atPath: centralConfigPath) {
            configPath = centralConfigPath
        } else if fileManager.fileExists(atPath: localConfigPath) {
            configPath = localConfigPath
        } else {
            print("❌ Configuration file not found at \(centralConfigPath) or \(localConfigPath)")
            config = [:]
            return
        }
        
        do {
            let yamlContent = try String(contentsOfFile: configPath, encoding: .utf8)
            config = parseYAML(yamlContent)
            print("✅ Configuration loaded successfully from \(configPath)")
        } catch {
            print("❌ Failed to load configuration: \(error.localizedDescription)")
            config = [:]
        }
    }
    
    private func parseYAML(_ yaml: String) -> [String: Any] {
        var result: [String: Any] = [:]
        
        // Simple YAML parser for key-value pairs (for demonstration)
        let lines = yaml.components(separatedBy: .newlines)
        var currentSection: String?
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            if trimmedLine.hasPrefix("#") || trimmedLine.isEmpty {
                continue
            }
            
            if trimmedLine.hasSuffix(":") {
                currentSection = String(trimmedLine.dropLast()).trimmingCharacters(in: .whitespaces)
                result[currentSection!] = [:]
            } else if let section = currentSection, trimmedLine.contains(":") {
                let parts = trimmedLine.components(separatedBy: ":")
                guard parts.count >= 2 else { continue }
                
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts[1...].joined(separator: ":").trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                
                if var sectionDict = result[section] as? [String: Any] {
                    sectionDict[key] = value
                    result[section] = sectionDict
                }
            }
        }
        
        return result
    }
    
    func getLeChatAPIKey() -> String? {
        guard let lechatConfig = config["lechat"] as? [String: Any],
              let apiKey = lechatConfig["api_key"] as? String else {
            return nil
        }
        return apiKey
    }
    
    func getLeChatAPIURL() -> String? {
        guard let lechatConfig = config["lechat"] as? [String: Any],
              let apiURL = lechatConfig["api_url"] as? String else {
            return nil
        }
        return apiURL
    }
    
    func isLeChatEnabled() -> Bool {
        guard let lechatConfig = config["lechat"] as? [String: Any],
              let enabled = lechatConfig["enabled"] as? Bool else {
            return false
        }
        return enabled
    }
    
    func getSnackbarConfig() -> [String: Any]? {
        return config["snackbar"] as? [String: Any]
    }
    
    // MARK: - SSH Config Parsing
    
    /// Parse ~/.ssh/config for the Ubuntu server connection details.
    /// Returns a dictionary with host, user, port, identityFile.
    public func parseSSHConfig() -> [String: String] {
        let sshConfigPath = "\(NSHomeDirectory())/.ssh/config"
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: sshConfigPath) else {
            print("⚠️ SSH config not found at \(sshConfigPath)")
            return [:]
        }
        
        do {
            let content = try String(contentsOfFile: sshConfigPath, encoding: .utf8)
            return parseSSHConfigContent(content)
        } catch {
            print("❌ Failed to read SSH config: \(error.localizedDescription)")
            return [:]
        }
    }
    
    private func parseSSHConfigContent(_ content: String) -> [String: String] {
        var config: [String: String] = [:]
        var currentHost: String?
        
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Skip comments and empty lines
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }
            
            // Check for Host directive
            if trimmed.lowercased().hasPrefix("host ") {
                let hostName = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                currentHost = hostName
                continue
            }
            
            // Parse key-value pairs under current host
            if let host = currentHost {
                let parts = trimmed.components(separatedBy: .whitespaces)
                guard parts.count >= 2 else { continue }
                
                let key = parts[0].lowercased()
                let value = parts[1...].joined(separator: " ").trimmingCharacters(in: .whitespaces)
                
                switch key {
                case "hostname":
                    config["\(host).hostname"] = value
                case "user":
                    config["\(host).user"] = value
                case "port":
                    config["\(host).port"] = value
                case "identityfile":
                    config["\(host).identityfile"] = value
                default:
                    break
                }
            }
        }
        
        return config
    }
    
    /// Get the Ubuntu server connection details from SSH config.
    public func getUbuntuSSHConfig() -> (host: String, user: String, port: Int, identityFile: String) {
        let sshConfig = parseSSHConfig()
        
        // Try to find wizard-server or wizard config
        let hostKeys = sshConfig.keys.filter { $0.hasSuffix(".hostname") }
        
        for key in hostKeys {
            let hostPrefix = String(key.dropLast(".hostname".count))
            if hostPrefix.lowercased().contains("wizard") {
                let hostname = sshConfig["\(hostPrefix).hostname"] ?? "192.168.20.11"
                let user = sshConfig["\(hostPrefix).user"] ?? "wizard"
                let port = Int(sshConfig["\(hostPrefix).port"] ?? "22") ?? 22
                let identityFile = sshConfig["\(hostPrefix).identityfile"] ?? "~/.ssh/id_ed25519"
                return (hostname, user, port, identityFile)
            }
        }
        
        // Fallback defaults
        return ("192.168.20.11", "wizard", 22, "~/.ssh/id_ed25519")
    }
    
    // MARK: - Hivemind Configuration
    
    /// Get the HivemindRust configuration.
    public func getHivemindConfig() -> (port: Int, path: String) {
        if let hivemindConfig = config["hivemind"] as? [String: Any] {
            let port = hivemindConfig["port"] as? Int ?? 30000
            let path = hivemindConfig["path"] as? String ?? "\(NSHomeDirectory())/Code/OkAgentDigital/HivemindRust"
            return (port, path)
        }
        return (30000, "\(NSHomeDirectory())/Code/OkAgentDigital/HivemindRust")
    }
}

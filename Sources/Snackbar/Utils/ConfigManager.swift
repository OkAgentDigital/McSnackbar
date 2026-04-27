import Foundation

class ConfigManager {
    static let shared = ConfigManager()
    
    private var config: [String: Any] = [:]
    
    private init() {
        loadConfig()
    }
    
    private func loadConfig() {
        let fileManager = FileManager.default
        let currentDirectory = fileManager.currentDirectoryPath
        let configPath = "\(currentDirectory)/config.yaml"
        
        do {
            let yamlContent = try String(contentsOfFile: configPath, encoding: .utf8)
            config = parseYAML(yamlContent)
            print("✅ Configuration loaded successfully")
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
}
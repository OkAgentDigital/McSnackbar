import Foundation

/// Manages snack definitions loaded from ~/.snacks/ and .state/snacks/
class SnackManager: ObservableObject {
    static let shared = SnackManager()
    
    @Published private(set) var snacks: [SnackV2] = []
    
    private let fileManager = FileManager.default
    private let userSnacksURL: URL
    private let systemSnacksURL: URL
    
    private init() {
        userSnacksURL = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".snacks")
        systemSnacksURL = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".state/snacks")
        refresh()
    }
    
    /// Refresh the snack list from disk.
    func refresh() {
        var allSnacks: [SnackV2] = []
        
        // Load user snacks
        if let userSnacks = loadSnacks(from: userSnacksURL) {
            allSnacks.append(contentsOf: userSnacks)
        }
        
        // Load system snacks
        if let systemSnacks = loadSnacks(from: systemSnacksURL) {
            allSnacks.append(contentsOf: systemSnacks)
        }
        
        DispatchQueue.main.async {
            self.snacks = allSnacks
        }
    }
    
    /// Load .snack YAML files from a directory.
    private func loadSnacks(from directory: URL) -> [SnackV2]? {
        guard fileManager.fileExists(atPath: directory.path),
              let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return nil
        }
        
        return files.filter { $0.pathExtension == "snack" }.compactMap { url in
            guard let content = try? String(contentsOf: url) else { return nil }
            return parseSnackYAML(content, sourceURL: url)
        }
    }
    
    /// Parse a .snack YAML file into a SnackV2 struct.
    private func parseSnackYAML(_ yaml: String, sourceURL: URL) -> SnackV2? {
        var id = ""
        var name = ""
        var version = "1.0.0"
        var runtime = "shell"
        var code = ""
        var inputs: [SnackInput] = []
        var outputs: [SnackOutput] = []
        var emoji = "🍔"
        var tags: [String] = []
        var lexiconTerms: [String] = []
        var lexiconDescription = ""
        var canBeBefore: [String] = []
        var canBeAfter: [String] = []
        var timeoutSecs = 30
        
        var currentSection = ""
        var inCodeBlock = false
        var codeLines: [String] = []
        var inInputBlock = false
        var currentInput: [String: String] = [:]
        var inOutputBlock = false
        var currentOutput: [String: String] = [:]
        var inLexiconBlock = false
        var inChainBlock = false
        
        for line in yaml.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Track sections
            if trimmed == "code: |" {
                currentSection = "code"
                inCodeBlock = true
                codeLines = []
                continue
            }
            if trimmed == "inputs:" { currentSection = "inputs"; inInputBlock = true; continue }
            if trimmed == "outputs:" { currentSection = "outputs"; inOutputBlock = true; continue }
            if trimmed == "lexicon:" { currentSection = "lexicon"; inLexiconBlock = true; continue }
            if trimmed == "chain:" { currentSection = "chain"; inChainBlock = true; continue }
            
            // End of code block
            if inCodeBlock {
                if trimmed.hasPrefix("- ") || trimmed.hasPrefix("inputs:") || trimmed.hasPrefix("outputs:") || trimmed.hasPrefix("emoji:") || trimmed.hasPrefix("tags:") || trimmed.hasPrefix("lexicon:") || trimmed.hasPrefix("chain:") || trimmed.hasPrefix("timeout_secs:") || trimmed.isEmpty && !codeLines.isEmpty && !line.hasPrefix(" ") {
                    inCodeBlock = false
                    code = codeLines.joined(separator: "\n").trimmingCharacters(in: .newlines)
                } else if !trimmed.isEmpty || !codeLines.isEmpty {
                    codeLines.append(line.hasPrefix("  ") ? String(line.dropFirst(2)) : line)
                }
                continue
            }
            
            // Parse key-value pairs
            if let colonIndex = trimmed.firstIndex(of: ":"), !inCodeBlock {
                let key = String(trimmed[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                let value = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                
                switch currentSection {
                case "":
                    switch key {
                    case "id": id = value
                    case "name": name = value
                    case "version": version = value
                    case "runtime": runtime = value
                    case "emoji": emoji = value
                    case "timeout_secs": timeoutSecs = Int(value) ?? 30
                    case "tags":
                        tags = parseYAMLList(value)
                    default: break
                    }
                case "inputs":
                    if key == "- name" { currentInput = ["name": value] }
                    else if let name = currentInput["name"] {
                        if key == "type" { currentInput["type"] = value }
                        else if key == "default" { currentInput["default"] = value }
                        else if key == "required" {
                            currentInput["required"] = value
                            inputs.append(SnackInput(name: currentInput["name"] ?? "", type: currentInput["type"] ?? "string", default: currentInput["default"], required: value == "true"))
                            currentInput = [:]
                        }
                    }
                case "outputs":
                    if key == "- name" { currentOutput = ["name": value] }
                    else if let name = currentOutput["name"] {
                        if key == "type" {
                            currentOutput["type"] = value
                            outputs.append(SnackOutput(name: name, type: value))
                            currentOutput = [:]
                        }
                    }
                case "lexicon":
                    if key == "terms" {
                        lexiconTerms = parseYAMLList(value)
                    } else if key == "description" {
                        lexiconDescription = value
                    }
                case "chain":
                    if key == "can_be_before" {
                        canBeBefore = parseYAMLList(value)
                    } else if key == "can_be_after" {
                        canBeAfter = parseYAMLList(value)
                    }
                default: break
                }
            }
        }
        
        // If code was in the last block
        if inCodeBlock && !codeLines.isEmpty {
            code = codeLines.joined(separator: "\n").trimmingCharacters(in: .newlines)
        }
        
        // Use filename as fallback name
        if name.isEmpty {
            name = sourceURL.deletingPathExtension().lastPathComponent
        }
        if id.isEmpty {
            id = name.lowercased().replacingOccurrences(of: " ", with: "_")
        }
        
        return SnackV2(
            id: id,
            name: name,
            version: version,
            runtime: runtime,
            code: code,
            inputs: inputs,
            outputs: outputs,
            emoji: emoji,
            tags: tags,
            lexicon: SnackLexicon(terms: lexiconTerms, description: lexiconDescription),
            chain: SnackChain(canBeBefore: canBeBefore, canBeAfter: canBeAfter),
            timeoutSecs: timeoutSecs,
            sourceURL: sourceURL
        )
    }
    
    private func parseYAMLList(_ value: String) -> [String] {
        let trimmed = value.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        return trimmed.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        }
    }
    
    // MARK: - Query
    
    func listSnacks() -> [SnackV2] {
        return snacks
    }
    
    func getSnack(byId id: String) -> SnackV2? {
        return snacks.first { $0.id == id }
    }
    
    func getSnack(byName name: String) -> SnackV2? {
        return snacks.first { $0.name.lowercased() == name.lowercased() }
    }
    
    func getSnacksByTag(_ tag: String) -> [SnackV2] {
        return snacks.filter { $0.tags.contains(tag) }
    }
}

// MARK: - Snack V2 Model

struct SnackV2: Identifiable {
    let id: String
    let name: String
    let version: String
    let runtime: String
    let code: String
    let inputs: [SnackInput]
    let outputs: [SnackOutput]
    let emoji: String
    let tags: [String]
    let lexicon: SnackLexicon
    let chain: SnackChain
    let timeoutSecs: Int
    let sourceURL: URL
    
    func toDictionary() -> [String: Any] {
        [
            "id": id,
            "name": name,
            "version": version,
            "runtime": runtime,
            "emoji": emoji,
            "tags": tags,
            "inputs": inputs.map { ["name": $0.name, "type": $0.type, "required": $0.required] },
            "outputs": outputs.map { ["name": $0.name, "type": $0.type] },
            "lexicon": ["terms": lexicon.terms, "description": lexicon.description],
            "chain": ["can_be_before": chain.canBeBefore, "can_be_after": chain.canBeAfter],
            "timeout_secs": timeoutSecs
        ]
    }
}

struct SnackInput {
    let name: String
    let type: String
    let `default`: String?
    let required: Bool
}

struct SnackOutput {
    let name: String
    let type: String
}

struct SnackLexicon {
    let terms: [String]
    let description: String
}

struct SnackChain {
    let canBeBefore: [String]
    let canBeAfter: [String]
}

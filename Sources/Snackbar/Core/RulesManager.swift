import Foundation

/// Manages automation rules stored at
/// ~/Library/Application Support/Snackbar/rules.json
class RulesManager: ObservableObject {
    static let shared = RulesManager()
    
    @Published private(set) var rules: [Rule] = []
    
    private let fileManager = FileManager.default
    private let rulesURL: URL
    private let queue = DispatchQueue(label: "com.snackbar.rules", qos: .utility)
    
    private init() {
        let supportDir = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Snackbar")
        rulesURL = supportDir.appendingPathComponent("rules.json")
        loadRules()
    }
    
    // MARK: - CRUD
    
    func loadRules() {
        queue.sync {
            guard fileManager.fileExists(atPath: rulesURL.path),
                  let data = try? Data(contentsOf: rulesURL),
                  let container = try? JSONDecoder().decode(RuleContainer.self, from: data) else {
                self.rules = []
                return
            }
            DispatchQueue.main.async {
                self.rules = container.rules
            }
        }
    }
    
    func saveRules() {
        queue.async { [weak self] in
            guard let self = self else { return }
            let container = RuleContainer(rules: self.rules)
            if let data = try? JSONEncoder().encode(container) {
                try? data.write(to: self.rulesURL)
            }
        }
    }
    
    func addRule(_ rule: Rule) {
        rules.append(rule)
        saveRules()
    }
    
    func updateRule(_ rule: Rule) {
        guard let index = rules.firstIndex(where: { $0.id == rule.id }) else { return }
        rules[index] = rule
        saveRules()
    }
    
    func deleteRule(id: String) {
        rules.removeAll { $0.id == id }
        saveRules()
    }
    
    func toggleRule(id: String) {
        guard let index = rules.firstIndex(where: { $0.id == id }) else { return }
        rules[index].enabled.toggle()
        saveRules()
    }
    
    func getEnabledRules() -> [Rule] {
        rules.filter { $0.enabled }
    }
    
    // MARK: - Evaluation
    
    /// Evaluate all enabled rules and return actions to execute.
    func evaluateTriggers(snackOutput: (snackId: String, exitCode: Int32)? = nil) -> [RuleAction] {
        var actions: [RuleAction] = []
        let calendar = Calendar.current
        let now = Date()
        
        for rule in getEnabledRules() {
            switch rule.trigger.type {
            case .schedule:
                if let cron = rule.trigger.cron, matchesCron(cron, at: now) {
                    actions.append(rule.action)
                }
                
            case .snack_output:
                guard let output = snackOutput else { continue }
                if rule.trigger.snack_id == output.snackId {
                    // Simple condition: exit code 0 = success
                    if rule.trigger.condition == "exit_code == 0" && output.exitCode == 0 {
                        actions.append(rule.action)
                    } else if rule.trigger.condition == "exit_code != 0" && output.exitCode != 0 {
                        actions.append(rule.action)
                    }
                }
                
            case .file_watch:
                // File watch is evaluated by the scheduler periodically
                if let path = rule.trigger.path {
                    let fileURL = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
                    if let modDate = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate {
                        let elapsed = now.timeIntervalSince(modDate)
                        if elapsed < 60 { // Changed within last minute
                            actions.append(rule.action)
                        }
                    }
                }
                
            case .keyboard_shortcut:
                // Keyboard shortcuts are handled by the app delegate
                break
            }
        }
        
        return actions
    }
    
    // MARK: - Cron Matching
    
    private func matchesCron(_ cron: String, at date: Date) -> Bool {
        let components = cron.split(separator: " ").map(String.init)
        guard components.count >= 5 else { return false }
        
        let calendar = Calendar.current
        let minute = calendar.component(.minute, from: date)
        let hour = calendar.component(.hour, from: date)
        let day = calendar.component(.day, from: date)
        let month = calendar.component(.month, from: date)
        let weekday = calendar.component(.weekday, from: date) - 1 // 0=Sunday
        
        return cronFieldMatches(components[0], value: minute) &&
               cronFieldMatches(components[1], value: hour) &&
               cronFieldMatches(components[2], value: day) &&
               cronFieldMatches(components[3], value: month) &&
               cronFieldMatches(components[4], value: weekday)
    }
    
    private func cronFieldMatches(_ field: String, value: Int) -> Bool {
        if field == "*" { return true }
        if field.contains("/") {
            let parts = field.split(separator: "/")
            if parts.count == 2, let step = Int(parts[1]) {
                return value % step == 0
            }
        }
        if field.contains("-") {
            let parts = field.split(separator: "-")
            if parts.count == 2, let low = Int(parts[0]), let high = Int(parts[1]) {
                return value >= low && value <= high
            }
        }
        if field.contains(",") {
            return field.split(separator: ",").contains(where: { Int($0) == value })
        }
        return Int(field) == value
    }
}

// MARK: - Data Models

struct RuleContainer: Codable {
    let rules: [Rule]
}

struct Rule: Codable, Identifiable {
    let id: String
    var name: String
    var enabled: Bool
    let trigger: RuleTrigger
    let action: RuleAction
    
    enum CodingKeys: String, CodingKey {
        case id, name, enabled, trigger, action
    }
}

struct RuleTrigger: Codable {
    let type: TriggerType
    let snack_id: String?
    let condition: String?
    let cron: String?
    let path: String?
    let shortcut: String?
    
    enum TriggerType: String, Codable {
        case schedule
        case snack_output
        case file_watch
        case keyboard_shortcut
    }
}

struct RuleAction: Codable {
    let type: ActionType
    let snack_id: String?
    let params: [String: AnyCodable]?
    let shortcut_name: String?
    let notification_title: String?
    let notification_body: String?
    let script: String?
    
    enum ActionType: String, Codable {
        case run_snack
        case run_shortcut
        case notify
        case script
    }
}

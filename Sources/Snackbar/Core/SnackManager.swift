import Foundation
import AppKit

@MainActor
class SnackManager: ObservableObject {
    static let shared = SnackManager()
    
    @Published var snacks: [Snack] = []
    @Published var badges: [String: String] = [:]
    
    private let userDefaultsKey = "SnackbarSnacks"
    private var timers: [String: Timer] = [:]
    
    private init() {
        loadSnacks()
        startTimers()
    }
    
    // MARK: - Persistence
    
    func loadSnacks() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let saved = try? JSONDecoder().decode([Snack].self, from: data) {
            snacks = saved
        } else {
            snacks = Snack.defaultSnacks
            saveSnacks()
        }
    }
    
    func saveSnacks() {
        if let data = try? JSONEncoder().encode(snacks) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
    
    // MARK: - Toggle
    
    func toggleSnack(_ id: String) {
        if let index = snacks.firstIndex(where: { $0.id == id }) {
            snacks[index].isEnabled.toggle()
            saveSnacks()
            
            if snacks[index].isEnabled {
                startTimer(for: snacks[index])
                runSnack(snacks[index])
            } else {
                stopTimer(for: id)
            }
        }
    }
    
    func updateRefreshInterval(for id: String, interval: Int) {
        if let index = snacks.firstIndex(where: { $0.id == id }) {
            snacks[index].refreshInterval = interval
            saveSnacks()
            if snacks[index].isEnabled {
                startTimer(for: snacks[index])
                runSnack(snacks[index])
            }
        }
    }
    
    // MARK: - Execution
    
    func runSnack(_ snack: Snack) {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let result = executeAppleScript(snack.script)
        let duration = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
        
        let status = result != nil ? "success" : "error"
        let output = result ?? "Script execution failed"
        
        // Update badge
        DispatchQueue.main.async {
            self.badges[snack.id] = output
        }
        
        // Log to spool
        let entry = SpoolEntry(snack: snack.id, status: status, output: output, durationMs: duration)
        SpoolWriter.shared.log(entry: entry)
    }
    
    private func executeAppleScript(_ script: String) -> String? {
        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        let result = appleScript?.executeAndReturnError(&error)
        
        if let error = error {
            print("AppleScript error: \(error)")
            return nil
        }
        
        return result?.stringValue
    }
    
    // MARK: - Badge Formatting
    
    func formattedBadge(for snack: Snack) -> String {
        guard let output = badges[snack.id] else { return "" }
        
        switch snack.id {
        case "reminders":
            if let count = Int(output), count > 0 {
                return "(\(count))"
            }
            return ""
        case "mail-vip":
            if let count = Int(output), count > 0 {
                return "(\(count))"
            }
            return ""
        case "contacts":
            if !output.isEmpty {
                return ": \(output)"
            }
            return ""
        default:
            return ""
        }
    }
    
    // MARK: - Timers
    
    func startTimers() {
        for snack in snacks where snack.isEnabled {
            startTimer(for: snack)
        }
    }
    
    private func startTimer(for snack: Snack) {
        stopTimer(for: snack.id)
        
        let timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(snack.refreshInterval), repeats: true) { [weak self] _ in
            self?.runSnack(snack)
        }
        timers[snack.id] = timer
        
        // Run immediately
        runSnack(snack)
    }
    
    private func stopTimer(for id: String) {
        timers[id]?.invalidate()
        timers[id] = nil
    }
    
    func stopAllTimers() {
        timers.values.forEach { $0.invalidate() }
        timers.removeAll()
    }
}

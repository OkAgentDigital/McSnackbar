import AppKit
import Foundation

@MainActor
class SnackManager: ObservableObject {
    static let shared = SnackManager()

    @Published var snacks: [Snack] = []
    @Published var badges: [String: String] = [:]
    @Published var launchAtStartup: Bool = false

    let updateChecker = UpdateChecker.shared

    private let userDefaultsKey = "SnackbarSnacks"
    private var timers: [String: Timer] = [:]

    private init() {
        loadSnacks()
        launchAtStartup = LaunchAtStartupManager.shared.isEnabled
        // Timers are started by AppDelegate after a short delay on launch,
        // to avoid triggering a flurry of simultaneous permission prompts.
        // startTimers() is called from AppDelegate.applicationDidFinishLaunching()
    }

    // MARK: - Launch at Startup

    func toggleLaunchAtStartup() {
        launchAtStartup.toggle()
        LaunchAtStartupManager.shared.isEnabled = launchAtStartup
        objectWillChange.send()
    }

    // MARK: - Persistence

    func loadSnacks() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
            let saved = try? JSONDecoder().decode([Snack].self, from: data)
        {
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
        let entry = SpoolEntry(
            snack: snack.id, status: status, output: output, durationMs: duration)
        SpoolWriter.shared.log(entry: entry)
    }

    private func executeAppleScript(_ script: String) -> String? {
        // Use osascript subprocess instead of NSAppleScript to avoid
        // stealing window focus from the user. NSAppleScript runs in-process
        // and can cause macOS to activate/focus the target application.
        let process = Process()
        process.launchPath = "/usr/bin/osascript"
        process.arguments = ["-e", script, "-e", "return"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(
                in: .whitespacesAndNewlines)

            if process.terminationStatus != 0 {
                print(
                    "osascript error (status \(process.terminationStatus)): \(output ?? "unknown")")
                return nil
            }

            return output?.isEmpty == true ? nil : output
        } catch {
            print("osascript execution error: \(error.localizedDescription)")
            return nil
        }
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

        let timer = Timer.scheduledTimer(
            withTimeInterval: TimeInterval(snack.refreshInterval), repeats: true
        ) { [weak self] _ in
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

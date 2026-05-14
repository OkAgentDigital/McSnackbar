import AppKit
import Combine
import Foundation
import Combine

struct GitHubRelease: Codable {
    let tag_name: String
    let html_url: String
    let published_at: String
    let body: String?
}

@MainActor
class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    private let repoOwner = "OkAgentDigital"
    private let repoName = "Snackbar"
    private let userDefaultsCheckKey = "SnackbarLastUpdateCheck"
    private let userDefaultsIntervalKey = "SnackbarUpdateInterval"

    @Published var isChecking = false
    @Published var lastCheckDate: Date? {
        didSet {
            UserDefaults.standard.set(
                lastCheckDate?.timeIntervalSince1970, forKey: userDefaultsCheckKey)
        }
    }
    @Published var updateInterval: TimeInterval = 86400  // default: daily
    @Published var updateAvailable: (version: String, url: String, body: String?)? = nil

    private var periodicTimer: Timer?

    private init() {
        if let ts = UserDefaults.standard.object(forKey: userDefaultsCheckKey) as? TimeInterval {
            lastCheckDate = Date(timeIntervalSince1970: ts)
        }
        let saved = UserDefaults.standard.double(forKey: userDefaultsIntervalKey)
        if saved > 0 { updateInterval = saved }
    }

    // MARK: - Interval

    var availableIntervals: [(label: String, value: TimeInterval)] {
        [
            ("Never", 0),
            ("Every hour", 3600),
            ("Every 6 hours", 21600),
            ("Daily", 86400),
            ("Weekly", 604800),
        ]
    }

    func setUpdateInterval(_ interval: TimeInterval) {
        updateInterval = interval
        UserDefaults.standard.set(interval, forKey: userDefaultsIntervalKey)
        restartPeriodicChecks()
    }

    // MARK: - Single Check

    func checkForUpdates(silent: Bool = false) {
        guard !isChecking else { return }
        isChecking = true

        Task {
            defer {
                Task { @MainActor [weak self] in
                    self?.isChecking = false
                }
            }

            let url = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest")!
            var request = URLRequest(url: url)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
            request.timeoutInterval = 15

            do {
                // Perform network call off the main actor
                let (data, _) = try await URLSession.shared.data(for: request)

                // Decode off the main actor to avoid main-actor isolated conformance issues
                let release = try JSONDecoder().decode(GitHubRelease.self, from: data)

                await MainActor.run {
                    self.lastCheckDate = Date()

                    let latestVersion = release.tag_name.replacingOccurrences(of: "v", with: "")
                    guard let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
                        return
                    }

                    if self.isVersion(latestVersion, greaterThan: currentVersion) {
                        self.updateAvailable = (
                            version: latestVersion,
                            url: release.html_url,
                            body: release.body
                        )
                        if !silent {
                            self.showUpdateNotification(version: latestVersion, url: release.html_url, body: release.body)
                        }
                    } else {
                        self.updateAvailable = nil
                        if !silent {
                            self.showAlert(title: "Up to Date", message: "Snackbar \(currentVersion) is the latest version.")
                        }
                    }
                }
            } catch {
                print("⚠️ Update check failed: \(error.localizedDescription)")
                if !silent {
                    await MainActor.run {
                        self.showAlert(title: "Update Check Failed", message: "Could not reach GitHub: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    // MARK: - Periodic Checks

    func startPeriodicChecks() {
        guard updateInterval > 0 else { return }
        stopPeriodicChecks()
        checkForUpdates(silent: true)
        periodicTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) {
            [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkForUpdates(silent: true)
            }
        }
    }

    func stopPeriodicChecks() {
        periodicTimer?.invalidate()
        periodicTimer = nil
    }

    func restartPeriodicChecks() {
        guard updateInterval > 0 else {
            stopPeriodicChecks()
            return
        }
        startPeriodicChecks()
    }

    // MARK: - Version Comparison

    private func isVersion(_ newVersion: String, greaterThan currentVersion: String) -> Bool {
        let newComponents = newVersion.split(separator: ".").compactMap { Int($0) }
        let currentComponents = currentVersion.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(newComponents.count, currentComponents.count) {
            let new = i < newComponents.count ? newComponents[i] : 0
            let current = i < currentComponents.count ? currentComponents[i] : 0
            if new > current { return true }
            if new < current { return false }
        }
        return false
    }

    // MARK: - UI

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func showUpdateNotification(version: String, url: String, body: String? = nil) {
        let alert = NSAlert()
        alert.messageText = "🍔 Snackbar Update Available"
        alert.informativeText = "Version \(version) is ready for download."

        if let releaseBody = body, !releaseBody.isEmpty {
            let preview = String(releaseBody.prefix(300))
            alert.informativeText += "\n\n\(preview)"
        }

        alert.alertStyle = .informational
        alert.addButton(withTitle: "Download")
        alert.addButton(withTitle: "Later")

        if alert.runModal() == .alertFirstButtonReturn {
            if let downloadURL = URL(string: url) {
                NSWorkspace.shared.open(downloadURL)
            }
        }
    }
}


import Foundation
import AppKit

struct GitHubRelease: Codable {
    let tag_name: String
    let html_url: String
    let published_at: String
    let body: String?
}

class UpdateChecker {
    static let shared = UpdateChecker()
    private let repoOwner = "OkAgentDigital"
    private let repoName = "Snackbar"

    private var periodicTimer: Timer?
    private var isChecking = false

    // MARK: - Single Check

    /// Check for updates once. Shows a notification if an update is available.
    /// - Parameter silent: If true, only logs results instead of showing UI when up-to-date.
    func checkForUpdates(silent: Bool = false) {
        guard !isChecking else { return }
        isChecking = true

        let url = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.timeoutInterval = 15

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            defer { self?.isChecking = false }

            guard let self = self else { return }

            if let error = error {
                print("⚠️ Update check failed: \(error.localizedDescription)")
                return
            }

            guard let data = data,
                  let release = try? JSONDecoder().decode(GitHubRelease.self, from: data) else {
                print("⚠️ Update check failed or no release found")
                return
            }

            let latestVersion = release.tag_name.replacingOccurrences(of: "v", with: "")
            guard let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
                return
            }

            // Record the check time
            SnackbarSettings.shared.lastUpdateCheck = Date()

            if self.isVersion(latestVersion, greaterThan: currentVersion) {
                DispatchQueue.main.async {
                    self.showUpdateNotification(version: latestVersion, url: release.html_url, body: release.body)
                }
            } else {
                if !silent {
                    print("✅ Snackbar is up to date (\(currentVersion))")
                }
            }
        }.resume()
    }

    // MARK: - Periodic Checks

    /// Start periodic update checks based on the user's configured interval.
    func startPeriodicChecks() {
        stopPeriodicChecks()

        let interval = SnackbarSettings.shared.updateInterval

        // Do an initial check on startup (silent)
        checkForUpdates(silent: true)

        periodicTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.checkForUpdates(silent: true)
        }

        print("⏰ UpdateChecker: periodic checks every \(Int(interval / 3600))h")
    }

    /// Stop periodic update checks.
    func stopPeriodicChecks() {
        periodicTimer?.invalidate()
        periodicTimer = nil
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

    // MARK: - Notification

    private func showUpdateNotification(version: String, url: String, body: String? = nil) {
        let alert = NSAlert()
        alert.messageText = "🍔 Snackbar Update Available"
        alert.informativeText = "Version \(version) is now available. You are currently on \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")."

        // Add release notes preview if available
        if let releaseBody = body, !releaseBody.isEmpty {
            let preview = String(releaseBody.prefix(200))
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

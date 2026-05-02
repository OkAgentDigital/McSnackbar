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
    
    func checkForUpdates() {
        let url = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data,
                  let release = try? JSONDecoder().decode(GitHubRelease.self, from: data) else {
                print("⚠️ Update check failed or no release found")
                return
            }
            
            let latestVersion = release.tag_name.replacingOccurrences(of: "v", with: "")
            guard let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
                return
            }
            
            if self.isVersion(latestVersion, greaterThan: currentVersion) {
                DispatchQueue.main.async {
                    self.showUpdateNotification(version: latestVersion, url: release.html_url)
                }
            } else {
                print("✅ Snackbar is up to date (\(currentVersion))")
            }
        }.resume()
    }
    
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
    
    private func showUpdateNotification(version: String, url: String) {
        let alert = NSAlert()
        alert.messageText = "Snackbar Update Available"
        alert.informativeText = "Version \(version) is now available. You are currently on \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")."
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

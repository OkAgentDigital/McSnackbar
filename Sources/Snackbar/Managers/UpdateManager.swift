import Foundation
import AppKit

class UpdateManager: ObservableObject {
    @Published var updateAvailable = false
    @Published var latestVersion = ""
    
    func checkForUpdates() {
        let url = URL(string: "https://api.github.com/repos/fredporter/Snackbar/releases/latest")!
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data,
                  let release = try? JSONDecoder().decode(Release.self, from: data),
                  let latest = release.tag_name else { return }
            
            let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
            
            DispatchQueue.main.async {
                if latest > current {
                    self.updateAvailable = true
                    self.latestVersion = latest
                }
            }
        }.resume()
    }
    
    func openDownloadPage() {
        let url = URL(string: "https://github.com/fredporter/Snackbar/releases/latest")!
        NSWorkspace.shared.open(url)
    }
}

struct Release: Codable {
    let tag_name: String?
    let name: String?
}

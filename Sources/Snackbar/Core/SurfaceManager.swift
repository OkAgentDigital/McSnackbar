import Foundation

/// A USXD surface discovered from uDosGo or DevStudio.
struct Surface: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let description: String
    let source: SurfaceSource
    let fileURL: URL
    var isEnabled: Bool

    enum SurfaceSource: String, Codable, Equatable {
        case uDosGo = "uDosGo"
        case devStudio = "DevStudio"
    }
}

/// Manages discovery and state of USXD surfaces from uDosGo and DevStudio.
class SurfaceManager: ObservableObject {
    static let shared = SurfaceManager()

    @Published var uDosGoSurfaces: [Surface] = []
    @Published var devStudioSurfaces: [Surface] = []

    /// Whether the Gift Wrapper (uDosGo surfaces) snack is enabled.
    @Published var giftWrapperEnabled: Bool {
        didSet {
            UserDefaults.standard.set(giftWrapperEnabled, forKey: "snackbar_giftWrapperEnabled")
            if giftWrapperEnabled { discoverSurfaces() }
        }
    }

    /// Whether the DevStudio Surfaces snack is enabled.
    @Published var devStudioSurfacesEnabled: Bool {
        didSet {
            UserDefaults.standard.set(devStudioSurfacesEnabled, forKey: "snackbar_devStudioSurfacesEnabled")
            if devStudioSurfacesEnabled { discoverSurfaces() }
        }
    }

    private let uDosGoSurfacesPath: String
    private let devStudioConfigPath: String

    private init() {
        self.giftWrapperEnabled = UserDefaults.standard.object(forKey: "snackbar_giftWrapperEnabled") as? Bool ?? false
        self.devStudioSurfacesEnabled = UserDefaults.standard.object(forKey: "snackbar_devStudioSurfacesEnabled") as? Bool ?? false
        self.uDosGoSurfacesPath = "\(NSHomeDirectory())/Code/uDosGo/surfaces"
        self.devStudioConfigPath = "\(NSHomeDirectory())/Code/DevStudio/config"
        discoverSurfaces()
    }

    /// Discover surfaces from uDosGo and DevStudio.
    func discoverSurfaces() {
        uDosGoSurfaces = discoverSurfaces(from: uDosGoSurfacesPath, source: .uDosGo)
        devStudioSurfaces = discoverDevStudioSurfaces()
    }

    /// Toggle a specific surface on/off.
    func toggleSurface(_ surface: Surface, enabled: Bool) {
        if surface.source == .uDosGo {
            if let idx = uDosGoSurfaces.firstIndex(where: { $0.id == surface.id }) {
                uDosGoSurfaces[idx].isEnabled = enabled
                saveSurfaceStates()
            }
        } else {
            if let idx = devStudioSurfaces.firstIndex(where: { $0.id == surface.id }) {
                devStudioSurfaces[idx].isEnabled = enabled
                saveSurfaceStates()
            }
        }
    }

    /// Get all enabled surfaces.
    var enabledSurfaces: [Surface] {
        (uDosGoSurfaces + devStudioSurfaces).filter { $0.isEnabled }
    }

    // MARK: - Private

    private func discoverSurfaces(from directory: String, source: Surface.SurfaceSource) -> [Surface] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: directory),
              let files = try? fm.contentsOfDirectory(atPath: directory) else {
            return []
        }

        let savedStates = loadSurfaceStates()

        return files
            .filter { $0.hasSuffix(".md") }
            .compactMap { filename -> Surface? in
                let url = URL(fileURLWithPath: "\(directory)/\(filename)")
                guard let content = try? String(contentsOf: url) else { return nil }

                let name = filename.replacingOccurrences(of: ".md", with: "")
                let id = "\(source.rawValue.lowercased())_\(name)"

                // Extract description from first line or USXD metadata
                let description = extractDescription(from: content) ?? name

                let isEnabled = savedStates.isEmpty || savedStates[id] ?? true

                return Surface(
                    id: id,
                    name: name,
                    description: description,
                    source: source,
                    fileURL: url,
                    isEnabled: isEnabled
                )
            }
            .sorted { $0.name < $1.name }
    }

    private func discoverDevStudioSurfaces() -> [Surface] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: devStudioConfigPath),
              let files = try? fm.contentsOfDirectory(atPath: devStudioConfigPath) else {
            return []
        }

        let savedStates = loadSurfaceStates()

        return files
            .filter { $0.hasSuffix(".yaml") || $0.hasSuffix(".sh") }
            .compactMap { filename -> Surface? in
                let url = URL(fileURLWithPath: "\(devStudioConfigPath)/\(filename)")
                let name = filename.replacingOccurrences(of: ".yaml", with: "").replacingOccurrences(of: ".sh", with: "")
                let id = "devstudio_\(name)"

                let description: String
                if filename == "narrator.yaml" {
                    description = "Narrator configuration for DevStudio"
                } else if filename == "ubuntu-secret-helper.sh" {
                    description = "Ubuntu secret helper script"
                } else if filename == "vault-publish" {
                    description = "Vault publishing tool"
                } else {
                    description = "DevStudio config: \(name)"
                }

                let isEnabled = savedStates.isEmpty || savedStates[id] ?? true

                return Surface(
                    id: id,
                    name: name,
                    description: description,
                    source: .devStudio,
                    fileURL: url,
                    isEnabled: isEnabled
                )
            }
            .sorted { $0.name < $1.name }
    }

    private func extractDescription(from content: String) -> String? {
        let lines = content.components(separatedBy: .newlines)
        // First non-empty, non-comment line after the title
        var foundTitle = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("# ") && !foundTitle {
                foundTitle = true
                continue
            }
            if foundTitle && !trimmed.isEmpty && !trimmed.hasPrefix("#") && !trimmed.hasPrefix("```") {
                return trimmed
            }
        }
        return nil
    }

    // MARK: - Persistence

    private func surfaceStatesURL() -> URL {
        let appSupport = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/com.udos.Snackbar")
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        return appSupport.appendingPathComponent("surface_states.json")
    }

    private func loadSurfaceStates() -> [String: Bool] {
        let url = surfaceStatesURL()
        guard let data = try? Data(contentsOf: url),
              let states = try? JSONDecoder().decode([String: Bool].self, from: data) else {
            return [:]
        }
        return states
    }

    private func saveSurfaceStates() {
        var states: [String: Bool] = [:]
        for surface in uDosGoSurfaces {
            states[surface.id] = surface.isEnabled
        }
        for surface in devStudioSurfaces {
            states[surface.id] = surface.isEnabled
        }
        if let data = try? JSONEncoder().encode(states) {
            try? data.write(to: surfaceStatesURL())
        }
    }
}

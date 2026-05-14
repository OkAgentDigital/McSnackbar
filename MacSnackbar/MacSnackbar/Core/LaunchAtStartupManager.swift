import Foundation
import ServiceManagement

/// Manages the "Launch at Startup" setting for Snackbar.
/// Uses SMAppService (macOS 13+) to register/unregister the app as a login item.
/// Falls back gracefully on older systems.
@MainActor
class LaunchAtStartupManager {
    static let shared = LaunchAtStartupManager()

    private let userDefaultsKey = "SnackbarLaunchAtStartup"

    private init() {}

    // MARK: - Check

    /// Whether Snackbar is currently registered as a login item.
    var isEnabled: Bool {
        get {
            if #available(macOS 13.0, *) {
                return SMAppService.mainApp.status == .enabled
            } else {
                return UserDefaults.standard.bool(forKey: userDefaultsKey)
            }
        }
        set {
            if #available(macOS 13.0, *) {
                setEnabledSMAppService(newValue)
            } else {
                UserDefaults.standard.set(newValue, forKey: userDefaultsKey)
            }
        }
    }

    // MARK: - SMAppService (macOS 13+)

    @available(macOS 13.0, *)
    private func setEnabledSMAppService(_ enabled: Bool) {
        if enabled {
            do {
                try SMAppService.mainApp.register()
            } catch {
                print("Failed to register login item: \(error.localizedDescription)")
            }
        } else {
            do {
                try SMAppService.mainApp.unregister()
            } catch {
                print("Failed to unregister login item: \(error.localizedDescription)")
            }
        }
    }
}

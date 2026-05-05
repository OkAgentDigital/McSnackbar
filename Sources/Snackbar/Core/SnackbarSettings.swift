import Foundation

/// 🍔 Snackbar Settings — persisted via UserDefaults.
/// Controls auto-launch, update checking, and other preferences.
class SnackbarSettings: ObservableObject {
    static let shared = SnackbarSettings()

    // MARK: - Keys
    private enum Key: String {
        case autoLaunch      = "snackbar_autoLaunch"
        case autoUpdate      = "snackbar_autoUpdate"
        case lastUpdateCheck = "snackbar_lastUpdateCheck"
        case updateInterval  = "snackbar_updateInterval"
    }

    // MARK: - Published Properties

    /// Automatically start Snackbar when the user logs in.
    @Published var autoLaunch: Bool {
        didSet {
            UserDefaults.standard.set(autoLaunch, forKey: Key.autoLaunch.rawValue)
            AutoLaunchManager.shared.setEnabled(autoLaunch)
        }
    }

    /// Automatically check for updates on startup and periodically.
    @Published var autoUpdate: Bool {
        didSet {
            UserDefaults.standard.set(autoUpdate, forKey: Key.autoUpdate.rawValue)
            if autoUpdate {
                UpdateChecker.shared.startPeriodicChecks()
            } else {
                UpdateChecker.shared.stopPeriodicChecks()
            }
        }
    }

    /// How often to check for updates (in seconds). Default: 24 hours.
    @Published var updateInterval: TimeInterval {
        didSet {
            UserDefaults.standard.set(updateInterval, forKey: Key.updateInterval.rawValue)
        }
    }

    /// When we last checked for an update.
    @Published var lastUpdateCheck: Date? {
        didSet {
            UserDefaults.standard.set(lastUpdateCheck, forKey: Key.lastUpdateCheck.rawValue)
        }
    }

    // MARK: - Init

    private init() {
        let defaults = UserDefaults.standard

        self.autoLaunch = defaults.object(forKey: Key.autoLaunch.rawValue) as? Bool ?? false
        self.autoUpdate = defaults.object(forKey: Key.autoUpdate.rawValue) as? Bool ?? true
        self.updateInterval = defaults.object(forKey: Key.updateInterval.rawValue) as? TimeInterval ?? 86400 // 24h
        self.lastUpdateCheck = defaults.object(forKey: Key.lastUpdateCheck.rawValue) as? Date
    }

    // MARK: - Apply on Startup

    /// Called at app launch to apply saved settings.
    func applyOnStartup() {
        // Sync auto-launch state
        AutoLaunchManager.shared.setEnabled(autoLaunch)

        // Start periodic update checks if enabled
        if autoUpdate {
            UpdateChecker.shared.startPeriodicChecks()
        }
    }
}

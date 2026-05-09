import Foundation
import AppKit
import ServiceManagement

/// 🚀 AutoLaunchManager — registers/unregisters Snackbar as a Login Item.
///
/// Uses SMAppService (macOS 13+) when available, falls back to
/// the legacy LSSharedFileList / LaunchAgent plist approach.
class AutoLaunchManager {
    static let shared = AutoLaunchManager()

    private let bundleURL: URL

    private init() {
        self.bundleURL = Bundle.main.bundleURL
    }

    // MARK: - Public API

    /// Enable or disable auto-launch at login.
    func setEnabled(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            setEnabledModern(enabled)
        } else {
            setEnabledLegacy(enabled)
        }
    }

    /// Check if auto-launch is currently enabled.
    var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            return isLegacyLoginItemEnabled
        }
    }

    // MARK: - Modern API (macOS 13+)

    @available(macOS 13.0, *)
    private func setEnabledModern(_ enabled: Bool) {
        let service = SMAppService.mainApp
        do {
            if enabled {
                if service.status != .enabled {
                    try service.register()
                    print("✅ AutoLaunch: registered via SMAppService")
                } else {
                    print("ℹ️ AutoLaunch: already registered")
                }
            } else {
                if service.status == .enabled {
                    try service.unregister()
                    print("✅ AutoLaunch: unregistered via SMAppService")
                } else {
                    print("ℹ️ AutoLaunch: already unregistered")
                }
            }
        } catch {
            print("❌ AutoLaunch: SMAppService error: \(error.localizedDescription)")
            // Fallback to legacy method
            setEnabledLegacy(enabled)
        }
    }

    // MARK: - Legacy API (macOS 10.x – 12.x)

    /// Use LSSharedFileList to add/remove from Login Items.
    private func setEnabledLegacy(_ enabled: Bool) {
        guard let loginItems = LSSharedFileListCreate(
            nil,
            kLSSharedFileListSessionLoginItems.takeRetainedValue(),
            nil
        )?.takeRetainedValue() else {
            print("❌ AutoLaunch: could not access Login Items list")
            return
        }

        if enabled {
            // Add to login items
            let itemURL = bundleURL as CFURL
            LSSharedFileListInsertItemURL(
                loginItems,
                kLSSharedFileListItemLast.takeRetainedValue(),
                nil,
                nil,
                itemURL,
                nil,
                nil
            )
            print("✅ AutoLaunch: added to Login Items (legacy)")
        } else {
            // Remove from login items
            let snapshot = LSSharedFileListCopySnapshot(loginItems, nil)?.takeRetainedValue() as? [LSSharedFileListItem] ?? []
            let itemURL = bundleURL as CFURL

            for item in snapshot {
                let resolution = LSSharedFileListItemCopyResolvedURL(item, 0, nil)
                if let resolvedURL = resolution?.takeRetainedValue() {
                    if (resolvedURL as NSURL) == (itemURL as NSURL) {
                        LSSharedFileListItemRemove(loginItems, item)
                        print("✅ AutoLaunch: removed from Login Items (legacy)")
                        return
                    }
                }
            }
            print("ℹ️ AutoLaunch: not found in Login Items")
        }
    }

    /// Check legacy login item status.
    private var isLegacyLoginItemEnabled: Bool {
        guard let loginItems = LSSharedFileListCreate(
            nil,
            kLSSharedFileListSessionLoginItems.takeRetainedValue(),
            nil
        )?.takeRetainedValue() else { return false }

        let snapshot = LSSharedFileListCopySnapshot(loginItems, nil)?.takeRetainedValue() as? [LSSharedFileListItem] ?? []
        let itemURL = bundleURL as CFURL

        for item in snapshot {
            let resolution = LSSharedFileListItemCopyResolvedURL(item, 0, nil)
            if let resolvedURL = resolution?.takeRetainedValue() {
                if (resolvedURL as NSURL) == (itemURL as NSURL) {
                    return true
                }
            }
        }
        return false
    }
}

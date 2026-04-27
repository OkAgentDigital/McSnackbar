import AppKit

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var menuBuilder: MenuBuilder?
    private var snackScheduler: SnackScheduler?
    var feedManager: FeedManager?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🍔 Snackbar Pro - Launching...")
        
        // Load configuration
        let configManager = ConfigManager.shared
        let lechatConfig = configManager.getSnackbarConfig()
        
        if configManager.isLeChatEnabled() {
            print("✅ LeChat Pro API enabled")
        } else {
            print("ℹ️ LeChat Pro API disabled")
        }
        
        // Initialize components
        menuBuilder = MenuBuilder()
        snackScheduler = SnackScheduler(menuBuilder: menuBuilder!)
        feedManager = FeedManager()
        
        // Set up status bar
        setupStatusBar()
        
        // Request permissions
        PermissionsManager.requestAutomationPermission()
        
        print("✅ Snackbar Pro is ready!")
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.title = "🍔"
        statusItem?.button?.action = #selector(toggleMenu)
        statusItem?.button?.target = self
    }
    
    @objc private func toggleMenu() {
        guard let menu = menuBuilder?.buildMenu() else { return }
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        print("👋 Snackbar Pro is shutting down...")
        snackScheduler?.cancelAllSchedules()
    }
    
    // MARK: - View Presentation Methods
    
    func showAddSnackView() {
        print("📋 Showing Add Snack View - Would open window to add new snack")
        // In full implementation, this would open a SwiftUI window
        let alert = NSAlert()
        alert.messageText = "Add New Snack"
        alert.informativeText = "This feature will be implemented in the full version"
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    func showImportExportView() {
        print("📁 Showing Import/Export View - Would open import/export window")
        let alert = NSAlert()
        alert.messageText = "Import/Export Snacks"
        alert.informativeText = "This feature will be implemented in the full version"
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    func showAboutView() {
        print("ℹ️ Showing About View")
        let alert = NSAlert()
        alert.messageText = "About Snackbar Pro"
        alert.informativeText = "A powerful macOS menu bar automation tool\nVersion 1.0 - Expanded Edition"
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    func showPreferencesView() {
        print("⚙️ Showing Preferences View - Would open preferences window")
        let alert = NSAlert()
        alert.messageText = "Preferences"
        alert.informativeText = "This feature will be implemented in the full version"
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
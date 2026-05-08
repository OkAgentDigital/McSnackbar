import AppKit
import SwiftUI

/// Snackmachine — minimal menu bar automator.
/// One icon. One spool. Infinite snacks. One narrator.
class SnackbarAppDelegate: NSObject, NSApplicationDelegate {
    
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var snackStatuses: [String: SnackStatus] = [:]
    
    // Core
    private let snackManager = SnackManager.shared
    private let spoolManager = SpoolManager.shared
    private let mcpServer = MCPServer.shared
    private let mcpManager = MCPManager.shared
    private let vaultProvider = VaultResourceProvider.shared
    private let hivemindClient = HivemindClient.shared
    private let ubuntuProxy = UbuntuProxy.shared
    private let surfaceManager = SurfaceManager.shared
    private let bonjourService = BonjourService.shared
    
    // MARK: - Lifecycle
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupMenu()
        
        // Apply saved settings (auto-launch, auto-update)
        SnackbarSettings.shared.applyOnStartup()
        
        // Start Snackbar's own MCP server (port 8765)
        mcpServer.start()
        
        // Auto-start HivemindRust gateway (port 3010) so Cline/Xcode can connect
        mcpManager.startHivemind(port: 3010)
        
        // Start health checks and client connections
        mcpManager.startHealthChecks()
        hivemindClient.connect()
        ubuntuProxy.startMonitoring()
        
        // Auto-discover surfaces
        surfaceManager.discoverSurfaces()
        
        // Start Bonjour service discovery for multi-machine networking
        bonjourService.startAdvertising(
            mcpPort: 8765,
            hivePort: 3010,
            instanceName: Host.current().localizedName ?? "Snackbar"
        )
        bonjourService.startBrowsing()
        
        if vaultProvider.isAccessible {
            print("Vault: accessible at \(vaultProvider.vaultPath)")
        }
        
        // ── Xcode Integration ────────────────────────────────────────────
        // Install Xcode ExternalAgent for reliable MCP connections
        mcpManager.installXcodeExternalAgent()
        
        // Write MCP config for Xcode to discover Snackbar + Hivemind tools
        mcpManager.writeXcodeMCPConfig()
        
        // Check if Hivemind binary is available; if not, log a helpful message
        if !mcpManager.isHivemindBinaryAvailable() {
            print("⚠️ HivemindRust binary not found. MCP gateway won't be available.")
            print("   Build it: cd ~/Code/OkAgentDigital/Hivemind && cargo build --release")
        }
        
        let peerCount = bonjourService.discoveredInstances.count
        print("Snackmachine ready — \(snackManager.listSnacks().count) snacks loaded, \(surfaceManager.enabledSurfaces.count) surfaces enabled, \(peerCount) network peers")
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        mcpServer.stop()
        mcpManager.stopHealthChecks()
        hivemindClient.disconnect()
        ubuntuProxy.stopMonitoring()
    }
    
    // MARK: - Menu Bar
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        
        // Use SF Symbol archivebox icon
        if #available(macOS 11.0, *) {
            let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
            if let sym = NSImage(systemSymbolName: "archivebox", accessibilityDescription: "Snackbar") {
                button.image = sym.withSymbolConfiguration(config)
                button.image?.isTemplate = true
            } else {
                // Fallback: use a text character
                button.title = "📦"
            }
        } else {
            button.title = "📦"
        }
    }
    
    // MARK: - Menu
    
    private func setupMenu() {
        menu = NSMenu()
        menu.delegate = self
        statusItem?.menu = menu
        rebuildMenu()
    }
    
    private func rebuildMenu() {
        menu.removeAllItems()
        
        // ── Header ────────────────────────────────────────────────────────
        let header = NSMenuItem(title: "Snackmachine", action: nil, keyEquivalent: "")
        header.attributedTitle = NSAttributedString(
            string: "Snackmachine",
            attributes: [.font: NSFont.systemFont(ofSize: 11, weight: .semibold),
                        .foregroundColor: NSColor.labelColor])
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(NSMenuItem.separator())
        
        // ── Snackboxes ────────────────────────────────────────────────────
        let allSnacks = snackManager.listSnacks()
        let enabledSnacks = allSnacks.filter { isSnackEnabled($0) }
        let groups = groupByCategory(enabledSnacks)
        
        if enabledSnacks.isEmpty {
            let emptyItem = NSMenuItem(title: "No snacks enabled", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        }
        
        for (category, snacks) in groups {
            // Category label
            let catItem = NSMenuItem(title: category, action: nil, keyEquivalent: "")
            catItem.attributedTitle = NSAttributedString(
                string: category,
                attributes: [.font: NSFont.systemFont(ofSize: 10, weight: .medium),
                            .foregroundColor: NSColor.secondaryLabelColor])
            catItem.isEnabled = false
            menu.addItem(catItem)
            
            for snack in snacks {
                let status = snackStatuses[snack.id] ?? .idle
                let indicator: String = {
                    switch status {
                    case .running: return " ⟳"
                    case .success: return " ✓"
                    case .failed:  return " ✗"
                    case .idle:    return "  " 
                    case .done:    return " ✓"
                    }
                }()
                
                let item = NSMenuItem(
                    title: " \(indicator) \(snack.name)",
                    action: nil,
                    keyEquivalent: ""
                )
                item.isEnabled = false
                
                // Submenu: Run / indicator light / last result
                let sub = NSMenu(title: snack.name)
                
                // Run immediately — ENABLED
                let runItem = sub.addItem(withTitle: "Run Now", action: #selector(runSnack(_:)), keyEquivalent: "")
                runItem.target = self
                runItem.representedObject = snack.id
                
                sub.addItem(NSMenuItem.separator())
                
                // Status indicator
                let statusText: String = {
                    switch status {
                    case .idle:    return "Idle"
                    case .running: return "Running..."
                    case .success: return "Completed"
                    case .failed:  return "Failed"
                    case .done:    return "Completed"
                    }
                }()
                let stItem = sub.addItem(withTitle: "State: \(statusText)", action: nil, keyEquivalent: "")
                stItem.isEnabled = false
                
                if let lastRun = snackStatuses[snack.id]?.lastRun {
                    let tItem = sub.addItem(withTitle: "Ran: \(lastRun)", action: nil, keyEquivalent: "")
                    tItem.isEnabled = false
                }
                
                // Runtime info
                sub.addItem(NSMenuItem.separator())
                sub.addItem(withTitle: "Runtime: \(snack.runtime)", action: nil, keyEquivalent: "").isEnabled = false
                sub.addItem(withTitle: "Timeout: \(snack.timeoutSecs)s", action: nil, keyEquivalent: "").isEnabled = false
                
                item.submenu = sub
                menu.addItem(item)
            }
        }
        
        // ── Surfaces Submenu ──────────────────────────────────────────────
        let enabledSurfaces = surfaceManager.enabledSurfaces
        if !enabledSurfaces.isEmpty {
            menu.addItem(NSMenuItem.separator())
            
            let surfacesSub = NSMenu(title: "Surfaces")
            
            // Group by source
            let uDosSurfaces = enabledSurfaces.filter { $0.source == .uDosGo }
            let devStudioSurfaces = enabledSurfaces.filter { $0.source == .devStudio }
            
            if !uDosSurfaces.isEmpty {
                let gwHeader = surfacesSub.addItem(withTitle: "🎁 Gift Wrapper", action: nil, keyEquivalent: "")
                gwHeader.isEnabled = false
                gwHeader.attributedTitle = NSAttributedString(
                    string: "🎁 Gift Wrapper",
                    attributes: [.font: NSFont.systemFont(ofSize: 10, weight: .medium),
                                .foregroundColor: NSColor.secondaryLabelColor])
                
                for surface in uDosSurfaces {
                    let sItem = surfacesSub.addItem(
                        withTitle: "  \(surface.name)",
                        action: #selector(openSurface(_:)),
                        keyEquivalent: ""
                    )
                    sItem.target = self
                    sItem.representedObject = surface.id  // Pass the surface ID, not file path
                }
            }
            
            if !devStudioSurfaces.isEmpty {
                if !uDosSurfaces.isEmpty {
                    surfacesSub.addItem(NSMenuItem.separator())
                }
                
                let dsHeader = surfacesSub.addItem(withTitle: "💻 DevStudio", action: nil, keyEquivalent: "")
                dsHeader.isEnabled = false
                dsHeader.attributedTitle = NSAttributedString(
                    string: "💻 DevStudio",
                    attributes: [.font: NSFont.systemFont(ofSize: 10, weight: .medium),
                                .foregroundColor: NSColor.secondaryLabelColor])
                
                for surface in devStudioSurfaces {
                    let sItem = surfacesSub.addItem(
                        withTitle: "  \(surface.name)",
                        action: #selector(openSurface(_:)),
                        keyEquivalent: ""
                    )
                    sItem.target = self
                    sItem.representedObject = surface.id  // Pass the surface ID, not file path
                }
            }
            
            let surfacesMenuItem = NSMenuItem(title: "Surfaces", action: nil, keyEquivalent: "")
            surfacesMenuItem.submenu = surfacesSub
            menu.addItem(surfacesMenuItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // ── Machine Status ────────────────────────────────────────────────
        let machineItem = NSMenuItem(title: "Machine", action: nil, keyEquivalent: "")
        machineItem.isEnabled = false
        machineItem.attributedTitle = NSAttributedString(
            string: "Machine",
            attributes: [.font: NSFont.systemFont(ofSize: 10, weight: .medium),
                        .foregroundColor: NSColor.secondaryLabelColor])
        menu.addItem(machineItem)
        
        let mcpLED = mcpServer.isRunning ? "●" : "○"
        addItem(" \(mcpLED) MCP Server", action: #selector(toggleMCPServer))
        
        let hiveLED = mcpManager.hivemindStatus == .running ? "●" : "○"
        addItem(" \(hiveLED) HivemindMCP", action: #selector(toggleHivemindMCP))
        
        let ubuntuLED = mcpManager.ubuntuMCPStatus == .running ? "●" : "○"
        addDisabled(" \(ubuntuLED) Ubuntu MCP")
        
        addDisabled(" Spool: \(spoolManager.entryCount) entries")
        
        // ── Network Peers ─────────────────────────────────────────────────
        let peers = bonjourService.discoveredInstances
        if !peers.isEmpty {
            menu.addItem(NSMenuItem.separator())
            let netItem = NSMenuItem(title: "Network", action: nil, keyEquivalent: "")
            netItem.isEnabled = false
            netItem.attributedTitle = NSAttributedString(
                string: "Network",
                attributes: [.font: NSFont.systemFont(ofSize: 10, weight: .medium),
                            .foregroundColor: NSColor.secondaryLabelColor])
            menu.addItem(netItem)
            
            for peer in peers {
                let peerLED = "●"
                let peerItem = NSMenuItem(
                    title: " \(peerLED) \(peer.name)",
                    action: #selector(openPeerURL(_:)),
                    keyEquivalent: ""
                )
                peerItem.target = self
                peerItem.representedObject = peer.mcpURL
                peerItem.toolTip = "MCP: \(peer.mcpURL) | Hive: \(peer.hiveURL)"
                menu.addItem(peerItem)
            }
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // ── Footer ────────────────────────────────────────────────────────
        addItem("About Snackmachine", action: #selector(showAbout))
        addItem("Settings...", action: #selector(openSettings), key: ",")
        menu.addItem(NSMenuItem.separator())
        addItem("Quit", action: #selector(NSApplication.terminate(_:)), key: "q")
    }
    
    // MARK: - Menu Helpers
    
    private func addItem(_ title: String, action: Selector, key: String = "") {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
    }
    
    private func addDisabled(_ title: String) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }
    
    private func groupByCategory(_ snacks: [SnackV2]) -> [(String, [SnackV2])] {
        var groups: [(String, [SnackV2])] = []
        var seen = Set<String>()
        for snack in snacks {
            for tag in snack.tags where !seen.contains(tag) {
                seen.insert(tag)
                groups.append((tag.capitalized, snacks.filter { $0.tags.contains(tag) }))
            }
        }
        if groups.isEmpty && !snacks.isEmpty {
            groups = [("Snacks", snacks)]
        }
        return groups
    }
    
    /// Check if a snack is enabled in settings.
    private func isSnackEnabled(_ snack: SnackV2) -> Bool {
        return UserDefaults.standard.object(forKey: "snack_enabled_\(snack.id)") as? Bool ?? true
    }
    
    // MARK: - Snack Execution
    
    @objc private func runSnack(_ sender: NSMenuItem) {
        guard let snackId = sender.representedObject as? String,
              let snack = snackManager.getSnack(byId: snackId) else { return }
        
        snackStatuses[snackId] = .running
        rebuildMenu()
        
        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }
            let executor = SnackExecutor()
            let result = executor.execute(snack: snack)
            
            DispatchQueue.main.async {
                if result.exitCode == 0 {
                    self.snackStatuses[snackId] = .success
                } else {
                    self.snackStatuses[snackId] = .failed
                }
                self.snackStatuses[snackId] = .done(Self.formatTimestamp(Date()))
                
                // Notification
                let note = NSUserNotification()
                note.title = snack.name
                note.informativeText = result.exitCode == 0
                    ? "Completed in \(result.durationMs)ms"
                    : "Failed: \(result.output.prefix(100))"
                NSUserNotificationCenter.default.deliver(note)
                
                self.rebuildMenu()
            }
        }
    }
    
    private static func formatTimestamp(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: date)
    }
    
    // MARK: - Surface Actions
    
    /// Map a surface name to its ThinUI GiftWrapper URL.
    /// Opens the GiftWrapper component instead of the raw .md file.
    @objc private func openSurface(_ sender: NSMenuItem) {
        guard let surfaceId = sender.representedObject as? String else { return }
        
        // Find the surface by ID
        let allSurfaces = surfaceManager.uDosGoSurfaces + surfaceManager.devStudioSurfaces
        guard let surface = allSurfaces.first(where: { $0.id == surfaceId }) else {
            print("⚠️ Surface not found: \(surfaceId)")
            return
        }
        
        let thinuiPort = 4687
        
        // Map surface name to a ThinUI GiftWrapper component URL
        let urlMappings: [String: String] = [
            "dashboard": "/",
            "chat": "/chat",
            "kanban": "/kanban",
            "tasks": "/tasks",
            "notes": "/notes",
            "vault": "/vault",
            "settings": "/settings",
            "launchpad": "/launchpad",
            "content": "/content",
            "packages": "/packages",
            "media": "/media",
            "devstudio": "/devstudio",
        ]
        
        // Normalize the surface name: lowercase, strip spaces/special chars
        let normalizedName = surface.name
            .lowercased()
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "_")
        
        if let pathComponent = urlMappings[normalizedName] ?? urlMappings[surface.name.lowercased()] {
            // Open ThinUI GiftWrapper component URL
            let urlStr = "http://localhost:\(thinuiPort)\(pathComponent)"
            if let url = URL(string: urlStr) {
                print("🎁 Opening GiftWrapper surface: \(surface.name) → \(urlStr)")
                NSWorkspace.shared.open(url)
                return
            }
        }
        
        // Fallback: open the surface file directly
        print("📄 Opening surface file: \(surface.fileURL.path)")
        NSWorkspace.shared.open(surface.fileURL)
    }
    
    // MARK: - Actions
    
    @objc private func toggleMCPServer() {
        mcpServer.isRunning ? mcpServer.stop() : mcpServer.start()
        rebuildMenu()
    }
    
    @objc private func toggleHivemindMCP() {
        if mcpManager.hivemindStatus == .running {
            mcpManager.stopHivemind()
        } else {
            mcpManager.startHivemind(port: 3010)
        }
        rebuildMenu()
    }
    
    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Snackmachine"
        alert.informativeText = """
        Snackbar v2.0 — macOS execution spine of uDos.
        
        One icon. One spool. Infinite snacks. One narrator.
        
        MCP Server: :8765
        Hivemind Gateway: :3010
        Spool: \(spoolManager.entryCount) entries
        Snacks: \(snackManager.listSnacks().count) installed
        Surfaces: \(surfaceManager.enabledSurfaces.count) enabled
        
        © OkAgentDigital
        """
        alert.runModal()
    }
    
    @objc private func openPeerURL(_ sender: NSMenuItem) {
        guard let urlStr = sender.representedObject as? String,
              let url = URL(string: urlStr) else { return }
        NSWorkspace.shared.open(url)
    }
    
    @objc private func openSettings() {
        let settingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 520),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: true
        )
        settingsWindow.title = "Snackbar Settings"
        settingsWindow.contentView = NSHostingView(rootView: SettingsView())
        settingsWindow.center()
        settingsWindow.makeKeyAndOrderFront(nil)
        settingsWindow.isReleasedWhenClosed = false
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Snack Status

enum SnackStatus: Equatable {
    case idle
    case running
    case success
    case failed
    case done(String)  // last run timestamp as associated value
    
    var lastRun: String? {
        if case .done(let t) = self { return t }
        return nil
    }
}

// MARK: - NSMenuDelegate

extension SnackbarAppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        mcpManager.performHealthCheck()
        rebuildMenu()
    }
}

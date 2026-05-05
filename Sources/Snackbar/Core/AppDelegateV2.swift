import AppKit
import SwiftUI

/// Main app delegate for Snackbar v2.0
/// Manages the menu bar icon, snack menu, MCP server, scheduler, and preferences.
class SnackbarAppDelegate: NSObject, NSApplicationDelegate {
    
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var preferencesWindow: NSWindow?
    
    // Core managers
    private let spoolManager = SpoolManager.shared
    private let nuggetManager = NuggetManager.shared
    private let rulesManager = RulesManager.shared
    private let snackManager = SnackManager.shared
    private let taskManager = TaskManager.shared
    private let mcpServer = MCPServer.shared
    
    // MARK: - Application Lifecycle
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupMenu()
        
        // Start MCP server
        if let config = loadConfig(),
           config["mcp_enabled"] as? Bool ?? true {
            mcpServer.start()
        }
        
        // Start task scheduler
        if let config = loadConfig(),
           config["scheduler_enabled"] as? Bool ?? true {
            taskManager.startScheduler()
        }
        
        print("🍔 Snackbar v2.0 ready")
        print("   📋 \(snackManager.listSnacks().count) snacks loaded")
        print("   📝 \(spoolManager.entryCount) spool entries")
        print("   ⚙️  \(rulesManager.rules.count) rules active")
        print("   🗂️  \(nuggetManager.nuggets.count) nuggets archived")
        print("   📡 MCP server: \(mcpServer.isRunning ? "running on :8765" : "stopped")")
        print("   ⏰ Scheduler: \(taskManager.isSchedulerRunning ? "running" : "stopped")")
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        mcpServer.stop()
        taskManager.stopScheduler()
    }
    
    // MARK: - Menu Bar Setup
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            // Use template image for native light/dark mode support
            if let image = loadMenuBarIcon() {
                button.image = image
                button.image?.size = NSSize(width: 18, height: 18)
            } else {
                // Fallback to emoji if image not found
                button.title = "🍔"
            }
            button.action = #selector(menuBarClicked)
            button.target = self
        }
    }
    
    /// Load the menu bar icon as a template image (adapts to light/dark mode)
    private func loadMenuBarIcon() -> NSImage? {
        // Try loading from main bundle Resources first, then fallback paths
        let image = NSImage(named: "MenuBarIcon")
            ?? NSImage(contentsOfFile: Bundle.main.path(forResource: "MenuBarIcon", ofType: "png") ?? "")
            ?? NSImage(contentsOfFile: Bundle.main.path(forResource: "MenuBarIcon@2x", ofType: "png") ?? "")
        
        image?.isTemplate = true
        return image
    }
    
    @objc private func menuBarClicked() {
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
    }
    
    // MARK: - Menu Construction
    
    private func setupMenu() {
        menu = NSMenu()
        menu.delegate = self
        
        rebuildMenu()
    }
    
    private func rebuildMenu() {
        menu.removeAllItems()
        
        // Snack sections
        let snackGroups = groupSnacksByTag()
        for (tag, snacks) in snackGroups {
            let titleItem = NSMenuItem(title: tag, action: nil, keyEquivalent: "")
            titleItem.attributedTitle = NSAttributedString(
                string: tag,
                attributes: [.font: NSFont.boldSystemFont(ofSize: 12)]
            )
            menu.addItem(titleItem)
            
            for snack in snacks {
                let item = NSMenuItem(
                    title: "\(snack.emoji) \(snack.name)",
                    action: #selector(runSnack(_:)),
                    keyEquivalent: ""
                )
                item.representedObject = snack.id
                item.target = self
                menu.addItem(item)
            }
            
            menu.addItem(NSMenuItem.separator())
        }
        
        // Spool info
        let spoolItem = NSMenuItem(
            title: "📝 Spool: \(spoolManager.entryCount) entries",
            action: nil,
            keyEquivalent: ""
        )
        menu.addItem(spoolItem)
        
        // MCP status
        let mcpStatus = mcpServer.isRunning ? "🟢 MCP Server: :8765" : "🔴 MCP Server: stopped"
        let mcpItem = NSMenuItem(title: mcpStatus, action: #selector(toggleMCPServer), keyEquivalent: "")
        mcpItem.target = self
        menu.addItem(mcpItem)
        
        // Scheduler status
        let schedStatus = taskManager.isSchedulerRunning ? "🟢 Scheduler: running" : "🔴 Scheduler: stopped"
        let schedItem = NSMenuItem(title: schedStatus, action: #selector(toggleScheduler), keyEquivalent: "")
        schedItem.target = self
        menu.addItem(schedItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Preferences
        let prefsItem = NSMenuItem(title: "⚙️ Preferences...", action: #selector(openPreferences), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)
        
        // Quit
        let quitItem = NSMenuItem(title: "🚪 Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
    }
    
    // MARK: - Snack Execution
    
    @objc private func runSnack(_ sender: NSMenuItem) {
        guard let snackId = sender.representedObject as? String,
              let snack = snackManager.getSnack(byId: snackId) else { return }
        
        let executor = SnackExecutor()
        let result = executor.execute(snack: snack)
        
        // Show notification
        let notification = NSUserNotification()
        notification.title = "\(snack.emoji) \(snack.name)"
        notification.informativeText = result.exitCode == 0
            ? "✅ Completed in \(result.durationMs)ms"
            : "❌ Failed: \(result.output)"
        NSUserNotificationCenter.default.deliver(notification)
    }
    
    // MARK: - Actions
    
    @objc private func toggleMCPServer() {
        if mcpServer.isRunning {
            mcpServer.stop()
        } else {
            mcpServer.start()
        }
        rebuildMenu()
    }
    
    @objc private func toggleScheduler() {
        if taskManager.isSchedulerRunning {
            taskManager.stopScheduler()
        } else {
            taskManager.startScheduler()
        }
        rebuildMenu()
    }
    
    @objc func openPreferences() {
        if preferencesWindow == nil {
            let prefsView = PreferencesView()
            preferencesWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            preferencesWindow?.title = "Snackbar Preferences"
            preferencesWindow?.contentView = NSHostingView(rootView: prefsView)
            preferencesWindow?.center()
        }
        preferencesWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    // MARK: - Helpers
    
    private func groupSnacksByTag() -> [(String, [SnackV2])] {
        let allSnacks = snackManager.listSnacks()
        var groups: [(String, [SnackV2])] = []
        var seen = Set<String>()
        
        for snack in allSnacks {
            for tag in snack.tags {
                if !seen.contains(tag) {
                    seen.insert(tag)
                    let tagged = allSnacks.filter { $0.tags.contains(tag) }
                    groups.append((tag.capitalized, tagged))
                }
            }
        }
        
        return groups
    }
    
    private func loadConfig() -> [String: Any]? {
        let configURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Snackbar/config.json")
        guard let data = try? Data(contentsOf: configURL),
              let config = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return config
    }
}

// MARK: - NSMenuDelegate

extension SnackbarAppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu()
    }
}

// MARK: - Preferences View

struct PreferencesView: View {
    @State private var mcpEnabled = true
    @State private var schedulerEnabled = true
    @State private var mcpPort = "8765"
    @State private var refreshInterval = 30.0
    
    var body: some View {
        TabView {
            // General
            Form {
                Toggle("Enable MCP Server", isOn: $mcpEnabled)
                TextField("MCP Port", text: $mcpPort)
                Toggle("Enable Scheduler", isOn: $schedulerEnabled)
                Slider(value: $refreshInterval, in: 10...120, step: 10) {
                    Text("Refresh Interval: \(Int(refreshInterval))s")
                }
            }
            .padding()
            .tabItem { Label("General", systemImage: "gearshape") }
            
            // Spool Viewer
            SpoolView()
                .tabItem { Label("Spool", systemImage: "list.bullet") }
            
            // Rules
            RulesView()
                .tabItem { Label("Rules", systemImage: "arrow.triangle.branch") }
            
            // Nuggets
            NuggetsView()
                .tabItem { Label("Nuggets", systemImage: "archivebox") }
        }
        .frame(width: 580, height: 460)
    }
}

struct SpoolView: View {
    @State private var entries: [SpoolEntry] = []
    @State private var searchText = ""
    
    var body: some View {
        List(entries, id: \.reply_id) { entry in
            VStack(alignment: .leading) {
                HStack {
                    Text(entry.metadata.snack_name).font(.headline)
                    Spacer()
                    Text(entry.timestamp).font(.caption).foregroundColor(.secondary)
                }
                Text(entry.output).font(.body).lineLimit(2)
                HStack {
                    ForEach(entry.tags, id: \.self) { tag in
                        Text(tag).font(.caption).padding(2).background(Color.gray.opacity(0.2)).cornerRadius(4)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .onAppear {
            entries = SpoolManager.shared.readRecent(limit: 50)
        }
    }
}

struct RulesView: View {
    @State private var rules: [Rule] = []
    
    var body: some View {
        List(rules) { rule in
            HStack {
                Image(systemName: rule.enabled ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(rule.enabled ? .green : .gray)
                VStack(alignment: .leading) {
                    Text(rule.name).font(.headline)
                    Text("Trigger: \(rule.trigger.type.rawValue)").font(.caption)
                }
            }
        }
        .onAppear {
            rules = RulesManager.shared.rules
        }
    }
}

struct NuggetsView: View {
    @State private var nuggets: [NuggetInfo] = []
    
    var body: some View {
        List(nuggets) { nugget in
            HStack {
                Image(systemName: "archivebox")
                VStack(alignment: .leading) {
                    Text(nugget.name).font(.headline)
                    Text("v\(nugget.version) • \(nugget.sizeFormatted)").font(.caption)
                }
            }
        }
        .onAppear {
            nuggets = NuggetManager.shared.nuggets
        }
    }
}

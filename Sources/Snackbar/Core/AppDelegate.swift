import AppKit

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    private var menuBuilder: MenuBuilder?
    private var snackScheduler: SnackScheduler?
    var feedManager: FeedManager?
    var popover: NSPopover?

    // Hivemind & Ubuntu integration
    private let hivemindClient = HivemindClient.shared
    private let ubuntuProxy = UbuntuProxy.shared
    private let xcodeBuildService = XcodeBuildService.shared
    private let processManager = uDosProcessManager()
    private var hivemindHealthTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🍔 Snackbar Pro - Launching...")

        // Load configuration
        let configManager = ConfigManager.shared
        _ = configManager.getSnackbarConfig()

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

        // ─── Hivemind & Ubuntu Integration ───────────────────────────────────

        // Load SSH config from ~/.ssh/config for Ubuntu connection
        let sshConfig = configManager.getUbuntuSSHConfig()
        print("🌐 Ubuntu SSH: \(sshConfig.user)@\(sshConfig.host):\(sshConfig.port)")

        // Start HivemindRust process if not already running
        startHivemindRust()

        // Connect to HivemindRust MCP server
        hivemindClient.connect()

        // Start Ubuntu backend monitoring
        ubuntuProxy.startMonitoring()

        // Start periodic Hivemind health checks
        startHivemindHealthChecks()

        // Register Xcode External Agent
        registerXcodeExternalAgent()

        // Check for updates
        // UpdateChecker.shared.checkForUpdates()

        print("✅ Snackbar Pro is ready!")
    }


    // MARK: - HivemindRust Process Management

    /// Start the HivemindRust MCP gateway if it's not already running.
    private func startHivemindRust() {
        // Check if HivemindRust is already running
        let checkTask = Process()
        checkTask.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        checkTask.arguments = ["-f", "hivemind-rust"]

        let checkPipe = Pipe()
        checkTask.standardOutput = checkPipe

        do {
            try checkTask.run()
            checkTask.waitUntilExit()

            if checkTask.terminationStatus == 0 {
                print("✅ HivemindRust is already running")
                return
            }
        } catch {
            print("⚠️ Could not check for HivemindRust: \(error.localizedDescription)")
        }

        // Start HivemindRust via the process manager
        if let hivemindComponent = processManager.getComponent(withId: "hivemind-rust") {
            processManager.startComponent(hivemindComponent)
        } else {
            // Create and start the component
            let component = uDosComponent(
                id: "hivemind-rust",
                displayName: "HivemindRust",
                command: "/usr/bin/env",
                args: ["cargo", "run", "--release"],
                workingDirectory: "\(NSHomeDirectory())/Code/OkAgentDigital/HivemindRust",
                env: ["RUST_LOG": "info"],
                healthCheckURL: "http://localhost:30000/health",
                icon: "🧠",
                port: 30000,
                requiredComponents: [],
                description: "Hivemind MCP Gateway — bridges Snackbar to Ubuntu LLM backend",
                isEssential: true
            )
            processManager.addComponent(component)
            processManager.startComponent(component)
        }
    }

    /// Start periodic health checks for the HivemindRust server.
    private func startHivemindHealthChecks() {
        hivemindHealthTimer?.invalidate()
        hivemindHealthTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            // Check if HivemindRust is still running
            let checkTask = Process()
            checkTask.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
            checkTask.arguments = ["-f", "hivemind-rust"]

            do {
                try checkTask.run()
                checkTask.waitUntilExit()

                if checkTask.terminationStatus != 0 {
                    print("⚠️ HivemindRust is not running, attempting restart...")
                    self.startHivemindRust()
                }
            } catch {
                print("⚠️ Health check failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Menu Bar Setup

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
        hivemindClient.disconnect()
        ubuntuProxy.stopMonitoring()
        hivemindHealthTimer?.invalidate()
    }

    // MARK: - Xcode External Agent Registration

    /// Register the Xcode External Agent so Xcode can discover Snackbar's build service.
    private func registerXcodeExternalAgent() {
        let agentPlistPath = "\(NSHomeDirectory())/Code/Apps/Snackbar/Resources/XcodeExternalAgent.plist"
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: agentPlistPath) else {
            print("⚠️ Xcode External Agent plist not found at \(agentPlistPath)")
            return
        }

        // Copy the plist to Xcode's external agent directory
        let xcodeAgentDir = "\(NSHomeDirectory())/Library/Developer/Xcode/ExternalAgents"
        let xcodeAgentPath = "\(xcodeAgentDir)/com.udos.Snackbar.XCSBuildService.plist"

        do {
            // Create the directory if needed
            try fileManager.createDirectory(atPath: xcodeAgentDir, withIntermediateDirectories: true)

            // Copy the plist
            if fileManager.fileExists(atPath: xcodeAgentPath) {
                try fileManager.removeItem(atPath: xcodeAgentPath)
            }
            try fileManager.copyItem(atPath: agentPlistPath, toPath: xcodeAgentPath)
            print("✅ Xcode External Agent registered at \(xcodeAgentPath)")
        } catch {
            print("⚠️ Failed to register Xcode External Agent: \(error.localizedDescription)")
        }
    }

    // MARK: - View Presentation Methods


    func showAddSnackView() {
        print("📋 Showing Add Snack View - Would open window to add new snack")
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
        alert.informativeText =
            "A powerful macOS menu bar automation tool\nVersion 1.0 - Expanded Edition\n\n🧠 Hivemind MCP Gateway\n🌐 Ubuntu Backend Proxy\n⚡ Xcode Build Service"
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    func showPreferencesView() {
        print("⚙️ Showing Preferences View - Would open preferences window")
        let alert = NSAlert()
        alert.messageText = "Settings"
        alert.informativeText = "This feature will be implemented in the full version"
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc func closeMenu() {
        print("🔒 Closing menu")
        if let statusItem = statusItem {
            statusItem.menu = nil
        }
        popover?.performClose(nil)
    }
}

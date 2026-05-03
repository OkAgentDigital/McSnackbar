import AppKit
import Foundation

class MenuBuilder {
    private let snackManager = SnackManager.shared
    private let hivemindClient = HivemindClient.shared
    private let ubuntuProxy = UbuntuProxy.shared
    private let xcodeBuildService = XcodeBuildService.shared

    func buildMenu() -> NSMenu {
        let menu = NSMenu(title: "Snackbar")

        // ─── Snacks Section ──────────────────────────────────────────────────
        let snacksHeader = NSMenuItem(title: "🍔 Snacks", action: nil, keyEquivalent: "")
        snacksHeader.isEnabled = false
        menu.addItem(snacksHeader)

        let snacks = snackManager.getSnacks()
        if snacks.isEmpty {
            let emptyItem = NSMenuItem(title: "  No snacks configured", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            for snack in snacks {
                let item = NSMenuItem(
                    title: "  \(snack.emoji) \(snack.name)",
                    action: #selector(runSnack(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = snack
                item.toolTip = snack.description
                menu.addItem(item)
            }
        }

        menu.addItem(NSMenuItem.separator())

        // ─── Hivemind Section ────────────────────────────────────────────────
        let hivemindHeader = NSMenuItem(title: "🧠 Hivemind", action: nil, keyEquivalent: "")
        hivemindHeader.isEnabled = false
        menu.addItem(hivemindHeader)

        // Hivemind status
        let statusText = hivemindClient.isConnected
            ? "  ✅ Connected (v\(hivemindClient.serverVersion))"
            : "  ⏹️  Disconnected"
        let statusItem = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        // Available tools submenu
        if !hivemindClient.availableTools.isEmpty {
            let toolsMenu = NSMenu()
            for tool in hivemindClient.availableTools {
                let toolItem = NSMenuItem(
                    title: "  \(tool.name)",
                    action: #selector(callMCPTool(_:)),
                    keyEquivalent: ""
                )
                toolItem.target = self
                toolItem.representedObject = tool
                toolItem.toolTip = tool.description
                toolsMenu.addItem(toolItem)
            }
            let toolsMenuItem = NSMenuItem(title: "  🛠️ MCP Tools", action: nil, keyEquivalent: "")
            menu.setSubmenu(toolsMenu, for: toolsMenuItem)
            menu.addItem(toolsMenuItem)
        }

        // Hivemind actions
        let refreshItem = NSMenuItem(
            title: "  🔄 Refresh Status",
            action: #selector(refreshHivemindStatus),
            keyEquivalent: ""
        )
        refreshItem.target = self
        menu.addItem(refreshItem)

        let restartItem = NSMenuItem(
            title: "  🔄 Restart HivemindRust",
            action: #selector(restartHivemindRust),
            keyEquivalent: ""
        )
        restartItem.target = self
        menu.addItem(restartItem)

        menu.addItem(NSMenuItem.separator())

        // ─── Ubuntu Backend Section ──────────────────────────────────────────
        let ubuntuHeader = NSMenuItem(title: "🌐 Ubuntu Backend", action: nil, keyEquivalent: "")
        ubuntuHeader.isEnabled = false
        menu.addItem(ubuntuHeader)

        // SSH status
        let sshStatus = ubuntuProxy.isReachable ? "  ✅ SSH Connected" : "  ❌ SSH Disconnected"
        let sshItem = NSMenuItem(title: sshStatus, action: nil, keyEquivalent: "")
        sshItem.isEnabled = false
        menu.addItem(sshItem)

        // Ollama status
        let ollamaItem = NSMenuItem(
            title: "  Ollama: \(ubuntuProxy.ollamaStatus.displayText)",
            action: nil,
            keyEquivalent: ""
        )
        ollamaItem.isEnabled = false
        menu.addItem(ollamaItem)

        // Hivemind status
        let hivemindRemoteItem = NSMenuItem(
            title: "  Hivemind: \(ubuntuProxy.hivemindStatus.displayText)",
            action: nil,
            keyEquivalent: ""
        )
        hivemindRemoteItem.isEnabled = false
        menu.addItem(hivemindRemoteItem)

        // Ubuntu actions
        let testUbuntuItem = NSMenuItem(
            title: "  🔍 Test Connection",
            action: #selector(testUbuntuConnection),
            keyEquivalent: ""
        )
        testUbuntuItem.target = self
        menu.addItem(testUbuntuItem)

        let refreshUbuntuItem = NSMenuItem(
            title: "  🔄 Refresh Status",
            action: #selector(refreshUbuntuStatus),
            keyEquivalent: ""
        )
        refreshUbuntuItem.target = self
        menu.addItem(refreshUbuntuItem)

        menu.addItem(NSMenuItem.separator())

        // ─── Xcode Build Section ─────────────────────────────────────────────
        let xcodeHeader = NSMenuItem(title: "⚡ Xcode Build", action: nil, keyEquivalent: "")
        xcodeHeader.isEnabled = false
        menu.addItem(xcodeHeader)

        let xcodeAvailable = xcodeBuildService.xcServiceAvailable
            ? "  ✅ Xcode CLI Available"
            : "  ❌ Xcode CLI Not Available"
        let xcodeAvailItem = NSMenuItem(title: xcodeAvailable, action: nil, keyEquivalent: "")
        xcodeAvailItem.isEnabled = false
        menu.addItem(xcodeAvailItem)

        // Build project submenu
        let buildMenu = NSMenu()
        for project in xcodeBuildService.knownProjects {
            let buildItem = NSMenuItem(
                title: "  Build \(project.name)",
                action: #selector(buildProject(_:)),
                keyEquivalent: ""
            )
            buildItem.target = self
            buildItem.representedObject = project
            buildMenu.addItem(buildItem)
        }
        let buildMenuItem = NSMenuItem(title: "  🔨 Build Project", action: nil, keyEquivalent: "")
        menu.setSubmenu(buildMenu, for: buildMenuItem)
        menu.addItem(buildMenuItem)

        // Build all
        let buildAllItem = NSMenuItem(
            title: "  🔨 Build All Projects",
            action: #selector(buildAllProjects),
            keyEquivalent: ""
        )
        buildAllItem.target = self
        menu.addItem(buildAllItem)

        // Last build result
        if let lastResult = xcodeBuildService.lastBuildResult {
            let resultItem = NSMenuItem(
                title: "  \(lastResult.summary)",
                action: nil,
                keyEquivalent: ""
            )
            resultItem.isEnabled = false
            menu.addItem(resultItem)
        }

        menu.addItem(NSMenuItem.separator())

        // ─── Actions Section ─────────────────────────────────────────────────
        let actionsHeader = NSMenuItem(title: "⚙️ Actions", action: nil, keyEquivalent: "")
        actionsHeader.isEnabled = false
        menu.addItem(actionsHeader)

        let addSnackItem = NSMenuItem(
            title: "  ➕ Add Snack",
            action: #selector(showAddSnackView),
            keyEquivalent: "n"
        )
        addSnackItem.target = self
        menu.addItem(addSnackItem)

        let importExportItem = NSMenuItem(
            title: "  📁 Import/Export",
            action: #selector(showImportExportView),
            keyEquivalent: "i"
        )
        importExportItem.target = self
        menu.addItem(importExportItem)

        let preferencesItem = NSMenuItem(
            title: "  ⚙️ Preferences",
            action: #selector(showPreferencesView),
            keyEquivalent: ","
        )
        preferencesItem.target = self
        menu.addItem(preferencesItem)

        menu.addItem(NSMenuItem.separator())

        // ─── Info Section ────────────────────────────────────────────────────
        let aboutItem = NSMenuItem(
            title: "  ℹ️ About Snackbar",
            action: #selector(showAboutView),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        let quitItem = NSMenuItem(
            title: "  🚪 Quit",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)

        return menu
    }

    // MARK: - Actions

    @objc private func runSnack(_ sender: NSMenuItem) {
        guard let snack = sender.representedObject as? Snack else { return }
        SnackExecutor.run(snack)
    }

    @objc private func callMCPTool(_ sender: NSMenuItem) {
        guard let tool = sender.representedObject as? MCPTool else { return }
        Task {
            let result = await hivemindClient.callTool(name: tool.name)
            switch result {
            case .success(let response):
                print("✅ MCP tool '\(tool.name)' response:\n\(response)")
            case .failure(let error):
                print("❌ MCP tool '\(tool.name)' failed: \(error.localizedDescription)")
            }
        }
    }

    @objc private func refreshHivemindStatus() {
        Task {
            _ = await hivemindClient.listTools()
            _ = await hivemindClient.getStatus()
        }
    }

    @objc private func restartHivemindRust() {
        guard let appDelegate = NSApplication.shared.delegate as? AppDelegate else { return }
        // Kill existing process
        let killTask = Process()
        killTask.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        killTask.arguments = ["-f", "hivemind-rust"]
        try? killTask.run()
        killTask.waitUntilExit()

        // Restart
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            appDelegate.perform(#selector(AppDelegate.startHivemindRust), with: nil, afterDelay: 0)
        }
    }

    @objc private func testUbuntuConnection() {
        ubuntuProxy.performHealthCheck()
        print(ubuntuProxy.getStatusSummary())
    }

    @objc private func refreshUbuntuStatus() {
        ubuntuProxy.performHealthCheck()
    }

    @objc private func buildProject(_ sender: NSMenuItem) {
        guard let project = sender.representedObject as? XcodeProject else { return }
        Task {
            let result = await xcodeBuildService.buildProject(project)
            print("Build result: \(result.summary)")
        }
    }

    @objc private func buildAllProjects() {
        Task {
            let results = await xcodeBuildService.buildAll()
            for result in results {
                print(result.summary)
            }
        }
    }

    @objc private func showAddSnackView() {
        (NSApplication.shared.delegate as? AppDelegate)?.showAddSnackView()
    }

    @objc private func showImportExportView() {
        (NSApplication.shared.delegate as? AppDelegate)?.showImportExportView()
    }

    @objc private func showPreferencesView() {
        (NSApplication.shared.delegate as? AppDelegate)?.showPreferencesView()
    }

    @objc private func showAboutView() {
        (NSApplication.shared.delegate as? AppDelegate)?.showAboutView()
    }
}

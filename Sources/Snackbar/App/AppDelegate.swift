import Cocoa
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private let snackManager = SnackManager.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        buildMenu()

        // Observe snack changes to rebuild menu
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(rebuildMenu),
            name: NSNotification.Name("SnackStateChanged"),
            object: nil
        )

        // Start periodic update checks
        UpdateChecker.shared.startPeriodicChecks()
    }

    /// Load an icon from the app bundle's Resources directory.
    /// SwiftPM does not compile .xcassets into Assets.car, so we try multiple
    /// paths to find PNG/SVG files in the Resources directory.
    private func loadIcon(_ name: String) -> NSImage? {
        // 1. Standard named image (works if xcassets compiled into Assets.car)
        if let image = NSImage(named: name) {
            return image
        }
        // 2. PNG directly in Resources/ (converted by Dev-Launch.command via sips)
        if let url = Bundle.main.url(forResource: name, withExtension: "png") {
            return NSImage(contentsOf: url)
        }
        // 3. SVG directly in Resources/
        if let url = Bundle.main.url(forResource: name, withExtension: "svg") {
            return NSImage(contentsOf: url)
        }
        // 4. SVG inside xcassets structure (may be copied as-is by SwiftPM)
        let imagesetDir = "Assets.xcassets/Mono Icons/\(name).imageset"
        if let url = Bundle.main.url(
            forResource: name, withExtension: "svg", subdirectory: imagesetDir)
        {
            return NSImage(contentsOf: url)
        }
        return nil
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            let icon = loadAppIcon()
            icon?.isTemplate = true
            button.image = icon
            button.action = #selector(menuBarClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    /// Render the box/archive icon programmatically using Core Graphics.
    /// This is the most reliable approach — no file loading dependencies.
    private func renderArchiveBoxIcon(size: NSSize = NSSize(width: 18, height: 18)) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()

        guard let ctx = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return NSImage(systemSymbolName: "archivebox", accessibilityDescription: "Snackbar") ?? image
        }

        let w = size.width
        let h = size.height
        let inset: CGFloat = 1.0
        let l: CGFloat = inset
        let r: CGFloat = w - inset
        let t: CGFloat = inset
        let b: CGFloat = h - inset
        let midX = w / 2
        let midY = h / 2

        // Set stroke color (will be treated as template)
        ctx.setStrokeColor(NSColor.black.cgColor)
        ctx.setLineWidth(1.5)
        ctx.setLineJoin(.round)

        // Draw the box body (bottom rectangle)
        let bodyTop: CGFloat = midY - 1
        let bodyRect = CGRect(x: l + 2, y: bodyTop, width: r - l - 4, height: b - bodyTop - 1)
        ctx.stroke(bodyRect)

        // Draw the lid (top rectangle)
        let lidRect = CGRect(x: l, y: t, width: r - l, height: midY - t - 2)
        ctx.stroke(lidRect)

        // Draw the tab in the middle
        ctx.move(to: NSPoint(x: midX - 3, y: midY))
        ctx.addLine(to: NSPoint(x: midX - 3, y: midY + 2))
        ctx.addLine(to: NSPoint(x: midX + 3, y: midY + 2))
        ctx.addLine(to: NSPoint(x: midX + 3, y: midY))
        ctx.strokePath()

        image.unlockFocus()
        return image
    }

    /// Load the app's status bar icon.
    /// Uses a programmatically rendered icon for reliability.
    private func loadAppIcon() -> NSImage? {
        let icon = renderArchiveBoxIcon()
        return icon
    }

    @objc private func menuBarClicked(_ sender: NSStatusBarButton) {
        // Rebuild menu each time to reflect latest badges
        buildMenu()
        statusItem.menu?.popUp(
            positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 5), in: sender)
    }

    @objc private func rebuildMenu() {
        buildMenu()
    }

    private func buildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false

        // Title
        let titleItem = NSMenuItem(title: "Snackbar", action: nil, keyEquivalent: "")
        let appIcon = loadIcon("icon-box-archive")
        appIcon?.isTemplate = true
        titleItem.image = appIcon
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(NSMenuItem.separator())

        // Snack items
        for snack in snackManager.snacks {
            let badge = snackManager.formattedBadge(for: snack)
            let title = "\(snack.name) \(badge)".trimmingCharacters(in: .whitespaces)
            let item = NSMenuItem(
                title: title, action: #selector(toggleSnack(_:)), keyEquivalent: "")

            let icon = loadIcon(snack.iconName)
            icon?.isTemplate = true
            item.image = icon

            item.representedObject = snack.id
            item.state = snack.isEnabled ? .on : .off
            item.onStateImage = NSImage(named: "NSMenuOnStateTemplate")

            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())

        // Settings
        let settingsItem = NSMenuItem(
            title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        let settingsIcon = loadIcon("icon-settings")
        settingsIcon?.isTemplate = true
        settingsItem.image = settingsIcon
        menu.addItem(settingsItem)

        // Quit
        let quitItem = NSMenuItem(
            title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func toggleSnack(_ sender: NSMenuItem) {
        guard let snackId = sender.representedObject as? String else { return }
        snackManager.toggleSnack(snackId)
        buildMenu()
    }

    @objc private func openSettings() {
        if settingsWindow != nil {
            settingsWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView()
        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Snackbar Settings"
        window.setContentSize(NSSize(width: 500, height: 400))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.delegate = self
        window.center()

        self.settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        settingsWindow = nil
    }
}

// SnackbarApp.swift
// Snackbar
//
// Created by DevStudio Integration
//

import SwiftUI
import AppKit

@main
struct SnackbarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    
    let snackNames = [
        "Quick Note",
        "Send Email",
        "Show Clipboard",
        "Do Not Disturb Toggle",
        "System Cleanup",
        "Launch Calendar"
    ]
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Register AppleScript support
        SnackbarAppleScriptHandler.registerScriptingSupport()
        
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            if let icon = NSImage(named: "AppIcon") {
                button.image = icon
            } else {
                button.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "Snackbar")
            }
        }
        
        // Create menu
        let menu = NSMenu()
        for snack in snackNames {
            let item = NSMenuItem(title: snack, action: #selector(runSnack(_:)), keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        }
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Quit Snackbar", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem?.menu = menu
        
        // Previous popover code removed/commented out:
        /*
        // Create popover
        popover = NSPopover()
        popover?.contentViewController = NSHostingController(rootView: ContentView())
        popover?.behavior = .transient
        */
    }
    
    @objc func runSnack(_ sender: NSMenuItem) {
        switch sender.title {
        case "Quick Note":
            // Open a quick note interface
            if let url = URL(string: "x-apple-notes://") {
                NSWorkspace.shared.open(url)
            } else {
                print("Could not open Notes app")
            }
        case "Send Email":
            // Open the default email client with a new email
            if let url = URL(string: "message:") {
                NSWorkspace.shared.open(url)
            } else {
                print("Could not open email client")
            }
        case "Show Clipboard":
            // Show the current clipboard content
            if let clipboardContent = NSPasteboard.general.string(forType: .string) {
                let alert = NSAlert()
                alert.messageText = "Clipboard Content"
                alert.informativeText = clipboardContent
                alert.alertStyle = .informational
                alert.addButton(withTitle: "OK")
                alert.runModal()
            } else {
                let alert = NSAlert()
                alert.messageText = "Clipboard is empty"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        case "Do Not Disturb Toggle":
            // Toggle Do Not Disturb mode
            toggleDoNotDisturb()
        case "System Cleanup":
            // Open system cleanup tools
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.universalaccess?General") {
                NSWorkspace.shared.open(url)
            } else {
                print("Could not open System Preferences")
            }
        case "Launch Calendar":
            // Open the Calendar app
            if let url = URL(string: "calshow:") {
                NSWorkspace.shared.open(url)
            } else {
                print("Could not open Calendar app")
            }
        default:
            print("Unknown snack: \"\"(sender.title)\"")
        }
    }

    // Helper method to toggle Do Not Disturb
    func toggleDoNotDisturb() {
        let script = """
        tell application "System Events"
            key code 10 using {command down, shift down}
        end tell
        """
        if let scriptObject = NSAppleScript(source: script) {
            var error: NSDictionary?
            scriptObject.executeAndReturnError(&error)
            if let error = error {
                print("Error toggling Do Not Disturb: \"\"(error)\"")
            }
        } else {
            print("Could not create AppleScript to toggle Do Not Disturb")
        }
    }
    
    @objc func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
    
    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}
// EnhancedSnackbar - SimpleSnackbar with original 6 snacks
// Version: 1.1 - Enhanced Edition
// Created: 2024-04-29
// Features: Menu bar + original 6 snacks + clean UI

import AppKit
import SwiftUI

// MARK: - Snack Model (Original 6 Snacks)
struct Snack: Identifiable {
    let id: String
    let name: String
    let emoji: String
    let code: String
    let runtime: String  // "appleScript" or "shell"
    
    static func originalSnacks() -> [Snack] {
        return [
            Snack(id: "reminders", name: "Reminders", emoji: "📋", 
                  code: 'tell application "Reminders" to activate', runtime: "appleScript"),
            Snack(id: "mail_vip", name: "Mail VIP", emoji: "✉️",
                  code: 'tell application "Mail" to set vipCount to count of messages of inbox whose is VIP is true', 
                  runtime: "appleScript"),
            Snack(id: "contacts", name: "Contacts", emoji: "👥",
                  code: 'tell application "Contacts" to activate', runtime: "appleScript"),
            Snack(id: "notes", name: "Notes", emoji: "📓",
                  code: 'tell application "Notes" to activate', runtime: "appleScript"),
            Snack(id: "calendar", name: "Calendar", emoji: "📅",
                  code: 'tell application "Calendar" to activate', runtime: "appleScript"),
            Snack(id: "permissions", name: "Permissions", emoji: "🔐",
                  code: 'open x-apple.systempreferences:com.apple.preference.security?Privacy_Automation', 
                  runtime: "shell")
        ]
    }
}

// MARK: - Snack Executor
class SnackExecutor {
    static func execute(snack: Snack) {
        DispatchQueue.global(qos: .userInitiated).async {
            if snack.runtime == "appleScript" {
                let script = NSAppleScript(source: snack.code)
                var error: NSDictionary?
                _ = script?.executeAndReturnError(&error)
                
                let notification = NSUserNotification()
                notification.title = snack.name
                notification.informativeText = error == nil ? "Executed" : "Error"
                NSUserNotificationCenter.default.deliver(notification)
                
            } else if snack.runtime == "shell" {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                process.arguments = ["-c", snack.code]
                try? process.run()
                
                let notification = NSUserNotification()
                notification.title = snack.name
                notification.informativeText = "Executed"
                NSUserNotificationCenter.default.deliver(notification)
            }
        }
    }
}

// MARK: - Main App
@main
struct EnhancedSnackbarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    let snacks = Snack.originalSnacks()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "Snackbar")
            button.action = #selector(togglePopover(_:))
        }
        
        updatePopover()
    }
    
    func updatePopover() {
        popover = NSPopover()
        popover?.contentViewController = NSHostingController(rootView: ContentView(snacks: snacks))
        popover?.behavior = .transient
    }
    
    @objc func togglePopover(_ sender: Any?) {
        if let button = statusItem?.button {
            if popover?.isShown == true {
                popover?.performClose(sender)
            } else {
                popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }
}

// MARK: - Content View
struct ContentView: View {
    let snacks: [Snack]
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("📱 Snackbar").font(.headline)
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            // Snacks List
            Text("Original Snacks")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(snacks, id: \.id) { snack in
                        Button(action: {
                            SnackExecutor.execute(snack: snack)
                        }) {
                            HStack {
                                Text(snack.emoji)
                                Text(snack.name)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                            .padding(8)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Execute All
                    Button(action: {
                        for snack in snacks {
                            SnackExecutor.execute(snack: snack)
                        }
                    }) {
                        HStack {
                            Image(systemName: "bolt.fill")
                            Text("Execute All")
                        }
                        .padding(8)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(height: 200)
            
            // Status
            HStack {
                Text("6 original snacks ready")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
            }
        }
        .padding()
        .frame(width: 250)
    }
}

// SimpleSnackbar - Minimal working menu bar app
// Created: 2024-04-28
// Focus: Just make it work in the menu bar

import AppKit
import SwiftUI

@main
struct SimpleSnackbarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "Snackbar")
            button.action = #selector(togglePopover(_:))
        }
        
        // Create a simple popover
        let contentView = NSHostingController(rootView: 
            VStack(spacing: 16) {
                Text("📱 Snackbar").font(.headline)
                Divider()
                Text("Simple Notes App").font(.caption)
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding()
            .frame(width: 200)
        )
        
        popover = NSPopover()
        popover?.contentViewController = contentView
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

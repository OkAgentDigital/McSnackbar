import AppKit

class TestAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("✅ Minimal test app launched successfully!")
        
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "🍔"
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Test", action: #selector(testAction), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        for item in menu.items {
            item.target = self
        }
        
        statusItem.menu = menu
        print("🍔 Menu bar icon should be visible!")
    }
    
    @objc func testAction() {
        print("Test action triggered!")
        let alert = NSAlert()
        alert.messageText = "Hello from Snackbar!"
        alert.informativeText = "The app is working!"
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

let app = NSApplication.shared
let delegate = TestAppDelegate()
app.delegate = delegate
app.run()
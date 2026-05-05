import AppKit
import Foundation

// Snackbar v2.0 — Execution Spine of uDos
// One icon (🍔). One spool. Infinite snacks. One narrator.

// ── Singleton Port Lock ───────────────────────────────────────────────
// Prevents multiple instances by binding a local TCP port.
// If the port is already in use, another instance is running → quit.

private let kSingletonPort: UInt16 = 6_587  // "SNCK" on phone keypad

private func acquireSingletonLock() -> Bool {
    let socketFD = socket(AF_INET, SOCK_STREAM, 0)
    guard socketFD >= 0 else { return false }
    
    var addr = sockaddr_in()
    addr.sin_family = sa_family_t(AF_INET)
    addr.sin_port = CFSwapInt16HostToBig(kSingletonPort)
    addr.sin_addr.s_addr = INADDR_LOOPBACK
    
    let addrSize = socklen_t(MemoryLayout<sockaddr_in>.size)
    let bindResult = withUnsafePointer(to: &addr) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            Darwin.bind(socketFD, $0, addrSize)
        }
    }
    
    if bindResult == 0 {
        // Successfully bound → we are the one true instance
        // Keep the socket open for the lifetime of the process
        listen(socketFD, 1)
        return true
    } else {
        // Port already in use → another instance is running
        close(socketFD)
        return false
    }
}

// ── Main ──────────────────────────────────────────────────────────────

if !acquireSingletonLock() {
    // Bring existing instance to front instead
    let apps = NSWorkspace.shared.runningApplications
    if let existing = apps.first(where: { $0.bundleIdentifier == "com.udos.snackbar" }) {
        existing.activate(options: .activateIgnoringOtherApps)
    }
    print("⚠️ Snackbar is already running. Exiting.")
    exit(0)
}

let app = NSApplication.shared
let delegate = SnackbarAppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // Menu bar only, no dock icon
app.run()

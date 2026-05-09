import AppKit
import Foundation

// Snackbar v2.0 — Execution Spine of uDos
// One icon (🍔). One spool. Infinite snacks. One narrator.

// ── Singleton Lock ────────────────────────────────────────────────────
// Uses a lock file + advisory flock to prevent multiple instances.
// More reliable than raw TCP sockets — survives crashes, no TIME_WAIT issues,
// and works correctly with macOS app sandboxing.

private let kSingletonLockFile = "com.udos.snackbar.lock"

private func acquireSingletonLock() -> Bool {
    let lockDir = FileManager.default.temporaryDirectory
    let lockURL = lockDir.appendingPathComponent(kSingletonLockFile)
    
    // Open (or create) the lock file
    let fd = Darwin.open((lockURL.path as NSString).fileSystemRepresentation, O_RDWR | O_CREAT, 0o644)
    guard fd >= 0 else {
        print("❌ Singleton: failed to open lock file: \(errno)")
        return false
    }
    
    // Try to acquire an exclusive lock (non-blocking)
    let result = flock(fd, LOCK_EX | LOCK_NB)
    
    if result == 0 {
        // Lock acquired — write our PID to the file for diagnostics
        let pidStr = "\(ProcessInfo.processInfo.processIdentifier)\n"
        pidStr.withCString { bytes in
            Darwin.ftruncate(fd, 0)
            Darwin.write(fd, bytes, strlen(bytes))
        }
        // Keep fd open for the lifetime of the process (never close it)
        return true
    } else {
        Darwin.close(fd)
        
        if errno == EWOULDBLOCK || errno == EAGAIN {
            // Another instance holds the lock
            if let lockData = try? Data(contentsOf: lockURL),
               let lockStr = String(data: lockData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               let existingPID = Int32(lockStr) {
                print("⚠️ Snackbar is already running (PID: \(existingPID)). Activating existing instance.")
            } else {
                print("⚠️ Snackbar is already running. Activating existing instance.")
            }
            
            // Try to activate the existing instance
            let apps = NSWorkspace.shared.runningApplications
            if let existing = apps.first(where: { $0.bundleIdentifier == "com.udos.snackbar" }) {
                existing.activate()
            }
            return false
        } else {
            print("⚠️ Singleton lock error (\(errno)). Proceeding anyway...")
            return true
        }
    }
}

// ── Main ──────────────────────────────────────────────────────────────

if !acquireSingletonLock() {
    exit(0)
}

let app = NSApplication.shared
let delegate = SnackbarAppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // Menu bar only, no dock icon
app.run()

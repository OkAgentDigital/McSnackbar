import AppKit
import Foundation

// Snackbar v2.0 — Execution Spine of uDos
// One icon (🍔). One spool. Infinite snacks. One narrator.

let app = NSApplication.shared
let delegate = SnackbarAppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // Menu bar only, no dock icon
app.run()

import Cocoa

class PermissionsManager {
    static func requestAutomationPermission() {
        let script = "tell application \"System Events\" to keystroke \"a\""
        let appleScript = NSAppleScript(source: script)
        appleScript?.executeAndReturnError(nil)
    }
}
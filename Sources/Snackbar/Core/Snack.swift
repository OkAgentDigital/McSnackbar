import Foundation

struct Snack: Identifiable, Codable {
    let id: String
    let name: String
    let iconName: String
    let script: String
    var isEnabled: Bool
    var refreshInterval: Int

    init(id: String, name: String, iconName: String, script: String, isEnabled: Bool = true, refreshInterval: Int = 60) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.script = script
        self.isEnabled = isEnabled
        self.refreshInterval = refreshInterval
    }
}

extension Snack {
    static let defaultSnacks: [Snack] = [
        Snack(
            id: "reminders",
            name: "Reminders",
            iconName: "icon-reminders",
            script: """
            tell application "Reminders"
                set pendingCount to count of (reminders whose completed is false)
                return pendingCount
            end tell
            """,
            isEnabled: true
        ),
        Snack(
            id: "mail-vip",
            name: "Mail VIP",
            iconName: "icon-mail",
            script: """
            tell application "Mail"
                set vipCount to count of (messages of inbox whose VIP status is true and read status is false)
                return vipCount
            end tell
            """,
            isEnabled: true
        ),
        Snack(
            id: "contacts",
            name: "Contacts",
            iconName: "icon-contacts",
            script: """
            tell application "Contacts"
                set vipNames to name of people whose VIP is true
                set AppleScript's text item delimiters to ", "
                return vipNames as string
            end tell
            """,
            isEnabled: true
        ),
        Snack(
            id: "notes",
            name: "Notes",
            iconName: "icon-notes",
            script: """
            tell application "Notes"
                activate
            end tell
            """,
            isEnabled: false
        ),
        Snack(
            id: "calendar",
            name: "Calendar",
            iconName: "icon-calendar",
            script: """
            tell application "Calendar"
                activate
            end tell
            """,
            isEnabled: false
        ),
        Snack(
            id: "permissions",
            name: "Permissions Helper",
            iconName: "icon-permissions",
            script: """
            open location "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
            """,
            isEnabled: true
        )
    ]
}

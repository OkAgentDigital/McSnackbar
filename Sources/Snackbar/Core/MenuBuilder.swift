import AppKit

class MenuBuilder {
    private var builtInSnacks: [Snack] = []
    private var customSnacks: [Snack] = []
    private let defaults = UserDefaults.standard
    private let customSnacksKey = "customSnacks"
    
    init() {
        loadBuiltInSnacks()
        loadCustomSnacks()
    }
    
    private func loadBuiltInSnacks() {
        // First try to load from bundle
        if let url = Bundle.main.url(forResource: "snacks", withExtension: "json") {
            print("📂 Found snacks.json at: \(url.path)")
            if let data = try? Data(contentsOf: url),
               let snacks = try? JSONDecoder().decode([Snack].self, from: data) {
                builtInSnacks = snacks
                print("✅ Loaded \(snacks.count) snacks from bundle")
                return
            }
        }
        
        // Try to load from Resources directory
        let resourcesURL = URL(fileURLWithPath: "#(FileManager.default.currentDirectoryPath)/Resources")
        let snacksURL = resourcesURL.appendingPathComponent("snacks.json")
        if FileManager.default.fileExists(atPath: snacksURL.path),
           let data = try? Data(contentsOf: snacksURL),
           let snacks = try? JSONDecoder().decode([Snack].self, from: data) {
            builtInSnacks = snacks
            print("✅ Loaded \(snacks.count) snacks from Resources directory")
            return
        }
        
        // Fallback to hardcoded snacks if both methods fail
        print("⚠️ Loading fallback snacks...")
        builtInSnacks = [
            Snack(id: "reminders", name: "Reminders", emoji: "📋", 
                  code: "tell application \"Reminders\" to activate", runtime: "appleScript", categoryId: "productivity"),
            Snack(id: "notes", name: "Notes", emoji: "📓",
                  code: "tell application \"Notes\" to activate", runtime: "appleScript", categoryId: "productivity"),
            Snack(id: "calendar", name: "Calendar", emoji: "📅",
                  code: "tell application \"Calendar\" to activate", runtime: "appleScript", categoryId: "productivity"),
            Snack(id: "mail_vip", name: "Mail VIP", emoji: "✉️",
                  code: "tell application \"Mail\" to set vipCount to count of messages of inbox whose is VIP is true", 
                  runtime: "appleScript", categoryId: "communication"),
            Snack(id: "contacts", name: "Contacts", emoji: "👥",
                  code: "tell application \"Contacts\" to set vipNames to name of people whose is VIP is true", 
                  runtime: "appleScript", categoryId: "communication"),
            Snack(id: "permissions", name: "Permissions Helper", emoji: "🔐",
                  code: "open x-apple.systempreferences:com.apple.preference.security?Privacy_Automation", 
                  runtime: "shell", categoryId: "system")
        ]
    }
    
    private func loadCustomSnacks() {
        if let data = defaults.data(forKey: customSnacksKey),
           let snacks = try? JSONDecoder().decode([Snack].self, from: data) {
            customSnacks = snacks
        }
    }
    
    func getAllSnacks() -> [Snack] {
        return builtInSnacks + customSnacks
    }
    
    func buildMenu() -> NSMenu {
        let menu = NSMenu()
        
        // Run All option
        let runAllItem = NSMenuItem(title: "⚡ Run All Enabled", action: #selector(runAllSnacks), keyEquivalent: "R")
        runAllItem.keyEquivalentModifierMask = .command
        menu.addItem(runAllItem)
        
        // Add Snack option
        menu.addItem(NSMenuItem.separator())
        let addItem = NSMenuItem(title: "➕ Add New Snack...", action: #selector(addNewSnack), keyEquivalent: "N")
        addItem.keyEquivalentModifierMask = .command
        menu.addItem(addItem)
        
        // Import/Export
        let importExportItem = NSMenuItem(title: "📁 Import/Export...", action: #selector(importExportSnacks), keyEquivalent: "E")
        importExportItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(importExportItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Organize snacks by category
        let allSnacks = getAllSnacks()
        let enabledSnackIds = defaults.stringArray(forKey: "enabledSnacks") ?? []
        
        let categorizedSnacks = Dictionary(grouping: allSnacks) { snack -> String in
            return snack.category?.id ?? "uncategorized"
        }
        
        for category in Category.allCategories {
            if let snacksInCategory = categorizedSnacks[category.id], !snacksInCategory.isEmpty {
                addSnacksMenu(for: snacksInCategory, enabledSnackIds: enabledSnackIds, to: menu, category: category)
            }
        }
        
        // About and Preferences
        menu.addItem(NSMenuItem.separator())
        let aboutItem = NSMenuItem(title: "ℹ️ About Snackbar", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = NSApp.delegate
        menu.addItem(aboutItem)
        
        let prefsItem = NSMenuItem(title: "⚙️ Preferences...", action: #selector(openPreferences), keyEquivalent: ",")
        prefsItem.target = NSApp.delegate
        menu.addItem(prefsItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        return menu
    }
    
    private func addSnacksMenu(for snacks: [Snack], enabledSnackIds: [String], to menu: NSMenu, category: Category) {
        let categoryMenu = NSMenu(title: "\(category.emoji) \(category.name)")
        
        for snack in snacks {
            let item = NSMenuItem(title: "\(snack.emoji) \(snack.name)", action: #selector(executeSnack), keyEquivalent: "")
            item.representedObject = snack
            item.target = self
            categoryMenu.addItem(item)
        }
        
        let categoryItem = NSMenuItem(title: "\(category.emoji) \(category.name)", action: nil, keyEquivalent: "")
        categoryItem.submenu = categoryMenu
        menu.addItem(categoryItem)
    }
    
    @objc private func executeSnack(_ sender: NSMenuItem) {
        guard let snack = sender.representedObject as? Snack else { return }
        SnackExecutor.run(snack)
    }
    
    @objc private func runAllSnacks() {
        let allSnacks = getAllSnacks()
        let enabledSnackIds = defaults.stringArray(forKey: "enabledSnacks") ?? []
        let snacksToRun = enabledSnackIds.isEmpty ? allSnacks : allSnacks.filter { enabledSnackIds.contains($0.id) }
        
        for snack in snacksToRun {
            SnackExecutor.run(snack)
        }
    }
    
    @objc private func addNewSnack() {
        (NSApp.delegate as? AppDelegate)?.showAddSnackView()
    }
    
    @objc private func importExportSnacks() {
        (NSApp.delegate as? AppDelegate)?.showImportExportView()
    }
    
    @objc private func showAbout() {
        (NSApp.delegate as? AppDelegate)?.showAboutView()
    }
    
    @objc private func openPreferences() {
        (NSApp.delegate as? AppDelegate)?.showPreferencesView()
    }
}
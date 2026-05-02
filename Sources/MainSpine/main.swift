// MainSpine - Unified Snackbar with Original 6 Snacks
// Version: 1.0 - Consolidated Edition
// Created: 2024-04-28
// Focus: One main app with original 6 snacks working

import AppKit
import SwiftUI
import Combine

// MARK: - Snack Model (Original 6 Snacks)
struct Snack: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let emoji: String
    let code: String
    let runtime: String  // "appleScript" or "shell"
    let categoryId: String
    var isEnabled: Bool
    
    // Original 6 snacks
    static func originalSnacks() -> [Snack] {
        return [
            Snack(id: "reminders", name: "Reminders", description: "Open the Reminders app.", 
                  emoji: "📋", code: 'tell application "Reminders" to activate', 
                  runtime: "appleScript", categoryId: "productivity", isEnabled: true),
            
            Snack(id: "mail_vip", name: "Mail VIP", description: "Count VIP emails in your inbox.", 
                  emoji: "✉️", code: 'tell application "Mail" to set vipCount to count of messages of inbox whose is VIP is true', 
                  runtime: "appleScript", categoryId: "communication", isEnabled: true),
            
            Snack(id: "contacts", name: "Contacts", description: "Open the Contacts app.", 
                  emoji: "👥", code: 'tell application "Contacts" to activate', 
                  runtime: "appleScript", categoryId: "communication", isEnabled: true),
            
            Snack(id: "notes", name: "Notes", description: "Open the Notes app.", 
                  emoji: "📓", code: 'tell application "Notes" to activate', 
                  runtime: "appleScript", categoryId: "productivity", isEnabled: true),
            
            Snack(id: "calendar", name: "Calendar", description: "Open the Calendar app.", 
                  emoji: "📅", code: 'tell application "Calendar" to activate', 
                  runtime: "appleScript", categoryId: "productivity", isEnabled: true),
            
            Snack(id: "permissions", name: "Permissions Helper", description: "Open the Permissions settings.", 
                  emoji: "🔐", code: 'open x-apple.systempreferences:com.apple.preference.security?Privacy_Automation', 
                  runtime: "shell", categoryId: "system", isEnabled: true)
        ]
    }
}

// MARK: - Snack Executor
class SnackExecutor {
    static func execute(snack: Snack, completion: @escaping (Result<String, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                var output = ""
                
                if snack.runtime == "appleScript" {
                    // Execute AppleScript
                    let script = NSAppleScript(source: snack.code)
                    var error: NSDictionary?
                    if let result = script?.executeAndReturnError(&error), 
                       error == nil {
                        output = result.stringValue ?? "Executed successfully"
                    } else if let err = error {
                        throw NSError(domain: "SnackError", code: 1, 
                                    userInfo: [NSLocalizedDescriptionKey: err.description ?? "AppleScript error"])
                    }
                } else if snack.runtime == "shell" {
                    // Execute shell command
                    let process = Process()
                    let pipe = Pipe()
                    
                    process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                    process.arguments = ["-c", snack.code]
                    process.standardOutput = pipe
                    
                    try process.run()
                    process.waitUntilExit()
                    
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    if let result = String(data: data, encoding: .utf8) {
                        output = result
                    }
                    
                    if process.terminationStatus != 0 {
                        throw NSError(domain: "SnackError", code: Int(process.terminationStatus), 
                                    userInfo: [NSLocalizedDescriptionKey: output])
                    }
                }
                
                DispatchQueue.main.async {
                    completion(.success(output))
                }
                
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
}

// MARK: - Note Model (From CompleteSnackbar)
struct Note: Identifiable, Codable {
    let id: UUID
    var title: String
    var content: String
    var createdAt: Date
    var updatedAt: Date
    var tags: [String]
    var isSynced: Bool
    
    init(id: UUID = UUID(), title: String, content: String, 
         createdAt: Date = Date(), updatedAt: Date = Date(), 
         tags: [String] = [], isSynced: Bool = false) {
        self.id = id
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.tags = tags
        self.isSynced = isSynced
    }
}

// MARK: - Note Manager
class NoteManager: ObservableObject {
    @Published var notes: [Note] = []
    
    init() {
        loadNotes()
    }
    
    func addNote(title: String, content: String) {
        let note = Note(title: title, content: content)
        notes.append(note)
        saveNotes()
    }
    
    func saveNotes() {
        if let data = try? JSONEncoder().encode(notes) {
            let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
                .first?.appendingPathComponent("com.udos.MainSpine/notes.json")
            try? FileManager.default.createDirectory(at: url?.deletingLastPathComponent() ?? URL(fileURLWithPath: "/"), 
                                                     withIntermediateDirectories: true)
            try? data.write(to: url ?? URL(fileURLWithPath: "/dev/null"))
        }
    }
    
    func loadNotes() {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("com.udos.MainSpine/notes.json")
        if let data = try? Data(contentsOf: url ?? URL(fileURLWithPath: "/dev/null")),
           let decoded = try? JSONDecoder().decode([Note].self, from: data) {
            notes = decoded
        }
    }
}

// MARK: - Main App
@main
struct MainSpineApp: App {
    @StateObject private var noteManager = NoteManager()
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
    var noteManager = NoteManager()
    var snacks = Snack.originalSnacks()
    
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
        let contentView = NSHostingController(rootView: 
            MainView(noteManager: noteManager, snacks: snacks, onUpdate: { [weak self] in
                self?.updatePopover()
            })
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

// MARK: - Main View
struct MainView: View {
    @ObservedObject var noteManager: NoteManager
    let snacks: [Snack]
    var onUpdate: () -> Void
    @State private var newNoteTitle = ""
    @State private var newNoteContent = ""
    @State private var showingSnacks = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("📱 MainSpine").font(.headline)
                Spacer()
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            // Toggle between Notes and Snacks
            Picker("Mode", selection: $showingSnacks) {
                Text("Notes").tag(false)
                Text("Snacks").tag(true)
            }
            .pickerStyle(.segmented)
            
            if showingSnacks {
                // Snacks View
                SnacksView(snacks: snacks)
            } else {
                // Notes View (from CompleteSnackbar)
                NotesView(noteManager: noteManager, 
                         newNoteTitle: $newNoteTitle, 
                         newNoteContent: $newNoteContent)
            }
            
            // Status
            HStack {
                Text(""\(noteManager.notes.count) notes, " + 
                     ""\(snacks.count) snacks")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
            }
        }
        .padding()
        .frame(width: 350)
    }
}

// MARK: - Notes View (From CompleteSnackbar)
struct NotesView: View {
    @ObservedObject var noteManager: NoteManager
    @Binding var newNoteTitle: String
    @Binding var newNoteContent: String
    
    var body: some View {
        VStack(spacing: 8) {
            TextField("Title", text: $newNoteTitle)
                .textFieldStyle(.roundedBorder)
            
            TextEditor(text: $newNoteContent)
                .frame(height: 100)
                .border(Color.gray.opacity(0.3))
            
            Button("Add Note") {
                if !newNoteTitle.isEmpty {
                    noteManager.addNote(title: newNoteTitle, content: newNoteContent)
                    newNoteTitle = ""
                    newNoteContent = ""
                }
            }
            .disabled(newNoteTitle.isEmpty)
            
            if noteManager.notes.isEmpty {
                Text("No notes yet")
                    .foregroundColor(.gray)
                    .font(.caption)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(noteManager.notes) { note in
                            NoteRow(note: note)
                        }
                    }
                }
                .frame(height: 150)
            }
        }
    }
}

// MARK: - Snacks View (Original 6 Snacks)
struct SnacksView: View {
    let snacks: [Snack]
    @State private var executionOutput = ""
    @State private var showingOutput = false
    
    // Group snacks by category
    private var categorizedSnacks: [String: [Snack]] {
        var result = [String: [Snack]]()
        for snack in snacks {
            if result[snack.categoryId] == nil {
                result[snack.categoryId] = [snack]
            } else {
                result[snack.categoryId]?.append(snack)
            }
        }
        return result
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Productivity
                if let productivity = categorizedSnacks["productivity"] {
                    CategorySection(title: "📋 Productivity", snacks: productivity, 
                                   onExecute: executeSnack)
                }
                
                // Communication
                if let communication = categorizedSnacks["communication"] {
                    CategorySection(title: "💬 Communication", snacks: communication, 
                                   onExecute: executeSnack)
                }
                
                // System
                if let system = categorizedSnacks["system"] {
                    CategorySection(title: "⚙️ System", snacks: system, 
                                   onExecute: executeSnack)
                }
                
                // Execute All
                Button(action: {
                    executeAllSnacks()
                }) {
                    HStack {
                        Image(systemName: "bolt.fill")
                        Text("Execute All Enabled")
                    }
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    private func executeSnack(snack: Snack) {
        SnackExecutor.execute(snack: snack) { result in
            switch result {
            case .success(let output):
                executionOutput = "✅ " + snack.name + "\n" + output
                showingOutput = true
                
                // Show notification
                let notification = NSUserNotification()
                notification.title = snack.name
                notification.informativeText = "Executed successfully"
                NSUserNotificationCenter.default.deliver(notification)
                
            case .failure(let error):
                executionOutput = "❌ " + snack.name + "\n" + error.localizedDescription
                showingOutput = true
                
                let notification = NSUserNotification()
                notification.title = snack.name
                notification.informativeText = "Error: " + error.localizedDescription
                NSUserNotificationCenter.default.deliver(notification)
            }
        }
    }
    
    private func executeAllSnacks() {
        let enabledSnacks = snacks.filter { $0.isEnabled }
        guard !enabledSnacks.isEmpty else { return }
        
        executionOutput = "Executing " + String(enabledSnacks.count) + " snacks...\n\n"
        showingOutput = true
        
        for snack in enabledSnacks {
            SnackExecutor.execute(snack: snack) { result in
                switch result {
                case .success(let output):
                    DispatchQueue.main.async {
                        executionOutput += "✅ " + snack.name + "\n"
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        executionOutput += "❌ " + snack.name + ": " + error.localizedDescription + "\n"
                    }
                }
            }
        }
    }
}

// MARK: - Category Section
struct CategorySection: View {
    let title: String
    let snacks: [Snack]
    let onExecute: (Snack) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            ForEach(snacks, id: \.id) { snack in
                Button(action: {
                    onExecute(snack)
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
        }
    }
}

// MARK: - Note Row (From CompleteSnackbar)
struct NoteRow: View {
    let note: Note
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(note.title).font(.headline)
            Text(note.content)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
            Divider()
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

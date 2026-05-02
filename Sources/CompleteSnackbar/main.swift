// CompleteSnackbar - Full-featured menu bar app with all features
// Created: 2024-04-28
// Combines: Simple UI + Core Features + DevStudio Integration

import AppKit
import SwiftUI
import Combine

// MARK: - Core Data Models
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

// MARK: - Note Manager (Simplified)
class NoteManager: ObservableObject {
    @Published var notes: [Note] = []
    
    func addNote(title: String, content: String) {
        let note = Note(title: title, content: content)
        notes.append(note)
        saveNotes()
    }
    
    func saveNotes() {
        if let data = try? JSONEncoder().encode(notes) {
            let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
                .first?.appendingPathComponent("com.udos.Snackbar/notes.json")
            try? FileManager.default.createDirectory(at: url?.deletingLastPathComponent() ?? URL(fileURLWithPath: "/"), 
                                                     withIntermediateDirectories: true)
            try? data.write(to: url ?? URL(fileURLWithPath: "/dev/null"))
        }
    }
    
    func loadNotes() {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("com.udos.Snackbar/notes.json")
        if let data = try? Data(contentsOf: url ?? URL(fileURLWithPath: "/dev/null")),
           let decoded = try? JSONDecoder().decode([Note].self, from: data) {
            notes = decoded
        }
    }
}

// MARK: - Main App
@main
struct CompleteSnackbarApp: App {
    @StateObject private var noteManager = NoteManager()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        noteManager.loadNotes()
    }
    
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
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        noteManager.loadNotes()
        
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "Snackbar")
            button.action = #selector(togglePopover(_:))
        }
        
        // Create main popover
        updatePopover()
    }
    
    func updatePopover() {
        let contentView = NSHostingController(rootView: 
            MainView(noteManager: noteManager, onUpdate: { [weak self] in
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
    var onUpdate: () -> Void
    @State private var newNoteTitle = ""
    @State private var newNoteContent = ""
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("📱 Snackbar").font(.headline)
                Spacer()
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            // Note creation
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
                        onUpdate()
                    }
                }
                .disabled(newNoteTitle.isEmpty)
            }
            
            Divider()
            
            // Notes list
            if noteManager.notes.isEmpty {
                VStack(spacing: 8) {
                    Text("No notes yet").foregroundColor(.gray)
                    Text("Add your first note above").foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(noteManager.notes) { note in
                            NoteRow(note: note)
                        }
                    }
                }
                .frame(height: 200)
            }
            
            // Status
            HStack {
                Text("\(noteManager.notes.count) notes")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
            }
        }
        .padding()
        .frame(width: 300)
    }
}

// MARK: - Note Row
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

// ContentView.swift
// Snackbar
//
// Created by DevStudio Integration
//

import SwiftUI
import SnackbarCore
import Snackbar

struct ContentView: View {
    @StateObject private var noteManager = NoteManager.shared
    @StateObject private var syncMonitor = SyncStatusMonitor.shared
    @StateObject private var mcpClient = MCPClient.shared
    @StateObject private var devToolsManager = DevToolsManager.shared
    @State private var newNoteTitle = ""
    @State private var newNoteContent = ""
    @State private var showingDevStudioSkill = false
    @State private var skillName = ""
    @State private var skillArgs = ""
    @State private var useMCP = true
    @State private var showinguDosManager = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Snackbar").font(.headline)
                Spacer()
                
                // Sync status indicators
                HStack(spacing: 8) {
                    if syncMonitor.isOnline {
                        Image(systemName: "wifi")
                            .foregroundColor(.green)
                            .help("Online")
                    } else {
                        Image(systemName: "wifi.slash")
                            .foregroundColor(.gray)
                            .help("Offline")
                    }
                    
                    if syncMonitor.iCloudAvailable {
                        Image(systemName: "icloud")
                            .foregroundColor(.blue)
                            .help("iCloud Available")
                    } else {
                        Image(systemName: "icloud.slash")
                            .foregroundColor(.gray)
                            .help("iCloud Not Available")
                    }
                    
                    if syncMonitor.hasPendingChanges {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.orange)
                            .help("Pending Changes")
                    }
                    
                    // MCP connection status
                    if mcpClient.isConnected {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(.green)
                            .help("MCP Connected")
                    } else {
                        Image(systemName: "bolt.slash")
                            .foregroundColor(.gray)
                            .help("MCP Disconnected")
                    }
                }
            }
            
            Divider()
            
            // Note creation
            VStack(spacing: 8) {
                TextField("Note Title", text: $newNoteTitle)
                    .textFieldStyle(.roundedBorder)
                
                TextEditor(text: $newNoteContent)
                    .frame(height: 100)
                    .border(Color.gray.opacity(0.3), width: 1)
                    .cornerRadius(4)
                
                HStack {
                    Button("Add Note") {
                        addNote()
                    }
                    .disabled(newNoteTitle.isEmpty)
                    
                    Button("Sync Now") {
                        syncNotes()
                    }
                    .disabled(!syncMonitor.isOnline || !syncMonitor.iCloudAvailable)
                }
            }
            
            Divider()
            
            // Notes list
            List {
                ForEach(noteManager.notes) { note in
                    NoteRow(note: note, onUpdate: { updatedContent in
                        noteManager.updateNote(note, newContent: updatedContent)
                    }, onDelete: {
                        noteManager.deleteNote(note)
                    })
                }
            }
            
            Divider()
            
            // DevStudio Integration
            VStack(spacing: 8) {
                HStack {
                    Button("Trigger DevStudio Skill") {
                        showingDevStudioSkill.toggle()
                    }
                    
                    Toggle("Use MCP", isOn: $useMCP)
                        .toggleStyle(.switch)
                        .help("Use MCP for real-time communication")
                }
                
                if !mcpClient.isConnected {
                    Button("Connect to MCP") {
                        mcpClient.connect()
                    }
                    .disabled(mcpClient.isConnected)
                }
                
                if showingDevStudioSkill {
                    VStack(spacing: 8) {
                        TextField("Skill Name (e.g., VAULTRUN)", text: $skillName)
                            .textFieldStyle(.roundedBorder)
                        
                        TextField("Arguments (space separated)", text: $skillArgs)
                            .textFieldStyle(.roundedBorder)
                        
                        HStack {
                            Button("Trigger") {
                                triggerDevStudioSkill()
                            }
                            .disabled(skillName.isEmpty)
                            
                            Button("Cancel") {
                                showingDevStudioSkill = false
                            }
                        }
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.1)))
                }
            }
            
            // Status footer
            HStack {
                if let lastSync = noteManager.lastSyncDate {
                    Text("Last sync: " + lastSync.formatted())
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Text(""\(noteManager.notes.count) notes")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Divider()
            
            // DevTools Section
            VStack(spacing: 8) {
                HStack {
                    Text("DevTools").font(.headline).font(.caption)
                    Spacer()
                    
                    if devToolsManager.isSyncing {
                        ProgressView()
                            .controlSize(.mini)
                    }
                }
                
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(devToolsManager.config.debugging.consoleCommands, id: \.name) { command in
                            Button(action: {
                                devToolsManager.executeConsoleCommand(named: command.name) { result in
                                    switch result {
                                    case .success(let output):
                                        print("Command output: " + output)
                                    case .failure(let error):
                                        print("Command error: " + error.localizedDescription)
                                    }
                                }
                            }) {
                                VStack(spacing: 4) {
                                    Image(systemName: "terminal")
                                        .font(.caption)
                                    Text(command.name)
                                        .font(.system(size: 10))
                                        .lineLimit(1)
                                }
                                .frame(width: 80, height: 60)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                                .help(command.description)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(height: 80)
            }
            
            // uDos Component Manager
            VStack(spacing: 8) {
                HStack {
                    Button(action: {
                        showinguDosManager.toggle()
                    }) {
                        HStack {
                            Text("🍫 uDos Components")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .rotationEffect(.degrees(showinguDosManager ? 90 : 0))
                                .animation(.easeInOut, value: showinguDosManager)
                        }
                        .font(.headline)
                    }
                }
                
                if showinguDosManager {
                    uDosComponentView()
                        .frame(height: 400)
                }
            }
        }
        .padding()
        .frame(width: 300)
    }
    
    private func addNote() {
        noteManager.addNote(title: newNoteTitle, content: newNoteContent)
        newNoteTitle = ""
        newNoteContent = ""
    }
    
    private func syncNotes() {
        syncMonitor.forceSync { result in
            if case .failure(let error) = result {
                print("Sync error: " + error.localizedDescription)
            }
        }
    }
    
    private func triggerDevStudioSkill() {
        let args = skillArgs.isEmpty ? [] : skillArgs.components(separatedBy: " ")
        
        if useMCP && mcpClient.isConnected {
            DevStudioSkillTrigger.shared.sendViaMCP(skillName, arguments: args) { result in
                switch result {
                case .success(let output):
                    print("MCP Skill output: " + output)
                case .failure(let error):
                    print("MCP Skill error: " + error.localizedDescription)
                }
            }
        } else {
            DevStudioSkillTrigger.shared.runSkill(command: skillName + " " + args.joined(separator: " ")) { result in
                switch result {
                case .success(let output):
                    print("CLI Skill output: " + output)
                case .failure(let error):
                    print("CLI Skill error: " + error.localizedDescription)
                }
            }
        }
        
        showingDevStudioSkill = false
        skillName = ""
        skillArgs = ""
    }
}

struct NoteRow: View {
    let note: Note
    let onUpdate: (String) -> Void
    let onDelete: () -> Void
    
    @State private var isEditing = false
    @State private var editedContent = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(note.title)
                    .font(.headline)
                
                Spacer()
                
                if !note.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(note.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }
            }
            
            if isEditing {
                TextEditor(text: $editedContent)
                    .border(Color.gray.opacity(0.3), width: 1)
                    .cornerRadius(4)
                
                HStack {
                    Button("Save") {
                        onUpdate(editedContent)
                        isEditing = false
                    }
                    
                    Button("Cancel") {
                        isEditing = false
                    }
                }
            } else {
                Text(note.content)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                
                HStack {
                    Button(action: {
                        editedContent = note.content
                        isEditing = true
                    }) {
                        Image(systemName: "pencil")
                            .help("Edit")
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .help("Delete")
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    if note.isSynced {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(.green)
                            .help("Synced")
                    } else {
                        Image(systemName: "clock")
                            .foregroundColor(.orange)
                            .help("Pending Sync")
                    }
                }
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

struct SettingsView: View {
    var body: some View {
        Text("Settings")
            .padding()
    }
}

#Preview {
    ContentView()
}
// SnackbarAppleScriptHandler.swift
// Snackbar
//
// Created by DevStudio Integration
//

import Foundation
import ScriptingBridge
import SnackbarCore

/// AppleScript handler for Snackbar
/// This class exposes Snackbar functionality to AppleScript
@objc class SnackbarAppleScriptHandler: NSObject {
    
    // MARK: - Note Management
    
    @objc func createNote(title: String, content: String, tags: [String]) -> NSAppleEventDescriptor {
        let noteManager = NoteManager.shared
        noteManager.addNote(title: title, content: content, tags: tags)
        
        guard let note = noteManager.notes.last else {
            return NSAppleEventDescriptor(string: "Failed to create note")
        }
        
        return noteDescriptor(for: note)
    }
    
    @objc func getNotes() -> NSAppleEventDescriptor {
        let noteManager = NoteManager.shared
        let notes = noteManager.notes
        
        let noteDescriptors = notes.map { noteDescriptor(for: $0) }
        return NSAppleEventDescriptor(list: noteDescriptors)
    }
    
    @objc func updateNote(id: String, newContent: String) -> NSAppleEventDescriptor {
        let noteManager = NoteManager.shared
        
        guard let uuid = UUID(uuidString: id),
              let note = noteManager.notes.first(where: { $0.id == uuid }) else {
            return NSAppleEventDescriptor(string: "Note not found")
        }
        
        noteManager.updateNote(note, newContent: newContent)
        return noteDescriptor(for: note)
    }
    
    @objc func deleteNote(id: String) -> NSAppleEventDescriptor {
        let noteManager = NoteManager.shared
        
        guard let uuid = UUID(uuidString: id),
              let note = noteManager.notes.first(where: { $0.id == uuid }) else {
            return NSAppleEventDescriptor(string: "Note not found")
        }
        
        noteManager.deleteNote(note)
        return NSAppleEventDescriptor(string: "Note deleted successfully")
    }
    
    // MARK: - Sync Management
    
    @objc func syncNotes() -> NSAppleEventDescriptor {
        let syncMonitor = SyncStatusMonitor.shared
        
        if !syncMonitor.isOnline {
            return NSAppleEventDescriptor(string: "Offline - cannot sync")
        }
        
        if !syncMonitor.iCloudAvailable {
            return NSAppleEventDescriptor(string: "iCloud not available")
        }
        
        let expectation = self.expectation(description: "Sync completion")
        
        syncMonitor.forceSync { result in
            switch result {
            case .success:
                expectation.fulfill(with: NSAppleEventDescriptor(string: "Sync completed successfully"))
            case .failure(let error):
                expectation.fulfill(with: NSAppleEventDescriptor(string: "Sync failed: " + error.localizedDescription))
            }
        }
        
        return expectation
    }
    
    @objc func getSyncStatus() -> NSAppleEventDescriptor {
        let syncMonitor = SyncStatusMonitor.shared
        
        let statusDict: [String: Any] = [
            "isOnline": syncMonitor.isOnline,
            "iCloudAvailable": syncMonitor.iCloudAvailable,
            "hasPendingChanges": syncMonitor.hasPendingChanges
        ]
        
        return NSAppleEventDescriptor(dictionary: statusDict)
    }
    
    // MARK: - DevStudio Integration
    
    @objc func triggerDevStudioSkill(skillName: String, arguments: String) -> NSAppleEventDescriptor {
        let skillTrigger = DevStudioSkillTrigger.shared
        let expectation = self.expectation(description: "Skill execution")
        
        let command = arguments.isEmpty ? skillName : skillName + " " + arguments
        
        skillTrigger.runSkill(command: command) { result in
            switch result {
            case .success(let output):
                expectation.fulfill(with: NSAppleEventDescriptor(string: output))
            case .failure(let error):
                expectation.fulfill(with: NSAppleEventDescriptor(string: "Error: " + error.localizedDescription))
            }
        }
        
        return expectation
    }
    
    // MARK: - Helper Methods
    
    private func noteDescriptor(for note: Note) -> NSAppleEventDescriptor {
        let noteDict: [String: Any] = [
            "id": note.id.uuidString,
            "title": note.title,
            "content": note.content,
            "createdAt": note.createdAt.timeIntervalSince1970,
            "updatedAt": note.updatedAt.timeIntervalSince1970,
            "tags": note.tags,
            "isSynced": note.isSynced
        ]
        
        return NSAppleEventDescriptor(dictionary: noteDict)
    }
    
    private func expectation(description: String) -> NSAppleEventDescriptor {
        // Create a placeholder descriptor that will be updated when the async operation completes
        let descriptor = NSAppleEventDescriptor(string: "Operation in progress...")
        
        // In a real implementation, you would use a more sophisticated mechanism
        // to update this descriptor when the async operation completes
        // This is a simplified version for demonstration
        
        return descriptor
    }
}

// MARK: - AppleScript Bridge Extension

extension SnackbarAppleScriptHandler {
    
    /// Register this handler with the Scripting Bridge
    @objc class func registerScriptingSupport() {
        // This method is called to register our AppleScript support
        // In a real app, you would also need to:
        // 1. Create a proper .sdef file
        // 2. Register the scripting definition
        // 3. Handle Apple Events properly
        
        print("Snackbar AppleScript support registered")
    }
}
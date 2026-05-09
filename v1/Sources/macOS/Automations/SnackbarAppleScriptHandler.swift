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
        
        let descriptor = NSAppleEventDescriptor.list()
        for (index, note) in notes.enumerated() {
            descriptor.insert(noteDescriptor(for: note), at: index + 1)
        }
        return descriptor
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
        
        syncMonitor.forceSync { result in
            switch result {
            case .success:
                print("Sync completed successfully")
            case .failure(let error):
                print("Sync failed: " + error.localizedDescription)
            }
        }
        
        return NSAppleEventDescriptor(string: "Sync started")
    }
    
    @objc func getSyncStatus() -> NSAppleEventDescriptor {
        let syncMonitor = SyncStatusMonitor.shared
        
        let statusDict: [String: NSAppleEventDescriptor] = [
            "isOnline": NSAppleEventDescriptor(boolean: syncMonitor.isOnline),
            "iCloudAvailable": NSAppleEventDescriptor(boolean: syncMonitor.iCloudAvailable),
            "lastSyncDate": NSAppleEventDescriptor(double: syncMonitor.lastSyncDate?.timeIntervalSince1970 ?? 0)
        ]
        
        let record = NSAppleEventDescriptor.record()
        for (key, value) in statusDict {
            record.setDescriptor(value, forKeyword: AEKeyword(bitPattern: Int32(key.hashValue)))
        }
        
        return record
    }
    
    // MARK: - DevStudio Integration
    
    @objc func triggerDevStudioSkill(skillName: String, arguments: String) -> NSAppleEventDescriptor {
        let skillTrigger = DevStudioSkillTrigger.shared
        
        // Use a semaphore to wait for the async operation since this is a synchronous AppleScript call
        let semaphore = DispatchSemaphore(value: 0)
        
        let command = arguments.isEmpty ? skillName : skillName + " " + arguments
        
        skillTrigger.runSkill(command: command) { result in
            semaphore.signal()
        }
        
        _ = semaphore.wait(timeout: .now() + 30)
        
        return NSAppleEventDescriptor(string: "OK")
    }
    
    // MARK: - Helper Methods
    
    private func noteDescriptor(for note: Note) -> NSAppleEventDescriptor {
        return NSAppleEventDescriptor(string: "Note: \(note.title)")
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
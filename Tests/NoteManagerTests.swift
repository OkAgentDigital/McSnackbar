// NoteManagerTests.swift
// SnackbarTests
//
// Created by DevStudio Integration
//

import XCTest
import Combine
@testable import SnackbarCore

class NoteManagerTests: XCTestCase {
    var noteManager: NoteManager!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        noteManager = NoteManager()
        cancellables = Set<AnyCancellable>()
        
        // Clear any existing notes
        noteManager.notes.removeAll()
    }
    
    override func tearDown() {
        noteManager = nil
        cancellables = nil
        super.tearDown()
    }

    // MARK: - Note Management Tests
    
    func testAddNote() {
        let expectation = XCTestExpectation(description: "Add note")
        
        noteManager.addNote(title: "Test Note", content: "Test Content")
        
        DispatchQueue.main.async {
            XCTAssertEqual(self.noteManager.notes.count, 1)
            XCTAssertEqual(self.noteManager.notes[0].title, "Test Note")
            XCTAssertEqual(self.noteManager.notes[0].content, "Test Content")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }

    func testUpdateNote() {
        let expectation = XCTestExpectation(description: "Update note")
        
        // Add a note first
        noteManager.addNote(title: "Original", content: "Original Content")
        
        DispatchQueue.main.async {
            guard let note = self.noteManager.notes.first else {
                XCTFail("No note to update")
                return
            }
            
            self.noteManager.updateNote(note, newContent: "Updated Content")
            
            XCTAssertEqual(self.noteManager.notes.count, 1)
            XCTAssertEqual(self.noteManager.notes[0].content, "Updated Content")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }

    func testDeleteNote() {
        let expectation = XCTestExpectation(description: "Delete note")
        
        // Add a note first
        noteManager.addNote(title: "To Delete", content: "Content")
        
        DispatchQueue.main.async {
            guard let note = self.noteManager.notes.first else {
                XCTFail("No note to delete")
                return
            }
            
            self.noteManager.deleteNote(note)
            
            XCTAssertEqual(self.noteManager.notes.count, 0)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Sync Status Monitor Tests
    
    func testSyncStatusMonitorInitialization() {
        let syncMonitor = SyncStatusMonitor.shared
        
        // Should initialize with default values
        XCTAssertTrue(syncMonitor.isOnline)
        XCTAssertFalse(syncMonitor.iCloudAvailable)
        XCTAssertFalse(syncMonitor.hasPendingChanges)
    }

    func testAddPendingNote() {
        let syncMonitor = SyncStatusMonitor.shared
        let testNote = Note(title: "Pending", content: "Test")
        
        syncMonitor.addPendingNote(testNote)
        
        XCTAssertTrue(syncMonitor.hasPendingChanges)
        XCTAssertEqual(syncMonitor.getPendingNotes().count, 1)
    }

    func testRemovePendingNote() {
        let syncMonitor = SyncStatusMonitor.shared
        let testNote = Note(title: "Pending", content: "Test")
        
        syncMonitor.addPendingNote(testNote)
        syncMonitor.removePendingNote(testNote)
        
        XCTAssertFalse(syncMonitor.hasPendingChanges)
        XCTAssertEqual(syncMonitor.getPendingNotes().count, 0)
    }

    // MARK: - Note Model Tests
    
    func testNoteInitialization() {
        let note = Note(title: "Test", content: "Content")
        
        XCTAssertNotNil(note.id)
        XCTAssertEqual(note.title, "Test")
        XCTAssertEqual(note.content, "Content")
        XCTAssertFalse(note.isSynced)
        XCTAssertNotNil(note.createdAt)
        XCTAssertNotNil(note.updatedAt)
    }

    func testNoteUpdateContent() {
        var note = Note(title: "Test", content: "Original")
        note.updateContent("Updated")
        
        XCTAssertEqual(note.content, "Updated")
        XCTAssertNotEqual(note.createdAt, note.updatedAt)
    }

    func testNoteAddTag() {
        var note = Note(title: "Test", content: "Content")
        note.addTag("important")
        
        XCTAssertEqual(note.tags.count, 1)
        XCTAssertTrue(note.tags.contains("important"))
        
        // Test duplicate tag handling
        note.addTag("important")
        XCTAssertEqual(note.tags.count, 1)
    }

    func testNoteMarkAsSynced() {
        var note = Note(title: "Test", content: "Content")
        XCTAssertFalse(note.isSynced)
        
        note.markAsSynced()
        XCTAssertTrue(note.isSynced)
    }

    func testNoteExample() {
        let note = Note.example()
        
        XCTAssertEqual(note.title, "Example Note")
        XCTAssertEqual(note.content, "This is an example note for testing.")
        XCTAssertTrue(note.tags.contains("example"))
        XCTAssertTrue(note.tags.contains("test"))
    }

    // MARK: - Local Storage Tests
    
    func testLocalStorageSaveAndLoad() {
        let expectation = XCTestExpectation(description: "Local storage")
        
        // Add some test notes
        noteManager.addNote(title: "Note 1", content: "Content 1")
        noteManager.addNote(title: "Note 2", content: "Content 2")
        
        DispatchQueue.main.async {
            // Verify notes were added
            XCTAssertEqual(self.noteManager.notes.count, 2)
            
            // Create a new manager to test loading
            let newManager = NoteManager()
            
            DispatchQueue.main.async {
                // Notes should persist
                XCTAssertEqual(newManager.notes.count, 2)
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Performance Tests
    
    func testPerformanceAddingManyNotes() {
        measure {
            for i in 0..<100 {
                noteManager.addNote(title: "Note " + String(i), content: "Content " + String(i))
            }
        }
    }

    func testPerformanceUpdatingNotes() {
        // Add notes first
        for i in 0..<100 {
            noteManager.addNote(title: "Note " + String(i), content: "Content " + String(i))
        }
        
        measure {
            for i in 0..<100 {
                if let note = noteManager.notes.first(where: { $0.title == "Note " + String(i) }) {
                    noteManager.updateNote(note, newContent: "Updated " + String(i))
                }
            }
        }
    }
}
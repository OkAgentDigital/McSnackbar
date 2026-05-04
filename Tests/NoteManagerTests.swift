// NoteManagerTests.swift
// SnackbarTests
//
// Created by DevStudio Integration
//

import XCTest
@testable import SnackbarCore

class NoteManagerTests: XCTestCase {

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
        // updatedAt should be >= createdAt after update
        XCTAssertGreaterThanOrEqual(note.updatedAt, note.createdAt)
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
}

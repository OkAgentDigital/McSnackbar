// Note.swift
// Snackbar
//
// Created by DevStudio Integration
//

import Foundation

public struct Note: Identifiable, Codable {
    public let id: UUID
    public var title: String
    public var content: String
    public var createdAt: Date
    public var updatedAt: Date
    public var tags: [String]
    public var isSynced: Bool

    public init(id: UUID = UUID(), title: String, content: String, createdAt: Date = Date(), updatedAt: Date = Date(), tags: [String] = [], isSynced: Bool = false) {
        self.id = id
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.tags = tags
        self.isSynced = isSynced
    }

    public mutating func updateContent(_ newContent: String) {
        self.content = newContent
        self.updatedAt = Date()
    }

    public mutating func addTag(_ tag: String) {
        if !tags.contains(tag) {
            tags.append(tag)
        }
    }

    public mutating func markAsSynced() {
        self.isSynced = true
    }
}

extension Note {
    public static func example() -> Note {
        return Note(
            title: "Example Note",
            content: "This is an example note for testing.",
            tags: ["example", "test"]
        )
    }
}
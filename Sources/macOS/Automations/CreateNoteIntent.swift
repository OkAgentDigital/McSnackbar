// CreateNoteIntent.swift
// Snackbar
//
// Created by DevStudio Integration
//

import AppIntents
import SnackbarCore

@available(macOS 13.0, *)
struct CreateNoteIntent: AppIntent {
    static var title: LocalizedStringResource = "Create Note"
    static var description = IntentDescription("Creates a new note in Snackbar.")

    @Parameter(title: "Note Title")
    var title: String

    @Parameter(title: "Note Content")
    var content: String

    @Parameter(title: "Tags", default: [])
    var tags: [String]

    static var parameterSummary: some ParameterSummary {
        Summary("Create note")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        // Create the note using NoteManager
        NoteManager.shared.addNote(title: title, content: content, tags: tags)

        // Return the created note ID
        guard let createdNote = NoteManager.shared.notes.last else {
            throw NSError(domain: "Snackbar", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create note"])
        }

        return .result(value: createdNote.id.uuidString)
    }
}
// SyncNotesIntent.swift
// Snackbar
//
// Created by DevStudio Integration
//

import AppIntents
import SnackbarCore

@available(macOS 13.0, *)
struct SyncNotesIntent: AppIntent {
    static var title: LocalizedStringResource = "Sync Notes with iCloud"
    static var description = IntentDescription("Syncs all notes with iCloud.")

    static var parameterSummary: some ParameterSummary {
        Summary("Sync all notes with iCloud")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        let syncMonitor = SyncStatusMonitor.shared

        // Check if we can sync
        guard syncMonitor.isOnline else {
            throw NSError(domain: "Snackbar", code: -1, userInfo: [NSLocalizedDescriptionKey: "Offline - cannot sync"])
        }

        guard syncMonitor.iCloudAvailable else {
            throw NSError(domain: "Snackbar", code: -1, userInfo: [NSLocalizedDescriptionKey: "iCloud not available"])
        }

        // Force sync
        let success: Bool = try await withCheckedThrowingContinuation { continuation in
            syncMonitor.forceSync { result in
                switch result {
                case .success:
                    continuation.resume(returning: true)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
        
        return .result(value: success)
    }
}
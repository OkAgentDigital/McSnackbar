// NoteManager.swift
// Snackbar
//
// Created by DevStudio Integration
//

import Foundation
import Combine

public class NoteManager: ObservableObject {
    public static let shared = NoteManager()
    
    @Published public private(set) var notes: [Note] = []
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var lastSyncDate: Date?
    
    private let localStorage = LocalNoteStorage()
    private let iCloudManager = iCloudSyncManager.shared
    private let syncMonitor = SyncStatusMonitor.shared
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        loadNotes()
        setupObservers()
    }
    
    private func setupObservers() {
        // Monitor network and iCloud status changes
        syncMonitor.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleSyncStatusChange()
            }
            .store(in: &cancellables)
    }
    
    private func handleSyncStatusChange() {
        if syncMonitor.isOnline && syncMonitor.iCloudAvailable {
            // Attempt to sync any pending changes
            syncAllNotesToiCloud()
        }
    }

    // MARK: - Public Methods
    
    public func loadNotes() {
        isLoading = true
        
        // Load from local storage first
        localStorage.loadNotes { [weak self] localNotes in
            guard let self = self else { return }
            
            self.notes = localNotes
            self.isLoading = false
            
            // Then check iCloud status
            self.checkiCloudStatus()
        }
    }

    public func addNote(title: String, content: String, tags: [String] = []) {
        var newNote = Note(title: title, content: content, tags: tags)
        
        // Only mark as synced if we can sync immediately
        if syncMonitor.isOnline && syncMonitor.iCloudAvailable {
            newNote.markAsSynced()
        }
        
        notes.append(newNote)
        saveNotes()
        
        // Sync to iCloud if possible, otherwise add to pending
        if syncMonitor.isOnline && syncMonitor.iCloudAvailable {
            syncNoteToiCloud(newNote)
        } else {
            syncMonitor.addPendingNote(newNote)
        }
    }

    public func updateNote(_ note: Note, newContent: String) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            var updatedNote = notes[index]
            updatedNote.updateContent(newContent)
            
            // Only mark as synced if we can sync immediately
            if syncMonitor.isOnline && syncMonitor.iCloudAvailable {
                updatedNote.markAsSynced()
            }
            
            notes[index] = updatedNote
            saveNotes()
            
            // Sync to iCloud if possible, otherwise add to pending
            if syncMonitor.isOnline && syncMonitor.iCloudAvailable {
                syncNoteToiCloud(updatedNote)
            } else {
                syncMonitor.addPendingNote(updatedNote)
            }
        }
    }

    public func deleteNote(_ note: Note) {
        notes.removeAll { $0.id == note.id }
        saveNotes()
        
        // Delete from iCloud
        deleteNoteFromiCloud(note)
    }

    public func syncAllNotesToiCloud(completion: ((Result<Bool, Error>) -> Void)? = nil) {
        guard !notes.isEmpty else {
            completion?(.success(true))
            return
        }
        
        // Check iCloud account status first
        iCloudManager.checkAccountStatus { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let status):
                guard status == .available else {
                    completion?(.failure(NSError(domain: "iCloudSync", code: -1, userInfo: [NSLocalizedDescriptionKey: "iCloud not available"])))
                    return
                }
                
                // Setup zone if needed
                self.iCloudManager.setupZone { zoneResult in
                    switch zoneResult {
                    case .success:
                        // Sync all notes
                        let dispatchGroup = DispatchGroup()
                        var syncError: Error?
                        
                        for note in self.notes {
                            dispatchGroup.enter()
                            self.iCloudManager.syncNote(note) { result in
                                if case .failure(let error) = result {
                                    syncError = error
                                }
                                dispatchGroup.leave()
                            }
                        }
                        
                        dispatchGroup.notify(queue: .main) {
                            if let error = syncError {
                                completion?(.failure(error))
                            } else {
                                self.lastSyncDate = Date()
                                completion?(.success(true))
                            }
                        }
                    
                    case .failure(let error):
                        completion?(.failure(error))
                    }
                }
            
            case .failure(let error):
                completion?(.failure(error))
            }
        }
    }

    public func fetchNotesFromiCloud(completion: ((Result<[Note], Error>) -> Void)? = nil) {
        iCloudManager.checkAccountStatus { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let status):
                guard status == .available else {
                    completion?(.failure(NSError(domain: "iCloudSync", code: -1, userInfo: [NSLocalizedDescriptionKey: "iCloud not available"])))
                    return
                }
                
                self.iCloudManager.fetchNotes { result in
                    switch result {
                    case .success(let iCloudNotes):
                        // Merge with local notes
                        self.mergeiCloudNotes(with: iCloudNotes)
                        completion?(.success(iCloudNotes))
                    
                    case .failure(let error):
                        completion?(.failure(error))
                    }
                }
            
            case .failure(let error):
                completion?(.failure(error))
            }
        }
    }

    // MARK: - Private Methods
    
    private func saveNotes() {
        localStorage.saveNotes(notes)
    }

    private func checkiCloudStatus() {
        iCloudManager.checkAccountStatus { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let status):
                if status == .available {
                    // Fetch notes from iCloud
                    self.fetchNotesFromiCloud()
                }
            
            case .failure:
                break // iCloud not available
            }
        }
    }

    private func syncNoteToiCloud(_ note: Note) {
        iCloudManager.checkAccountStatus { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let status):
                guard status == .available else { return }
                
                self.iCloudManager.setupZone { zoneResult in
                    if case .success = zoneResult {
                        self.iCloudManager.syncNote(note) { _ in }
                    }
                }
            
            case .failure:
                break
            }
        }
    }

    private func deleteNoteFromiCloud(_ note: Note) {
        // Note: CloudKit doesn't have a direct delete by query API
        // We would need to fetch the record ID first, then delete
        // This is a simplified version - in production, you'd need to:
        // 1. Query for the record with the note ID
        // 2. Get the record ID
        // 3. Delete the record
        
        iCloudManager.checkAccountStatus { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let status):
                guard status == .available else { return }
                
                self.iCloudManager.setupZone { zoneResult in
                    if case .success = zoneResult {
                        let recordID = CKRecord.ID(recordName: note.id.uuidString, zoneID: self.iCloudManager.zoneID)
                        let operation = CKModifyRecordsOperation(
                            recordsToSave: nil,
                            recordIDsToDelete: [recordID]
                        )
                        
                        operation.modifyRecordsCompletionBlock = { _, _, error in
                            if let error = error {
                                print("Error deleting note from iCloud: " + error.localizedDescription)
                            }
                        }
                        
                        self.iCloudManager.privateDatabase.add(operation)
                    }
                }
            
            case .failure:
                break
            }
        }
    }

    private func mergeiCloudNotes(with iCloudNotes: [Note]) {
        var mergedNotes = notes
        
        // Add or update notes from iCloud
        for iCloudNote in iCloudNotes {
            if let index = mergedNotes.firstIndex(where: { $0.id == iCloudNote.id }) {
                // Update existing note if iCloud version is newer
                if iCloudNote.updatedAt > mergedNotes[index].updatedAt {
                    var updatedNote = iCloudNote
                    updatedNote.markAsSynced()
                    mergedNotes[index] = updatedNote
                }
            } else {
                // Add new note from iCloud
                var newNote = iCloudNote
                newNote.markAsSynced()
                mergedNotes.append(newNote)
            }
        }
        
        // Remove notes that exist locally but not in iCloud (if they were deleted in iCloud)
        let iCloudNoteIDs = Set(iCloudNotes.map { $0.id })
        mergedNotes = mergedNotes.filter { note in
            // Keep local-only notes that haven't been synced yet
            if !note.isSynced {
                return true
            }
            // Keep notes that exist in iCloud
            return iCloudNoteIDs.contains(note.id)
        }
        
        notes = mergedNotes
        saveNotes()
    }
}

// MARK: - Local Storage Helper

private class LocalNoteStorage {
    private let storageURL: URL
    
    init() {
        let fileManager = FileManager.default
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let bundleID = Bundle.main.bundleIdentifier ?? "com.udos.Snackbar"
        let appDirectory = appSupportURL.appendingPathComponent(bundleID, isDirectory: true)
        
        storageURL = appDirectory.appendingPathComponent("notes.json", isDirectory: false)
        
        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: appDirectory.path) {
            try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        }
    }
    
    func saveNotes(_ notes: [Note]) {
        do {
            let data = try JSONEncoder().encode(notes)
            try data.write(to: storageURL, options: [.atomicWrite])
        } catch {
            print("Error saving notes: " + error.localizedDescription)
        }
    }
    
    func loadNotes(completion: @escaping ([Note]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                let data = try Data(contentsOf: self.storageURL)
                let notes = try JSONDecoder().decode([Note].self, from: data)
                DispatchQueue.main.async {
                    completion(notes)
                }
            } catch {
                // Return empty array if file doesn't exist or can't be decoded
                DispatchQueue.main.async {
                    completion([])
                }
            }
        }
    }
}
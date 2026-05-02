// iCloudSyncManager.swift
// Snackbar
//
// Created by DevStudio Integration
//

import Foundation
import CloudKit

public class iCloudSyncManager {
    public static let shared = iCloudSyncManager()
    
    public let container: CKContainer
    public let privateDatabase: CKDatabase
    public let zoneID: CKRecordZone.ID
    
    public init() {
        container = CKContainer(identifier: "iCloud.com.udos.Snackbar")
        privateDatabase = container.privateCloudDatabase
        zoneID = CKRecordZone.ID(zoneName: "SnackbarZone", ownerName: CKCurrentUserDefaultName)
    }

    // MARK: - Zone Management
    public func setupZone(completion: @escaping (Result<CKRecordZone, Error>) -> Void) {
        let zone = CKRecordZone(zoneID: zoneID)
        
        privateDatabase.save(zone) { savedZone, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            if let savedZone = savedZone {
                completion(.success(savedZone))
            } else {
                completion(.failure(NSError(domain: "iCloudSync", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to save zone"])))
            }
        }
    }

    // MARK: - Note Sync
    public func syncNote(_ note: Note, completion: @escaping (Result<CKRecord, Error>) -> Void) {
        let recordID = CKRecord.ID(recordName: note.id.uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: "Note", recordID: recordID)
        
        record["title"] = note.title as CKRecordValue
        record["content"] = note.content as CKRecordValue
        record["createdAt"] = note.createdAt as CKRecordValue
        record["updatedAt"] = note.updatedAt as CKRecordValue
        record["tags"] = note.tags as CKRecordValue
        record["isSynced"] = note.isSynced as CKRecordValue
        
        privateDatabase.save(record) { savedRecord, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            if let savedRecord = savedRecord {
                completion(.success(savedRecord))
            } else {
                completion(.failure(NSError(domain: "iCloudSync", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to save note"])))
            }
        }
    }

    public func fetchNotes(completion: @escaping (Result<[Note], Error>) -> Void) {
        let query = CKQuery(recordType: "Note", predicate: NSPredicate(value: true))
        
        privateDatabase.perform(query, inZoneWith: zoneID) { records, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            let notes = records?.compactMap { record -> Note? in
                guard let title = record["title"] as? String,
                      let content = record["content"] as? String,
                      let createdAt = record["createdAt"] as? Date,
                      let updatedAt = record["updatedAt"] as? Date,
                      let tags = record["tags"] as? [String],
                      let isSynced = record["isSynced"] as? Bool,
                      let id = UUID(uuidString: record.recordID.recordName) else {
                    return nil
                }
                
                return Note(
                    id: id,
                    title: title,
                    content: content,
                    createdAt: createdAt,
                    updatedAt: updatedAt,
                    tags: tags,
                    isSynced: isSynced
                )
            } ?? []
            
            completion(.success(notes))
        }
    }

    // MARK: - Account Status
    public func checkAccountStatus(completion: @escaping (Result<CKAccountStatus, Error>) -> Void) {
        container.accountStatus { status, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            completion(.success(status))
        }
    }
}
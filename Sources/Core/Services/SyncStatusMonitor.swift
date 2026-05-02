// SyncStatusMonitor.swift
// Snackbar
//
// Created by DevStudio Integration
//

import Foundation
import Combine
import Network

public class SyncStatusMonitor: ObservableObject {
    public static let shared = SyncStatusMonitor()
    
    @Published public private(set) var isOnline: Bool = true
    @Published public private(set) var iCloudAvailable: Bool = false
    @Published public private(set) var hasPendingChanges: Bool = false
    
    private let networkMonitor = NWPathMonitor()
    private let iCloudManager = iCloudSyncManager.shared
    private var pendingNotes: [Note] = []
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        setupNetworkMonitoring()
        checkiCloudStatus()
    }

    // MARK: - Network Monitoring
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isOnline = path.status == .satisfied
                
                if self?.isOnline == true {
                    self?.attemptSyncPendingChanges()
                }
            }
        }
        
        let queue = DispatchQueue(label: "NetworkMonitor")
        networkMonitor.start(queue: queue)
    }

    // MARK: - iCloud Status
    
    public func checkiCloudStatus() {
        iCloudManager.checkAccountStatus { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let status):
                    self?.iCloudAvailable = status == .available
                    
                    if self?.iCloudAvailable == true {
                        self?.attemptSyncPendingChanges()
                    }
                
                case .failure:
                    self?.iCloudAvailable = false
                }
            }
        }
    }

    // MARK: - Pending Changes Management
    
    public func addPendingNote(_ note: Note) {
        if !pendingNotes.contains(where: { $0.id == note.id }) {
            pendingNotes.append(note)
            hasPendingChanges = true
        }
    }

    public func removePendingNote(_ note: Note) {
        pendingNotes.removeAll { $0.id == note.id }
        hasPendingChanges = !pendingNotes.isEmpty
    }

    public func getPendingNotes() -> [Note] {
        return pendingNotes
    }

    // MARK: - Sync Attempts
    
    private func attemptSyncPendingChanges() {
        guard isOnline && iCloudAvailable && hasPendingChanges else {
            return
        }
        
        hasPendingChanges = false
        let notesToSync = pendingNotes
        pendingNotes = []
        
        iCloudManager.setupZone { [weak self] zoneResult in
            guard let self = self else { return }
            
            if case .success = zoneResult {
                let dispatchGroup = DispatchGroup()
                
                for note in notesToSync {
                    dispatchGroup.enter()
                    self.iCloudManager.syncNote(note) { result in
                        if case .failure(let error) = result {
                            // If sync fails, add back to pending
                            self.addPendingNote(note)
                            print("Error syncing note: " + error.localizedDescription)
                        }
                        dispatchGroup.leave()
                    }
                }
            } else {
                // If zone setup fails, restore pending notes
                self.pendingNotes = notesToSync
                self.hasPendingChanges = true
            }
        }
    }

    // MARK: - Manual Sync Trigger
    
    public func forceSync(completion: ((Result<Bool, Error>) -> Void)? = nil) {
        guard isOnline else {
            completion?(.failure(NSError(domain: "Sync", code: -1, userInfo: [NSLocalizedDescriptionKey: "Offline"])))
            return
        }
        
        checkiCloudStatus()
        
        guard iCloudAvailable else {
            completion?(.failure(NSError(domain: "Sync", code: -1, userInfo: [NSLocalizedDescriptionKey: "iCloud not available"])))
            return
        }
        
        attemptSyncPendingChanges()
        completion?(.success(true))
    }
}
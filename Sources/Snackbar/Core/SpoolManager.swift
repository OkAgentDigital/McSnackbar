import Foundation

/// Manages the immutable, append-only spool ledger at
/// ~/Library/Application Support/Snackbar/replies.jsonl
class SpoolManager: ObservableObject {
    static let shared = SpoolManager()
    
    @Published private(set) var entryCount: Int = 0
    @Published private(set) var lastEntry: SpoolEntry?
    
    private let fileManager = FileManager.default
    private let spoolURL: URL
    private let queue = DispatchQueue(label: "com.snackbar.spool", qos: .utility)
    private var fileHandle: FileHandle?
    
    private init() {
        let supportDir = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Snackbar")
        spoolURL = supportDir.appendingPathComponent("replies.jsonl")
        setupSpool()
    }
    
    // MARK: - Setup
    
    private func setupSpool() {
        queue.sync {
            let dir = spoolURL.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: dir.path) {
                try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            }
            if !fileManager.fileExists(atPath: spoolURL.path) {
                fileManager.createFile(atPath: spoolURL.path, contents: nil)
            }
            do {
                fileHandle = try FileHandle(forWritingTo: spoolURL)
                fileHandle?.seekToEndOfFile()
                // Count existing entries
                if let data = try? Data(contentsOf: spoolURL) {
                    let lines = data.split(separator: UInt8(ascii: "\n"))
                    entryCount = lines.count
                }
            } catch {
                print("❌ SpoolManager: Failed to open spool file: \(error)")
            }
        }
    }
    
    // MARK: - Write
    
    /// Append an entry to the spool. Thread-safe.
    func append(_ entry: SpoolEntry) {
        queue.async { [weak self] in
            guard let self = self else { return }
            do {
                var jsonData = try JSONEncoder().encode(entry)
                jsonData.append(0x0A) // newline
                
                if let handle = self.fileHandle {
                    try handle.seekToEnd()
                    try handle.write(contentsOf: jsonData)
                    try handle.synchronize()
                }
                
                DispatchQueue.main.async {
                    self.entryCount += 1
                    self.lastEntry = entry
                }
            } catch {
                print("❌ SpoolManager: Failed to write entry: \(error)")
            }
        }
    }
    
    // MARK: - Read
    
    /// Read recent entries from the spool.
    func readRecent(limit: Int = 10, tag: String? = nil) -> [SpoolEntry] {
        guard let data = try? Data(contentsOf: spoolURL) else { return [] }
        let lines = data.split(separator: UInt8(ascii: "\n"))
        let decoder = JSONDecoder()
        var entries: [SpoolEntry] = []
        
        for lineData in lines.reversed() {
            guard entries.count < limit else { break }
            if let entry = try? decoder.decode(SpoolEntry.self, from: lineData) {
                if let tag = tag, !entry.tags.contains(tag) { continue }
                entries.append(entry)
            }
        }
        return entries
    }
    
    /// Search spool entries by query string.
    func search(query: String, since: String? = nil) -> [SpoolEntry] {
        guard let data = try? Data(contentsOf: spoolURL) else { return [] }
        let lines = data.split(separator: UInt8(ascii: "\n"))
        let decoder = JSONDecoder()
        var entries: [SpoolEntry] = []
        let lowerQuery = query.lowercased()
        
        for lineData in lines.reversed() {
            guard let entry = try? decoder.decode(SpoolEntry.self, from: lineData) else { continue }
            
            // Filter by date if since provided
            if let since = since, entry.timestamp < since { continue }
            
            // Search in output, prompt, tags, snack name
            let searchable = "\(entry.output) \(entry.prompt) \(entry.tags.joined()) \(entry.metadata.snack_name)".lowercased()
            if searchable.contains(lowerQuery) {
                entries.append(entry)
            }
        }
        return entries
    }
    
    /// Get aggregated statistics for a snack.
    func stats(snackId: String, lastHours: Int = 24) -> [String: Any] {
        guard let data = try? Data(contentsOf: spoolURL) else { return [:] }
        let lines = data.split(separator: UInt8(ascii: "\n"))
        let decoder = JSONDecoder()
        
        let cutoff = Date().addingTimeInterval(-Double(lastHours * 3600))
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        var totalRuns = 0
        var successRuns = 0
        var totalDuration: Int = 0
        
        for lineData in lines.reversed() {
            guard let entry = try? decoder.decode(SpoolEntry.self, from: lineData) else { continue }
            guard entry.metadata.snack_id == snackId else { continue }
            
            // Check time cutoff
            if let entryDate = formatter.date(from: entry.timestamp), entryDate < cutoff { break }
            
            totalRuns += 1
            if entry.metadata.exit_code == 0 { successRuns += 1 }
            totalDuration += entry.metadata.duration_ms
        }
        
        return [
            "snack_id": snackId,
            "total_runs": totalRuns,
            "success_runs": successRuns,
            "failure_runs": totalRuns - successRuns,
            "avg_duration_ms": totalRuns > 0 ? totalDuration / totalRuns : 0,
            "period_hours": lastHours
        ]
    }
    
    // MARK: - Cleanup
    
    deinit {
        try? fileHandle?.close()
    }
}

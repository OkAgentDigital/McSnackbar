import Foundation

struct SpoolEntry: Identifiable, Codable {
    let id: String
    let timestamp: String
    let snack: String
    let status: String
    let output: String
    let durationMs: Int
    
    init(snack: String, status: String, output: String, durationMs: Int) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.timestamp = formatter.string(from: Date())
        self.id = "\(snack)_\(timestamp.replacingOccurrences(of: "[-:T.Z]", with: "", options: .regularExpression))"
        self.snack = snack
        self.status = status
        self.output = output
        self.durationMs = durationMs
    }
}

@MainActor
class SpoolWriter {
    static let shared = SpoolWriter()
    
    private var spoolURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let snackbarDir = appSupport.appendingPathComponent("Snackbar", isDirectory: true)
        try? FileManager.default.createDirectory(at: snackbarDir, withIntermediateDirectories: true)
        return snackbarDir.appendingPathComponent("replies.jsonl")
    }
    
    func log(entry: SpoolEntry) {
        guard let data = try? JSONEncoder().encode(entry),
              let line = String(data: data, encoding: .utf8)?.appending("\n") else { return }
        
        if FileManager.default.fileExists(atPath: spoolURL.path) {
            if let fileHandle = try? FileHandle(forWritingTo: spoolURL) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(line.data(using: .utf8)!)
                fileHandle.closeFile()
            }
        } else {
            try? line.write(to: spoolURL, atomically: true, encoding: .utf8)
        }
    }
    
    func readAll() -> [SpoolEntry] {
        guard let data = try? Data(contentsOf: spoolURL),
              let content = String(data: data, encoding: .utf8) else { return [] }
        
        return content
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
            .compactMap { line in
                guard let data = line.data(using: .utf8) else { return nil }
                return try? JSONDecoder().decode(SpoolEntry.self, from: data)
            }
    }
    
    func clear() {
        try? "".write(to: spoolURL, atomically: true, encoding: .utf8)
    }
    
    func export(to url: URL) {
        try? FileManager.default.copyItem(at: spoolURL, to: url)
    }
}

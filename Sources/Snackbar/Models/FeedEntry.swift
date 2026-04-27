import Foundation

struct FeedEntry: Codable, Identifiable {
    let id: String
    let timestamp: Date
    let snackId: String
    let snackName: String
    let success: Bool
    let output: String?
    let metadata: [String: String]
    
    init(id: String = UUID().uuidString,
         timestamp: Date = Date(),
         snackId: String,
         snackName: String,
         success: Bool,
         output: String? = nil,
         metadata: [String: String] = [:]) {
        self.id = id
        self.timestamp = timestamp
        self.snackId = snackId
        self.snackName = snackName
        self.success = success
        self.output = output
        self.metadata = metadata
    }
}
import Foundation

/// A single entry in the immutable spool ledger (replies.jsonl)
struct SpoolEntry: Codable, Identifiable {
    let reply_id: String
    let thread_id: String
    let timestamp: String
    let source: String
    let user_id: String
    let compartment: String
    let prompt: String
    let output: String
    let tags: [String]
    let metadata: SpoolMetadata
    
    var id: String { reply_id }
    
    static func currentTimestamp() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date())
    }
    
    static func generateReplyId(snackId: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let dateStr = formatter.string(from: Date())
        return "snack_\(snackId.replacingOccurrences(of: "-", with: "_"))_\(dateStr)"
    }
    
    static func generateThreadId(snackName: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let dateStr = formatter.string(from: Date())
        return "snack_\(snackName.lowercased())_\(dateStr)"
    }
}

/// Metadata embedded in each spool entry
struct SpoolMetadata: Codable {
    let event_type: String
    let snack_id: String
    let snack_name: String
    let runtime: String
    let duration_ms: Int
    let exit_code: Int32
    let stdout: String?
    let stderr: String?
    let inputs: [String: String]?
    let outputs: [String: AnyCodable]?
    let nugget_pointer: String?
    
    enum CodingKeys: String, CodingKey {
        case event_type, snack_id, snack_name, runtime, duration_ms, exit_code
        case stdout, stderr, inputs, outputs, nugget_pointer
    }
    
    init(event_type: String = "snack_execution",
         snack_id: String,
         snack_name: String,
         runtime: String,
         duration_ms: Int,
         exit_code: Int32,
         stdout: String? = nil,
         stderr: String? = nil,
         inputs: [String: String]? = nil,
         outputs: [String: AnyCodable]? = nil,
         nugget_pointer: String? = nil) {
        self.event_type = event_type
        self.snack_id = snack_id
        self.snack_name = snack_name
        self.runtime = runtime
        self.duration_ms = duration_ms
        self.exit_code = exit_code
        self.stdout = stdout
        self.stderr = stderr
        self.inputs = inputs
        self.outputs = outputs
        self.nugget_pointer = nugget_pointer
    }
}

/// Type-erased Codable wrapper for heterogeneous dictionaries
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) { self.value = value }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) { value = intVal }
        else if let doubleVal = try? container.decode(Double.self) { value = doubleVal }
        else if let boolVal = try? container.decode(Bool.self) { value = boolVal }
        else if let stringVal = try? container.decode(String.self) { value = stringVal }
        else if let arrayVal = try? container.decode([AnyCodable].self) { value = arrayVal.map { $0.value } }
        else if let dictVal = try? container.decode([String: AnyCodable].self) { value = dictVal.mapValues { $0.value } }
        else { value = "null" }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let intVal = value as? Int { try container.encode(intVal) }
        else if let doubleVal = value as? Double { try container.encode(doubleVal) }
        else if let boolVal = value as? Bool { try container.encode(boolVal) }
        else if let stringVal = value as? String { try container.encode(stringVal) }
        else if let arrayVal = value as? [Any] { try container.encode(arrayVal.map { AnyCodable($0) }) }
        else if let dictVal = value as? [String: Any] { try container.encode(dictVal.mapValues { AnyCodable($0) }) }
        else { try container.encodeNil() }
    }
}

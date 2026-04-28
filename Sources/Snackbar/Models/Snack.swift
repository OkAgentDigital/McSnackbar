import Foundation

struct Snack: Identifiable, Codable {
    let id: String
    let name: String
    let emoji: String
    let code: String
    let runtime: String // "appleScript" or "shell"
    let categoryId: String
    var schedule: Schedule?
    var isEnabled: Bool
    var createdAt: Date
    var updatedAt: Date
    let description: String?
    
    init(id: String, name: String, emoji: String, code: String, runtime: String, categoryId: String, schedule: Schedule? = nil, isEnabled: Bool = true, description: String? = nil) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.code = code
        self.runtime = runtime
        self.categoryId = categoryId
        self.schedule = schedule
        self.isEnabled = isEnabled
        self.createdAt = Date()
        self.updatedAt = Date()
        self.description = description
    }
    
    // Custom initializer for backward compatibility with JSON files
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        emoji = try container.decode(String.self, forKey: .emoji)
        code = try container.decode(String.self, forKey: .code)
        runtime = try container.decode(String.self, forKey: .runtime)
        categoryId = try container.decode(String.self, forKey: .categoryId)
        
        // Optional fields with defaults
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        description = try container.decodeIfPresent(String.self, forKey: .description)
        schedule = try container.decodeIfPresent(Schedule.self, forKey: .schedule)
        
        // Generate current timestamps if not present
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }
    
    var category: Category? {
        return Category.categoryById(categoryId)
    }
}
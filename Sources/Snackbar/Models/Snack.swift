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
    
    init(id: String, name: String, emoji: String, code: String, runtime: String, categoryId: String, schedule: Schedule? = nil, isEnabled: Bool = true) {
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
    }
    
    var category: Category? {
        return Category.categoryById(categoryId)
    }
}
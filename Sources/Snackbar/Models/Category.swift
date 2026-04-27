import Foundation

struct Category: Identifiable, Codable {
    let id: String
    let name: String
    let emoji: String
    let color: String
    
    static let allCategories: [Category] = [
        Category(id: "productivity", name: "Productivity", emoji: "🚀", color: "#FF6B6B"),
        Category(id: "communication", name: "Communication", emoji: "💬", color: "#4ECDC4"),
        Category(id: "organization", name: "Organization", emoji: "📂", color: "#45B7D1"),
        Category(id: "system", name: "System", emoji: "⚙️", color: "#96CEB4"),
        Category(id: "custom", name: "Custom", emoji: "✨", color: "#FFEAA7")
    ]
    
    static func categoryById(_ id: String) -> Category? {
        return allCategories.first { $0.id == id }
    }
}
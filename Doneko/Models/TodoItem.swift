import Foundation

struct TodoItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var createdAt: Date
    var completedAt: Date?
    var isPriority = false
    var dueDate: Date?
    var order: Int
}

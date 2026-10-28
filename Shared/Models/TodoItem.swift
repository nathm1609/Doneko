import Foundation

struct TodoItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var createdAt: Date
    var completedAt: Date?
    var isPriority = false
    var dueDate: Date?
    var order: Int
    /// Dernière modification, pour la fusion entre appareils (absente des fichiers de Doneko 1.1).
    var updatedAt: Date?
    /// Tâche supprimée : gardée 30 jours, pour que la suppression l'emporte aussi sur l'autre appareil.
    var deletedAt: Date?

    /// À la fusion, la version la plus récente de la tâche gagne.
    var lastChange: Date { updatedAt ?? completedAt ?? createdAt }
}

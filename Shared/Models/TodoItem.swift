import Foundation

/// Élément synchronisé entre appareils (tâche, dossier) : à la fusion, sa version la plus récente gagne, et une
/// suppression reste enregistrée 30 jours (`deletedAt`) pour l'emporter aussi sur l'autre appareil.
protocol Syncable: Identifiable, Codable, Equatable where ID == UUID {
    var updatedAt: Date? { get set }
    var deletedAt: Date? { get set }
    var lastChange: Date { get }
}

struct TodoItem: Syncable {
    var id = UUID()
    var title: String
    var createdAt: Date
    var completedAt: Date?
    var isPriority = false
    var dueDate: Date?
    var order: Int
    /// Dossier où la tâche est rangée ; `nil`, ou dossier supprimé entre-temps : seulement dans « Tout ».
    var folderID: UUID?
    /// Dernière modification, pour la fusion entre appareils (absente des fichiers de Doneko 1.1).
    var updatedAt: Date?
    /// Tâche supprimée : gardée 30 jours, pour que la suppression l'emporte aussi sur l'autre appareil.
    var deletedAt: Date?

    /// À la fusion, la version la plus récente de la tâche gagne.
    var lastChange: Date { updatedAt ?? completedAt ?? createdAt }
}

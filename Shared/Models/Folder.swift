import Foundation

/// Dossier où ranger des tâches : un nom et une place dans la barre, ni couleur ni emoji (DESIGN.md).
struct Folder: Syncable {
    var id = UUID()
    var name: String
    var order: Int
    var updatedAt: Date?
    var deletedAt: Date?

    var lastChange: Date { updatedAt ?? .distantPast }
}

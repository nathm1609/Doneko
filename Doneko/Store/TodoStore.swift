import Foundation
import Observation

@Observable
final class TodoStore {
    private(set) var items: [TodoItem]
    /// Versions précédentes des tâches touchées par complete / delete / edit, la plus récente en dernier.
    private var undoStack: [TodoItem] = []
    @ObservationIgnored private let clock: Clock
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let persistence: Persistence?

    /// Sans `persistence`, la liste reste en mémoire (tests).
    init(persistence: Persistence? = nil, clock: Clock = SystemClock(), calendar: Calendar = .current) {
        self.items = persistence?.load() ?? []
        self.persistence = persistence
        self.clock = clock
        self.calendar = calendar
    }

    var todos: [TodoItem] {
        items.filter { $0.completedAt == nil }.sorted { $0.order < $1.order }
    }

    /// Tâches faites, la plus récente en premier.
    var done: [TodoItem] {
        items.filter { $0.completedAt != nil }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    var canUndo: Bool { !undoStack.isEmpty }

    /// Info-bulle et libellé VoiceOver de l'icône : « Doneko — 3 tâches sur la table ».
    var summary: String {
        switch todos.count {
        case 0: "Doneko — plus rien sur la table"
        case 1: "Doneko — 1 tâche sur la table"
        case let count: "Doneko — \(count) tâches sur la table"
        }
    }

    func add(_ title: String) {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let order = (items.map(\.order).max() ?? -1) + 1
        items.append(TodoItem(title: title, createdAt: clock.now(), order: order))
        save()
    }

    func complete(_ id: TodoItem.ID) {
        guard let i = index(of: id), items[i].completedAt == nil else { return }
        undoStack.append(items[i])
        items[i].completedAt = clock.now()
        save()
    }

    func delete(_ id: TodoItem.ID) {
        guard let i = index(of: id) else { return }
        undoStack.append(items.remove(at: i))
        save()
    }

    func edit(_ id: TodoItem.ID, title: String) {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, let i = index(of: id), items[i].title != title else { return }
        undoStack.append(items[i])
        items[i].title = title
        save()
    }

    /// Remet la tâche dans l'état d'avant la dernière action (la réinsère si elle a été supprimée).
    func undo() {
        guard let previous = undoStack.popLast() else { return }
        if let i = index(of: previous.id) {
            items[i] = previous
        } else {
            items.append(previous)
        }
        save()
    }

    /// Vide « Tombé aujourd'hui » : retire les tâches faites avant le début de la journée.
    func purgeDone() {
        let startOfToday = calendar.startOfDay(for: clock.now())
        let purged = Set(items.filter { ($0.completedAt ?? .distantFuture) < startOfToday }.map(\.id))
        guard !purged.isEmpty else { return }
        items.removeAll { purged.contains($0.id) }
        // Une annulation ne doit ramener aucune version d'une tâche purgée.
        undoStack.removeAll { purged.contains($0.id) }
        save()
    }

    private func save() {
        do {
            try persistence?.save(items)
        } catch {
            NSLog("Doneko : sauvegarde impossible (\(error))")
        }
    }

    private func index(of id: TodoItem.ID) -> Int? {
        items.firstIndex { $0.id == id }
    }
}

import Foundation
import Observation

/// Export des tâches faites dans le dossier Obsidian choisi dans les réglages : une note par jour (`AAAA-MM-JJ.md`),
/// section « Fait avec Doneko ». Une tâche qui tombe y est ajoutée, une tâche décochée en est retirée ;
/// la purge quotidienne n'efface rien, et le reste de la note n'est jamais modifié. Au lancement, les tâches déjà faites
/// (sur l'iPhone, pendant que Doneko était quitté ici) sont exportées aussi : créer l'export avant la purge.
/// Toujours utilisé sur le fil principal (l'observation y renvoie), d'où `@unchecked Sendable`.
final class ObsidianExport: @unchecked Sendable {
    static let heading = "## Fait avec Doneko"

    private let store: TodoStore
    private let defaults: UserDefaults
    private let calendar: Calendar
    /// Tâches faites au dernier passage : la différence donne celles qui viennent de tomber ou de revenir.
    private var previousDone: [TodoItem] = []

    init(store: TodoStore, defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.store = store
        self.defaults = defaults
        self.calendar = calendar
        // Une ligne déjà présente dans la note n'est pas ajoutée une deuxième fois.
        sync()
        observe()
    }

    private func observe() {
        withObservationTracking {
            _ = store.done
        } onChange: { [weak self] in
            // Appelé juste avant la modification : on exporte une fois qu'elle est faite.
            DispatchQueue.main.async {
                self?.sync()
                self?.observe()
            }
        }
    }

    func sync() {
        let done = store.done
        let todoIDs = Set(store.todos.map(\.id))
        let previousIDs = Set(previousDone.map(\.id))
        let completed = done.filter { !previousIDs.contains($0.id) }
        let uncompleted = previousDone.filter { todoIDs.contains($0.id) }
        previousDone = done
        guard let folder = defaults.string(forKey: SettingsKey.obsidianFolder), !folder.isEmpty else { return }

        for day in Set((completed + uncompleted).compactMap(noteName)) {
            update(
                note: URL(fileURLWithPath: folder).appendingPathComponent("\(day).md"),
                // Dans l'ordre où elles sont tombées.
                ensuring: done.reversed().filter { noteName($0) == day }.map(\.title),
                removing: uncompleted.filter { noteName($0) == day }.map(\.title)
            )
        }
    }

    /// `2027-01-15` : jour où la tâche est tombée.
    private func noteName(_ item: TodoItem) -> String? {
        item.completedAt.map { date in
            let day = calendar.dateComponents([.year, .month, .day], from: date)
            return String(format: "%04d-%02d-%02d", day.year ?? 0, day.month ?? 0, day.day ?? 0)
        }
    }

    private func update(note url: URL, ensuring titles: [String], removing removed: [String]) {
        var text = ""
        if FileManager.default.fileExists(atPath: url.path) {
            // Note illisible : on n'y touche pas plutôt que de risquer d'écraser son contenu.
            guard let existing = try? String(contentsOf: url, encoding: .utf8) else {
                NSLog("Doneko : note Obsidian illisible, export ignoré (\(url.path))")
                return
            }
            text = existing
        }
        let merged = Self.merge(text, ensuring: titles, removing: removed)
        guard merged != text else { return }
        do {
            try merged.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            NSLog("Doneko : export Obsidian impossible (\(error))")
        }
    }

    /// `note` dont la section « Fait avec Doneko » contient une ligne par titre de `titles` (sans doublon en trop)
    /// et une ligne de moins par titre de `removed`. Section créée en fin de note si besoin ; le reste est intact.
    static func merge(_ note: String, ensuring titles: [String], removing removed: [String]) -> String {
        let line = { (title: String) in "- [x] \(title)" }
        var lines = note.components(separatedBy: "\n")
        guard let heading = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines) == Self.heading }) else {
            guard !titles.isEmpty else { return note }
            let separator = note.isEmpty ? "" : note.hasSuffix("\n") ? "\n" : "\n\n"
            return note + separator + ([Self.heading] + titles.map(line)).joined(separator: "\n") + "\n"
        }
        // La section s'arrête au titre suivant de niveau 1 ou 2.
        var end = lines[(heading + 1)...].firstIndex { $0.hasPrefix("# ") || $0.hasPrefix("## ") } ?? lines.count
        for title in removed {
            if let i = lines[(heading + 1)..<end].firstIndex(of: line(title)) {
                lines.remove(at: i)
                end -= 1
            }
        }
        var present = Array(lines[(heading + 1)..<end])
        var insertAt = (lines[(heading + 1)..<end].lastIndex { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? heading) + 1
        for title in titles {
            if let i = present.firstIndex(of: line(title)) {
                present.remove(at: i)
            } else {
                lines.insert(line(title), at: insertAt)
                insertAt += 1
            }
        }
        return lines.joined(separator: "\n")
    }
}

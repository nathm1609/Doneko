import Foundation
import Observation

@Observable
final class TodoStore {
    private(set) var items: [TodoItem]
    /// Versions précédentes des tâches touchées par complete / delete / edit, la plus récente en dernier.
    private var undoStack: [TodoItem] = []
    @ObservationIgnored private let clock: Clock
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private var persistence: Persistence?
    /// Début du jour en cours : sépare « Aujourd'hui » de « Plus tard ». Avancé par `refreshDay()`.
    private(set) var currentDay: Date

    /// Sans `persistence`, la liste reste en mémoire (tests).
    init(persistence: Persistence? = nil, clock: Clock = SystemClock(), calendar: Calendar = .current) {
        self.items = persistence?.load() ?? []
        self.persistence = persistence
        self.clock = clock
        self.calendar = calendar
        self.currentDay = calendar.startOfDay(for: clock.now())
    }

    /// Tâches à faire, dans l'ordre d'affichage : « Aujourd'hui » puis « Plus tard » (par date),
    /// les prioritaires en tête de chaque groupe, puis dans l'ordre choisi.
    var todos: [TodoItem] {
        items.filter { $0.completedAt == nil }.sorted { sortKey($0) < sortKey($1) }
    }

    /// Sans échéance, ou échéance atteinte ou dépassée.
    var today: [TodoItem] { todos.filter { !isLater($0) } }

    /// Échéance après aujourd'hui.
    var later: [TodoItem] { todos.filter(isLater) }

    /// Tâches faites, la plus récente en premier.
    var done: [TodoItem] {
        items.filter { $0.completedAt != nil }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    var canUndo: Bool { !undoStack.isEmpty }

    /// Info-bulle et libellé VoiceOver de l'icône : « Doneko — 3 tâches sur la table ».
    var summary: String {
        switch today.count {
        case 0: "Doneko — plus rien sur la table"
        case 1: "Doneko — 1 tâche sur la table"
        case let count: "Doneko — \(count) tâches sur la table"
        }
    }

    func add(_ input: String) {
        let (title, isPriority, dueDate) = parse(input)
        guard !title.isEmpty else { return }
        let order = (items.map(\.order).max() ?? -1) + 1
        items.append(TodoItem(title: title, createdAt: clock.now(), isPriority: isPriority, dueDate: dueDate, order: order))
        save()
    }

    func complete(_ id: TodoItem.ID) {
        guard let i = index(of: id), items[i].completedAt == nil else { return }
        undoStack.append(items[i])
        items[i].completedAt = clock.now()
        save()
    }

    /// Décoche une tâche faite : elle revient à sa place dans la liste.
    func uncomplete(_ id: TodoItem.ID) {
        guard let i = index(of: id), items[i].completedAt != nil else { return }
        undoStack.append(items[i])
        items[i].completedAt = nil
        save()
    }

    func delete(_ id: TodoItem.ID) {
        guard let i = index(of: id) else { return }
        undoStack.append(items.remove(at: i))
        save()
    }

    /// Le titre suit les mêmes règles qu'à l'ajout : « ! » final = prioritaire, son absence retire la priorité.
    /// Une date tapée remplace l'échéance ; sans date, elle reste la même.
    func edit(_ id: TodoItem.ID, title input: String) {
        let parsed = parse(input)
        guard !parsed.title.isEmpty, let i = index(of: id) else { return }
        let dueDate = parsed.dueDate ?? items[i].dueDate
        guard items[i].title != parsed.title || items[i].isPriority != parsed.isPriority || items[i].dueDate != dueDate
        else { return }
        undoStack.append(items[i])
        items[i].title = parsed.title
        items[i].isPriority = parsed.isPriority
        items[i].dueDate = dueDate
        save()
    }

    /// Fin de saisie : « ! » (un ou plusieurs) = prioritaire, et une date en français (« demain », « lundi »,
    /// « le 20 »), dans un ordre ou l'autre. Les deux sont retirés du titre.
    private func parse(_ input: String) -> (title: String, isPriority: Bool, dueDate: Date?) {
        var title = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let priorityFirst = Self.stripPriority(&title)
        let dueDate = stripDueDate(&title)
        let priorityLast = Self.stripPriority(&title)
        return (title, priorityFirst || priorityLast, dueDate)
    }

    private static func stripPriority(_ title: inout String) -> Bool {
        guard title.hasSuffix("!") else { return false }
        while title.hasSuffix("!") { title.removeLast() }
        title = title.trimmingCharacters(in: .whitespaces)
        return true
    }

    /// « aujourd'hui », « demain », « après-demain », un jour de la semaine (le prochain, jamais aujourd'hui)
    /// ou « le 20 » / « le 1er » (ce mois-ci, sinon le suivant), précédé ou non de « pour ».
    private func stripDueDate(_ title: inout String) -> Date? {
        let suffix = #/(?i)\s+(?:pour\s+)?(aujourd['’]hui|apr[eè]s-demain|demain|lundi|mardi|mercredi|jeudi|vendredi|samedi|dimanche|le\s+(\d{1,2})(?:er)?)$/#
        guard let match = title.firstMatch(of: suffix) else { return nil }
        let today = calendar.startOfDay(for: clock.now())
        let word = match.1.lowercased().replacingOccurrences(of: "è", with: "e").replacingOccurrences(of: "’", with: "'")
        let weekdays = ["dimanche", "lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi"]
        let dueDate: Date?
        switch word {
        case "aujourd'hui": dueDate = today
        case "demain": dueDate = calendar.date(byAdding: .day, value: 1, to: today)
        case "apres-demain": dueDate = calendar.date(byAdding: .day, value: 2, to: today)
        default:
            if let weekday = weekdays.firstIndex(of: word) {
                dueDate = calendar.nextDate(after: today, matching: DateComponents(weekday: weekday + 1), matchingPolicy: .nextTime)
            } else if let day = match.2.flatMap({ Int($0) }), (1...31).contains(day),
                      let yesterday = calendar.date(byAdding: .day, value: -1, to: today) {
                // Les mois sans ce jour (le 31) sont sautés.
                dueDate = calendar.nextDate(after: yesterday, matching: DateComponents(day: day), matchingPolicy: .strict)
            } else {
                dueDate = nil
            }
        }
        if dueDate != nil {
            title = String(title[..<match.range.lowerBound])
        }
        return dueDate
    }

    /// Glisser-déposer : `id` prend la place de `target`. Une tâche ne quitte pas son groupe
    /// (section, date, priorité) : seul l'ordre à l'intérieur du groupe change. Une tâche faite revient dans la liste.
    func move(_ id: TodoItem.ID, to target: TodoItem.ID) {
        uncomplete(id)
        var list = todos
        guard let from = list.firstIndex(where: { $0.id == id }),
              let to = list.firstIndex(where: { $0.id == target }), from != to else { return }
        list.insert(list.remove(at: from), at: to)
        list = list.enumerated()
            .sorted { sortKey($0.element, order: $0.offset) < sortKey($1.element, order: $1.offset) }
            .map(\.element)
        // Mêmes valeurs d'ordre, redistribuées : aucun conflit avec les tâches faites.
        for (item, order) in zip(list, todos.map(\.order).sorted()) {
            if let i = index(of: item.id) { items[i].order = order }
        }
        save()
    }

    /// Remet la tâche dans l'état d'avant la dernière action (la réinsère si elle a été supprimée).
    /// Elle garde sa place actuelle : un glisser-déposer fait depuis ne s'annule pas avec elle.
    func undo() {
        guard var previous = undoStack.popLast() else { return }
        if let i = index(of: previous.id) {
            previous.order = items[i].order
            items[i] = previous
        } else {
            items.append(previous)
        }
        save()
    }

    /// Synchronisation iCloud activée ou coupée : la liste change de fichier. En rejoignant un fichier existant
    /// (`merging`), ses tâches sont gardées et celles d'ici qui n'y sont pas s'y ajoutent.
    /// Fichier existant illisible (rien n'est écrasé) ou écriture impossible (accès refusé) : rien ne change,
    /// et la réponse est `false`.
    @discardableResult
    func relocate(to persistence: Persistence, merging: Bool) -> Bool {
        var list = items
        if merging {
            let there: [TodoItem]
            do {
                there = try persistence.read() ?? []
            } catch {
                NSLog("Doneko : impossible de lire \(persistence.url.path) (\(error))")
                return false
            }
            let ids = Set(there.map(\.id))
            list = there + items.filter { !ids.contains($0.id) }
        }
        do {
            try persistence.save(list)
        } catch {
            NSLog("Doneko : impossible d'écrire dans \(persistence.url.path) (\(error))")
            return false
        }
        self.persistence = persistence
        if list != items {
            items = list
            undoStack.removeAll()
        }
        return true
    }

    /// Le fichier a été modifié ailleurs (un autre appareil, via iCloud) : la liste est relue. Notre propre écriture
    /// ne compte pas ; fichier absent ou illisible (synchronisation en cours) : la liste reste telle quelle.
    func reloadIfChangedOnDisk() {
        guard let persistence, let data = try? persistence.data(),
              data != (try? Persistence.encode(items)), let loaded = try? Persistence.decode(data) else { return }
        items = loaded
        undoStack.removeAll()
    }

    /// Au changement de jour, les tâches de « Plus tard » arrivées à échéance passent dans « Aujourd'hui ».
    func refreshDay() {
        let day = calendar.startOfDay(for: clock.now())
        if day != currentDay { currentDay = day }
    }

    /// Vide « Tombé aujourd'hui » : retire les tâches faites avant le dernier passage de l'heure de purge
    /// (minuit par défaut, réglable).
    func purgeDone(atHour hour: Int = 0) {
        let now = clock.now()
        var boundary = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: now) ?? calendar.startOfDay(for: now)
        if boundary > now { boundary = calendar.date(byAdding: .day, value: -1, to: boundary) ?? boundary }
        let purged = Set(items.filter { ($0.completedAt ?? .distantFuture) < boundary }.map(\.id))
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

    private func isLater(_ item: TodoItem) -> Bool {
        (item.dueDate ?? .distantPast) > currentDay
    }

    /// « Aujourd'hui » avant « Plus tard », date, priorité, puis ordre.
    private func sortKey(_ item: TodoItem, order: Int? = nil) -> (Date, Int, Int) {
        let day = isLater(item) ? item.dueDate ?? .distantPast : .distantPast
        return (day, item.isPriority ? 0 : 1, order ?? item.order)
    }

    private func index(of id: TodoItem.ID) -> Int? {
        items.firstIndex { $0.id == id }
    }
}

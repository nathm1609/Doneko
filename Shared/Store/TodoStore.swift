import Foundation
import Observation

@Observable
final class TodoStore {
    /// Tâches à faire et faites ; les supprimées sont à part, dans `tombstones`.
    private(set) var items: [TodoItem]
    /// Tâches supprimées (ou vidées de « Tombé aujourd'hui ») depuis moins de 30 jours. Elles restent dans le fichier
    /// pour que la suppression l'emporte sur l'autre appareil, qui a peut-être encore l'ancienne version.
    @ObservationIgnored private var tombstones: [TodoItem]
    /// Versions précédentes des tâches touchées par complete / delete / edit, la plus récente en dernier.
    private var undoStack: [TodoItem] = []
    @ObservationIgnored private let clock: Clock
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private var persistence: Persistence?
    /// Début du jour en cours : sépare « Aujourd'hui » de « Plus tard ». Avancé par `refreshDay()`.
    private(set) var currentDay: Date

    /// Sans `persistence`, la liste reste en mémoire (tests).
    init(persistence: Persistence? = nil, clock: Clock = SystemClock(), calendar: Calendar = .current) {
        let saved = persistence?.load() ?? []
        self.items = saved.filter { $0.deletedAt == nil }
        self.tombstones = saved.filter { $0.deletedAt != nil }
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
        items.append(TodoItem(
            title: title, createdAt: clock.now(), isPriority: isPriority, dueDate: dueDate, order: order,
            updatedAt: stamp(after: nil)
        ))
        save()
    }

    func complete(_ id: TodoItem.ID) {
        guard let i = index(of: id), items[i].completedAt == nil else { return }
        undoStack.append(items[i])
        items[i].updatedAt = stamp(after: items[i])
        items[i].completedAt = clock.now()
        save()
    }

    /// Décoche une tâche faite : elle revient à sa place dans la liste.
    func uncomplete(_ id: TodoItem.ID) {
        guard let i = index(of: id), items[i].completedAt != nil else { return }
        undoStack.append(items[i])
        items[i].updatedAt = stamp(after: items[i])
        items[i].completedAt = nil
        save()
    }

    func delete(_ id: TodoItem.ID) {
        guard let i = index(of: id) else { return }
        let item = items.remove(at: i)
        undoStack.append(item)
        bury(item)
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
        items[i].updatedAt = stamp(after: items[i])
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
            if let i = index(of: item.id), items[i].order != order {
                items[i].updatedAt = stamp(after: items[i])
                items[i].order = order
            }
        }
        save()
    }

    /// Remet la tâche dans l'état d'avant la dernière action (la réinsère si elle a été supprimée).
    /// Elle garde sa place actuelle : un glisser-déposer fait depuis ne s'annule pas avec elle.
    func undo() {
        guard var previous = undoStack.popLast() else { return }
        // Plus récente que la suppression ou la coche annulée : elle l'emporte aussi sur l'autre appareil.
        let current = items.first { $0.id == previous.id } ?? tombstones.first { $0.id == previous.id }
        previous.updatedAt = stamp(after: current ?? previous)
        if let i = index(of: previous.id) {
            previous.order = items[i].order
            items[i] = previous
        } else {
            tombstones.removeAll { $0.id == previous.id }
            items.append(previous)
        }
        save()
    }

    /// Synchronisation iCloud activée ou coupée : la liste change de fichier. En rejoignant un fichier existant
    /// (`merging`), les deux listes sont fusionnées tâche par tâche.
    /// Fichier existant illisible (rien n'est écrasé) ou écriture impossible (accès refusé) : rien ne change,
    /// et la réponse est `false`.
    @discardableResult
    func relocate(to persistence: Persistence, merging: Bool) -> Bool {
        var list = snapshot
        if merging {
            let there: [TodoItem]
            do {
                there = try persistence.read() ?? []
            } catch {
                NSLog("Doneko : impossible de lire \(persistence.url.path) (\(error))")
                return false
            }
            list = Self.merge(list, there)
        }
        do {
            try persistence.save(list)
        } catch {
            NSLog("Doneko : impossible d'écrire dans \(persistence.url.path) (\(error))")
            return false
        }
        self.persistence = persistence
        if list != snapshot {
            adopt(list)
            undoStack.removeAll()
        }
        return true
    }

    /// Le fichier a été modifié ailleurs (un autre appareil, via iCloud) : il est fusionné tâche par tâche avec la liste,
    /// ainsi que les versions qu'iCloud a mises de côté, et ce qu'on avait changé sans le voir (hors ligne, ou au même
    /// moment) y est réécrit pour l'autre appareil. Notre propre écriture ne compte pas ; fichier absent, pas encore
    /// téléchargé ou illisible : la liste reste telle quelle.
    func reloadIfChangedOnDisk() {
        guard let persistence else { return }
        let conflicts = persistence.conflicts()
        guard let data = try? persistence.currentData(), let theirs = try? Persistence.decode(data),
              data != (try? Persistence.encode(snapshot)) || !conflicts.isEmpty else { return }
        absorb(theirs)
        conflicts.forEach { absorb($0.items) }
        if (try? Persistence.encode(snapshot)) != data, !save() { return }
        persistence.resolve(conflicts.map(\.version))
    }

    /// Au changement de jour, les tâches de « Plus tard » arrivées à échéance passent dans « Aujourd'hui ».
    func refreshDay() {
        let day = calendar.startOfDay(for: clock.now())
        if day != currentDay { currentDay = day }
    }

    /// Vide « Tombé aujourd'hui » : retire les tâches faites avant le dernier passage de l'heure de purge
    /// (minuit par défaut, réglable), et oublie les suppressions de plus de 30 jours.
    func purgeDone(atHour hour: Int = 0) {
        let now = clock.now()
        var boundary = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: now) ?? calendar.startOfDay(for: now)
        if boundary > now { boundary = calendar.date(byAdding: .day, value: -1, to: boundary) ?? boundary }
        let purged = items.filter { ($0.completedAt ?? .distantFuture) < boundary }
        guard !purged.isEmpty || tombstones.contains(where: isForgotten) else { return }
        let ids = Set(purged.map(\.id))
        items.removeAll { ids.contains($0.id) }
        tombstones.removeAll(where: isForgotten)
        purged.forEach(bury)
        // Une annulation ne doit ramener aucune version d'une tâche purgée.
        undoStack.removeAll { ids.contains($0.id) }
        save()
    }

    /// Ce que l'autre appareil a écrit depuis notre dernière lecture est d'abord fusionné, jamais écrasé.
    /// Fichier présent mais pas encore téléchargé : rien n'est écrit, la prochaine relecture fusionnera puis écrira.
    /// shortcut: les changements faits pendant ce temps sont perdus si l'app est quittée avant ; les écrire à part
    /// si ça arrive.
    @discardableResult
    private func save() -> Bool {
        guard let persistence else { return true }
        do {
            if let data = try persistence.currentData(), let theirs = try? Persistence.decode(data) { absorb(theirs) }
            try persistence.save(snapshot)
            return true
        } catch {
            NSLog("Doneko : sauvegarde impossible (\(error))")
            return false
        }
    }

    /// Ce qu'on écrit dans le fichier : toutes les tâches, supprimées comprises, toujours dans le même ordre, pour que
    /// deux appareils qui ont la même liste écrivent exactement le même fichier.
    private var snapshot: [TodoItem] { Self.canonical(items + tombstones) }

    /// Heure d'une modification : à la seconde, comme dans le fichier, pour que les deux appareils comparent les mêmes
    /// valeurs ; et toujours après la version précédente, pour que deux changements dans la même seconde gardent le dernier.
    private func stamp(after previous: TodoItem?) -> Date {
        let now = Date(timeIntervalSince1970: clock.now().timeIntervalSince1970.rounded(.down))
        return previous.map { max(now, $0.lastChange.addingTimeInterval(1)) } ?? now
    }

    private func bury(_ item: TodoItem) {
        var item = item
        item.deletedAt = stamp(after: item)
        item.updatedAt = item.deletedAt
        tombstones.append(item)
    }

    /// Suppression de plus de 30 jours : l'autre appareil l'a reçue depuis longtemps.
    private func isForgotten(_ item: TodoItem) -> Bool {
        guard let deletedAt = item.deletedAt,
              let limit = calendar.date(byAdding: .day, value: -30, to: clock.now()) else { return false }
        return deletedAt < limit
    }

    /// Fusionne la liste d'un autre appareil avec la nôtre.
    private func absorb(_ theirs: [TodoItem]) {
        let merged = Self.merge(snapshot, theirs.filter { !isForgotten($0) })
        if merged != snapshot { adopt(merged) }
    }

    private func adopt(_ list: [TodoItem]) {
        items = list.filter { $0.deletedAt == nil }
        tombstones = list.filter { $0.deletedAt != nil }
    }

    /// Chaque tâche garde sa version la plus récente, suppressions comprises. Une tâche absente d'un côté n'est pas
    /// supprimée pour autant : seule une suppression enregistrée (`deletedAt`) la retire.
    private static func merge(_ mine: [TodoItem], _ theirs: [TodoItem]) -> [TodoItem] {
        var byID = Dictionary(mine.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for item in theirs {
            byID[item.id] = byID[item.id].map { newer($0, item) } ?? item
        }
        return canonical(Array(byID.values))
    }

    /// La plus récente des deux versions d'une tâche. À la même seconde, un choix arbitraire mais identique sur chaque
    /// appareil, sinon chacun réécrirait la sienne indéfiniment.
    private static func newer(_ a: TodoItem, _ b: TodoItem) -> TodoItem {
        if a.lastChange != b.lastChange { return a.lastChange > b.lastChange ? a : b }
        let (x, y) = ((try? Persistence.encode([a])) ?? Data(), (try? Persistence.encode([b])) ?? Data())
        return x.lexicographicallyPrecedes(y) ? b : a
    }

    private static func canonical(_ items: [TodoItem]) -> [TodoItem] {
        items.sorted { $0.id.uuidString < $1.id.uuidString }
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

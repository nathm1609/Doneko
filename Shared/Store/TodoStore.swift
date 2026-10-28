import Foundation
import Observation

@Observable
final class TodoStore {
    /// Tâches à faire et faites ; les supprimées sont à part, dans `tombstones`.
    private(set) var items: [TodoItem]
    /// Tâches supprimées (ou vidées de « Tombé aujourd'hui ») depuis moins de 30 jours. Elles restent dans le fichier
    /// pour que la suppression l'emporte sur l'autre appareil, qui a peut-être encore l'ancienne version.
    @ObservationIgnored private var tombstones: [TodoItem]
    /// Dossiers, dans l'ordre du fichier ; `folders` les donne dans l'ordre de la barre.
    private var liveFolders: [Folder]
    /// Dossiers supprimés depuis moins de 30 jours, gardés pour la même raison que `tombstones`.
    @ObservationIgnored private var buriedFolders: [Folder]
    /// Ce que ⌘Z défait, le plus récent en dernier.
    private var undoStack: [Undo] = []
    @ObservationIgnored private let clock: Clock
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private var persistence: Persistence?
    /// Début du jour en cours : sépare « Aujourd'hui » de « Plus tard ». Avancé par `refreshDay()`.
    private(set) var currentDay: Date
    /// Les tâches faites avant sont masquées (`hideDone`), pas effacées.
    private(set) var doneSince = Date.distantPast

    private enum Undo {
        /// Version précédente d'une tâche touchée par complete / delete / edit / file.
        case task(TodoItem)
        /// Dossier supprimé, et les tâches qu'il contenait.
        case folder(Folder, tasks: [TodoItem.ID])
    }

    /// Sans `persistence`, la liste reste en mémoire (tests).
    init(persistence: Persistence? = nil, clock: Clock = SystemClock(), calendar: Calendar = .current) {
        let saved = persistence?.load() ?? SavedList()
        self.items = saved.items.filter { $0.deletedAt == nil }
        self.tombstones = saved.items.filter { $0.deletedAt != nil }
        self.liveFolders = saved.folders.filter { $0.deletedAt == nil }
        self.buriedFolders = saved.folders.filter { $0.deletedAt != nil }
        self.persistence = persistence
        self.clock = clock
        self.calendar = calendar
        self.currentDay = calendar.startOfDay(for: clock.now())
    }

    /// Tâches à faire, dans l'ordre d'affichage : « Aujourd'hui » puis « Plus tard » (par date),
    /// les prioritaires en tête de chaque groupe, puis dans l'ordre choisi.
    var todos: [TodoItem] { todos(in: nil) }

    /// Sans échéance, ou échéance atteinte ou dépassée.
    var today: [TodoItem] { today(in: nil) }

    /// Échéance après aujourd'hui.
    var later: [TodoItem] { later(in: nil) }

    /// Tâches faites, la plus récente en premier.
    var done: [TodoItem] { done(in: nil) }

    /// Mêmes listes, limitées au dossier choisi dans la barre (`nil` : « Tout »).
    func todos(in folder: Folder.ID?) -> [TodoItem] {
        items.filter { $0.completedAt == nil && isIn(folder, $0) }.sorted { sortKey($0) < sortKey($1) }
    }

    func today(in folder: Folder.ID?) -> [TodoItem] { todos(in: folder).filter { !isLater($0) } }

    func later(in folder: Folder.ID?) -> [TodoItem] { todos(in: folder).filter(isLater) }

    func done(in folder: Folder.ID?) -> [TodoItem] {
        items.filter { ($0.completedAt.map { $0 >= doneSince } ?? false) && isIn(folder, $0) }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    /// Dossiers dans l'ordre de la barre.
    var folders: [Folder] {
        liveFolders.sorted { ($0.order, $0.id.uuidString) < ($1.order, $1.id.uuidString) }
    }

    /// Dossier où la tâche est rangée, s'il existe encore.
    func folder(of item: TodoItem) -> Folder? {
        liveFolders.first { $0.id == item.folderID }
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

    /// `folder` : dossier choisi dans la barre ; un `#nom` tapé l'emporte.
    func add(_ input: String, in folder: Folder.ID? = nil) {
        let parsed = parse(input)
        guard !parsed.title.isEmpty else { return }
        let folderID = parsed.folder.flatMap(addFolder) ?? folder
        let order = (items.map(\.order).max() ?? -1) + 1
        items.append(TodoItem(
            title: parsed.title, createdAt: clock.now(), isPriority: parsed.isPriority, dueDate: parsed.dueDate,
            order: order, folderID: folderID, updatedAt: stamp(after: nil)
        ))
        save()
    }

    func complete(_ id: TodoItem.ID) {
        guard let i = index(of: id), items[i].completedAt == nil else { return }
        undoStack.append(.task(items[i]))
        items[i].updatedAt = stamp(after: items[i].lastChange)
        items[i].completedAt = clock.now()
        save()
    }

    /// Décoche une tâche faite : elle revient à sa place dans la liste.
    func uncomplete(_ id: TodoItem.ID) {
        guard let i = index(of: id), items[i].completedAt != nil else { return }
        undoStack.append(.task(items[i]))
        items[i].updatedAt = stamp(after: items[i].lastChange)
        items[i].completedAt = nil
        save()
    }

    func delete(_ id: TodoItem.ID) {
        guard let i = index(of: id) else { return }
        let item = items.remove(at: i)
        undoStack.append(.task(item))
        tombstones.append(buried(item))
        save()
    }

    /// Le titre suit les mêmes règles qu'à l'ajout : « ! » final = prioritaire, son absence retire la priorité.
    /// Une date ou un `#nom` tapés remplacent l'échéance ou le dossier ; sans eux, ils restent les mêmes.
    func edit(_ id: TodoItem.ID, title input: String) {
        let parsed = parse(input)
        guard !parsed.title.isEmpty, index(of: id) != nil else { return }
        // Avant de prendre la position de la tâche : créer le dossier enregistre, et peut réordonner la liste.
        let folderID = parsed.folder.flatMap(addFolder)
        guard let i = index(of: id) else { return }
        var item = items[i]
        item.title = parsed.title
        item.isPriority = parsed.isPriority
        item.dueDate = parsed.dueDate ?? item.dueDate
        item.folderID = folderID ?? item.folderID
        guard item != items[i] else { return }
        undoStack.append(.task(items[i]))
        item.updatedAt = stamp(after: items[i].lastChange)
        items[i] = item
        save()
    }

    /// Appui long › « Prioritaire » (iPhone) : la tâche remonte en haut de sa section, ou y reprend sa place.
    func setPriority(_ id: TodoItem.ID, _ isPriority: Bool) {
        guard let i = index(of: id), items[i].isPriority != isPriority else { return }
        undoStack.append(.task(items[i]))
        items[i].updatedAt = stamp(after: items[i].lastChange)
        items[i].isPriority = isPriority
        save()
    }

    /// « Ranger dans » : `nil` sort la tâche de son dossier.
    func file(_ id: TodoItem.ID, in folder: Folder.ID?) {
        guard let i = index(of: id), items[i].folderID != folder else { return }
        undoStack.append(.task(items[i]))
        items[i].updatedAt = stamp(after: items[i].lastChange)
        items[i].folderID = folder
        save()
    }

    /// Nouveau dossier, au bout de la barre. Nom vide : rien ; nom déjà pris (majuscules et accents mis à part) :
    /// ce dossier-là.
    @discardableResult
    func addFolder(_ name: String) -> Folder.ID? {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        if let existing = folder(named: name) { return existing.id }
        let folder = Folder(name: name, order: (liveFolders.map(\.order).max() ?? -1) + 1, updatedAt: stamp(after: nil))
        liveFolders.append(folder)
        save()
        return folder.id
    }

    /// Nom vide, ou déjà pris par un autre dossier : rien ne change.
    func renameFolder(_ id: Folder.ID, to name: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, folder(named: name).map({ $0.id == id }) ?? true,
              let i = liveFolders.firstIndex(where: { $0.id == id }), liveFolders[i].name != name else { return }
        liveFolders[i].updatedAt = stamp(after: liveFolders[i].lastChange)
        liveFolders[i].name = name
        save()
    }

    /// `id` prend la place de `target` dans la barre.
    func moveFolder(_ id: Folder.ID, to target: Folder.ID) {
        var list = folders
        guard let from = list.firstIndex(where: { $0.id == id }),
              let to = list.firstIndex(where: { $0.id == target }), from != to else { return }
        list.insert(list.remove(at: from), at: to)
        for (order, folder) in list.enumerated() {
            if let i = liveFolders.firstIndex(where: { $0.id == folder.id }), liveFolders[i].order != order {
                liveFolders[i].updatedAt = stamp(after: liveFolders[i].lastChange)
                liveFolders[i].order = order
            }
        }
        save()
    }

    /// Ses tâches reviennent dans « Tout » ; ⌘Z rend le dossier et les y range de nouveau.
    func deleteFolder(_ id: Folder.ID) {
        guard let i = liveFolders.firstIndex(where: { $0.id == id }) else { return }
        let folder = liveFolders.remove(at: i)
        let filed = items.indices.filter { items[$0].folderID == id }
        for t in filed {
            items[t].updatedAt = stamp(after: items[t].lastChange)
            items[t].folderID = nil
        }
        undoStack.append(.folder(folder, tasks: filed.map { items[$0].id }))
        buriedFolders.append(buried(folder))
        save()
    }

    /// Fin de saisie : « ! » (un ou plusieurs) = prioritaire, et une date en français (« demain », « lundi »,
    /// « le 20 »), dans un ordre ou l'autre ; n'importe où, `#nom` range la tâche dans ce dossier.
    /// Tous sont retirés du titre.
    private func parse(_ input: String) -> (title: String, isPriority: Bool, dueDate: Date?, folder: String?) {
        var title = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let folder = Self.stripFolder(&title)
        let priorityFirst = Self.stripPriority(&title)
        let dueDate = stripDueDate(&title)
        let priorityLast = Self.stripPriority(&title)
        return (title, priorityFirst || priorityLast, dueDate, folder)
    }

    /// Premier `#nom` (lettres, chiffres, « - », « _ ») en début de saisie ou après une espace.
    private static func stripFolder(_ title: inout String) -> String? {
        guard let match = title.firstMatch(of: #/(?:^|\s+)#([\w-]+)/#) else { return nil }
        title.removeSubrange(match.range)
        title = title.trimmingCharacters(in: .whitespaces)
        return String(match.1)
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
                items[i].updatedAt = stamp(after: items[i].lastChange)
                items[i].order = order
            }
        }
        save()
    }

    /// Défait la dernière action : la tâche revient dans son état d'avant (réinsérée si elle a été supprimée), ou le
    /// dossier supprimé revient avec ses tâches. Une tâche garde sa place actuelle : un glisser-déposer fait depuis
    /// ne s'annule pas avec elle. Ce qui revient est daté de maintenant, pour l'emporter aussi sur l'autre appareil.
    func undo() {
        switch undoStack.popLast() {
        case .task(var previous):
            let current = items.first { $0.id == previous.id } ?? tombstones.first { $0.id == previous.id }
            previous.updatedAt = stamp(after: (current ?? previous).lastChange)
            if let i = index(of: previous.id) {
                previous.order = items[i].order
                items[i] = previous
            } else {
                tombstones.removeAll { $0.id == previous.id }
                items.append(previous)
            }
        case .folder(var folder, let tasks):
            let current = buriedFolders.first { $0.id == folder.id } ?? folder
            folder.updatedAt = stamp(after: current.lastChange)
            buriedFolders.removeAll { $0.id == folder.id }
            liveFolders.removeAll { $0.id == folder.id }
            liveFolders.append(folder)
            // Seulement les tâches restées hors dossier depuis.
            for id in tasks {
                guard let i = index(of: id), items[i].folderID == nil else { continue }
                items[i].updatedAt = stamp(after: items[i].lastChange)
                items[i].folderID = folder.id
            }
        case nil:
            return
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
            let there: SavedList
            do {
                there = try persistence.read() ?? SavedList()
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
        conflicts.forEach { absorb($0.list) }
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
        let boundary = purgeBoundary(atHour: hour)
        let purged = items.filter { ($0.completedAt ?? .distantFuture) < boundary }
        guard !purged.isEmpty || tombstones.contains(where: { isForgotten($0) })
                || buriedFolders.contains(where: { isForgotten($0) }) else { return }
        let ids = Set(purged.map(\.id))
        items.removeAll { ids.contains($0.id) }
        tombstones.removeAll { isForgotten($0) }
        buriedFolders.removeAll { isForgotten($0) }
        tombstones += purged.map(buried)
        // Une annulation ne doit ramener aucune version d'une tâche purgée.
        undoStack.removeAll {
            if case .task(let item) = $0 { return ids.contains(item.id) }
            return false
        }
        save()
    }

    /// iPhone synchronisé avec le Mac : vide « Tombé aujourd'hui » à l'écran seulement. Les tâches faites avant le
    /// dernier passage de l'heure de purge restent dans le fichier, pour que le Mac les exporte dans Obsidian avant de
    /// les effacer avec `purgeDone`.
    func hideDone(atHour hour: Int = 0) {
        let boundary = purgeBoundary(atHour: hour)
        if boundary != doneSince { doneSince = boundary }
    }

    /// Dernier passage de l'heure de purge (minuit par défaut) : début de la journée de « Tombé aujourd'hui ».
    private func purgeBoundary(atHour hour: Int) -> Date {
        let now = clock.now()
        let boundary = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: now) ?? calendar.startOfDay(for: now)
        return boundary > now ? calendar.date(byAdding: .day, value: -1, to: boundary) ?? boundary : boundary
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

    /// Ce qu'on écrit dans le fichier : tout, suppressions comprises, toujours dans le même ordre, pour que deux
    /// appareils qui ont la même liste écrivent exactement le même fichier.
    private var snapshot: SavedList {
        SavedList(items: Self.canonical(items + tombstones), folders: Self.canonical(liveFolders + buriedFolders))
    }

    /// Heure d'une modification : à la seconde, comme dans le fichier, pour que les deux appareils comparent les mêmes
    /// valeurs ; et toujours après la version précédente, pour que deux changements dans la même seconde gardent le dernier.
    private func stamp(after previous: Date?) -> Date {
        let now = Date(timeIntervalSince1970: clock.now().timeIntervalSince1970.rounded(.down))
        return previous.map { max(now, $0.addingTimeInterval(1)) } ?? now
    }

    /// Version supprimée, datée de maintenant.
    private func buried<T: Syncable>(_ element: T) -> T {
        var element = element
        element.deletedAt = stamp(after: element.lastChange)
        element.updatedAt = element.deletedAt
        return element
    }

    /// Suppression de plus de 30 jours : l'autre appareil l'a reçue depuis longtemps.
    private func isForgotten(_ element: some Syncable) -> Bool {
        guard let deletedAt = element.deletedAt,
              let limit = calendar.date(byAdding: .day, value: -30, to: clock.now()) else { return false }
        return deletedAt < limit
    }

    /// Fusionne la liste d'un autre appareil avec la nôtre.
    private func absorb(_ theirs: SavedList) {
        let recent = SavedList(
            items: theirs.items.filter { !isForgotten($0) }, folders: theirs.folders.filter { !isForgotten($0) }
        )
        let merged = Self.merge(snapshot, recent)
        if merged != snapshot { adopt(merged) }
    }

    private func adopt(_ list: SavedList) {
        items = list.items.filter { $0.deletedAt == nil }
        tombstones = list.items.filter { $0.deletedAt != nil }
        liveFolders = list.folders.filter { $0.deletedAt == nil }
        buriedFolders = list.folders.filter { $0.deletedAt != nil }
    }

    private static func merge(_ mine: SavedList, _ theirs: SavedList) -> SavedList {
        SavedList(items: merge(mine.items, theirs.items), folders: merge(mine.folders, theirs.folders))
    }

    /// Chaque élément garde sa version la plus récente, suppressions comprises. Un élément absent d'un côté n'est pas
    /// supprimé pour autant : seule une suppression enregistrée (`deletedAt`) le retire.
    private static func merge<T: Syncable>(_ mine: [T], _ theirs: [T]) -> [T] {
        var byID = Dictionary(mine.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for element in theirs {
            byID[element.id] = byID[element.id].map { newer($0, element) } ?? element
        }
        return canonical(Array(byID.values))
    }

    /// La plus récente des deux versions. À la même seconde, un choix arbitraire mais identique sur chaque appareil,
    /// sinon chacun réécrirait la sienne indéfiniment.
    private static func newer<T: Syncable>(_ a: T, _ b: T) -> T {
        if a.lastChange != b.lastChange { return a.lastChange > b.lastChange ? a : b }
        let (x, y) = ((try? Persistence.encode(a)) ?? Data(), (try? Persistence.encode(b)) ?? Data())
        return x.lexicographicallyPrecedes(y) ? b : a
    }

    private static func canonical<T: Syncable>(_ list: [T]) -> [T] {
        list.sorted { $0.id.uuidString < $1.id.uuidString }
    }

    private func folder(named name: String) -> Folder? {
        liveFolders.first { $0.name.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
    }

    private func isIn(_ folder: Folder.ID?, _ item: TodoItem) -> Bool {
        folder == nil || item.folderID == folder
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

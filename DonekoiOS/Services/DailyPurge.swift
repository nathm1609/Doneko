import Foundation

/// Vide « Tombé aujourd'hui » à l'heure choisie dans les réglages (minuit par défaut) : à l'ouverture, au retour au
/// premier plan et chaque minute. Synchronisé avec le Mac, l'iPhone masque seulement les tâches d'avant : le Mac les
/// exporte dans Obsidian, puis les efface. Fait aussi passer « Plus tard » dans « Aujourd'hui » au changement de jour.
final class DailyPurge {
    private let store: TodoStore
    private let sync: FolderSync
    private let defaults: UserDefaults
    private var timer: Timer?

    init(store: TodoStore, sync: FolderSync, defaults: UserDefaults = .standard, checkInterval: TimeInterval = 60) {
        self.store = store
        self.sync = sync
        self.defaults = defaults
        purge()
        timer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in self?.purge() }
    }

    deinit {
        timer?.invalidate()
    }

    func purge() {
        store.refreshDay()
        let hour = defaults.integer(forKey: SettingsKey.purgeHour)
        if sync.folderName == nil {
            store.purgeDone(atHour: hour)
        } else {
            store.hideDone(atHour: hour)
        }
    }
}

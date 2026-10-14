import AppKit

/// Vide « Tombé aujourd'hui » à l'heure choisie dans les réglages (minuit par défaut) :
/// au démarrage, au réveil de veille, et par une vérification chaque minute.
final class DailyPurge {
    private let store: TodoStore
    private let defaults: UserDefaults
    private var wakeObserver: (center: NotificationCenter, token: NSObjectProtocol)?
    private var timer: Timer?

    init(
        store: TodoStore,
        defaults: UserDefaults = .standard,
        workspaceCenter: NotificationCenter = NSWorkspace.shared.notificationCenter,
        checkInterval: TimeInterval = 60
    ) {
        self.store = store
        self.defaults = defaults
        purge()
        wakeObserver = (workspaceCenter, workspaceCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.purge() })
        // Une vérification par minute suffit à passer n'importe quelle heure choisie, même après un changement d'heure.
        timer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in self?.purge() }
    }

    deinit {
        timer?.invalidate()
        if let wakeObserver { wakeObserver.center.removeObserver(wakeObserver.token) }
    }

    func purge() {
        store.purgeDone(atHour: defaults.integer(forKey: SettingsKey.purgeHour))
    }
}

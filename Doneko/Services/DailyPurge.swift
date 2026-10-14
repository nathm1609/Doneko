import AppKit

/// Vide « Tombé aujourd'hui » au démarrage, à minuit et au réveil de veille.
final class DailyPurge {
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []

    init(store: TodoStore, workspaceCenter: NotificationCenter = NSWorkspace.shared.notificationCenter) {
        store.purgeDone()
        let purge: (Notification) -> Void = { _ in store.purgeDone() }
        observers = [
            // Posté par le système quand la date change (minuit, ou changement d'heure / de fuseau).
            (.default, NotificationCenter.default.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main, using: purge)),
            (workspaceCenter, workspaceCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main, using: purge)),
        ]
    }

    deinit {
        for (center, observer) in observers { center.removeObserver(observer) }
    }
}

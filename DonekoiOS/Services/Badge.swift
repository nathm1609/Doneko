import Foundation
import Observation
import UserNotifications

/// Pastille sur l'icône : le nombre de tâches du jour, comme le compteur de la barre de menu du Mac. Suit la liste et
/// le réglage tant que l'app tourne ; l'autorisation est demandée à la première pastille à afficher.
/// shortcut: iOS ne réveille pas l'app à minuit, une échéance qui arrive ne compte qu'à la prochaine ouverture ; passer
/// par un rafraîchissement en arrière-plan si ça gêne.
/// Toujours utilisé sur le fil principal (l'observation et l'autorisation y renvoient), d'où `@unchecked Sendable`.
final class Badge: NSObject, @unchecked Sendable {
    private let store: TodoStore
    private let defaults: UserDefaults
    private let center = UNUserNotificationCenter.current()
    private var shown: Int?
    private var hasAskedPermission = false

    init(store: TodoStore, defaults: UserDefaults = .standard) {
        self.store = store
        self.defaults = defaults
        super.init()
        update()
        observe()
        // Réglage « Afficher le nombre de tâches sur l'icône ».
        NotificationCenter.default.addObserver(self, selector: #selector(update), name: UserDefaults.didChangeNotification, object: defaults)
    }

    private func observe() {
        withObservationTracking {
            _ = store.today
        } onChange: { [weak self] in
            // Appelé juste avant la modification : on met à jour une fois qu'elle est faite.
            DispatchQueue.main.async {
                self?.update()
                self?.observe()
            }
        }
    }

    @objc private func update() {
        let count = defaults.bool(forKey: SettingsKey.showBadge) ? store.today.count : 0
        guard count != shown else { return }
        shown = count
        center.setBadgeCount(count)
        guard count > 0, !hasAskedPermission else { return }
        hasAskedPermission = true
        center.requestAuthorization(options: Reminders.permissions) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                self.shown = nil
                self.update()
            }
        }
    }
}

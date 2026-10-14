import Foundation
import Observation
import UserNotifications

/// Rappels des échéances : une notification par tâche datée, le jour venu à l'heure choisie dans les réglages.
/// Une tâche qui tombe, change de date ou disparaît voit son rappel suivre. Clic sur un rappel : le panneau s'ouvre.
/// Toujours utilisé sur le fil principal (l'observation et l'autorisation y renvoient), d'où `@unchecked Sendable`.
final class Reminders: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    struct Reminder: Equatable {
        let id: String
        let title: String
        let date: Date
    }

    /// Rappels à programmer : tâches à faire avec une échéance, à `hour` heures ce jour-là, s'il n'est pas déjà passé.
    /// `hour` négatif : pas de rappel.
    static func reminders(for todos: [TodoItem], hour: Int, now: Date, calendar: Calendar) -> [Reminder] {
        guard hour >= 0 else { return [] }
        return todos.compactMap { item in
            guard let dueDate = item.dueDate,
                  let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: dueDate), date > now
            else { return nil }
            return Reminder(id: item.id.uuidString, title: item.title, date: date)
        }
    }

    private let store: TodoStore
    private let defaults: UserDefaults
    private let clock: Clock
    private let calendar: Calendar
    private let onOpen: () -> Void
    private let center = UNUserNotificationCenter.current()
    private var scheduled: [Reminder] = []
    private var hasAskedPermission = false

    init(store: TodoStore, defaults: UserDefaults = .standard, clock: Clock = SystemClock(), calendar: Calendar = .current,
         onOpen: @escaping () -> Void) {
        self.store = store
        self.defaults = defaults
        self.clock = clock
        self.calendar = calendar
        self.onOpen = onOpen
        super.init()
        center.delegate = self
        schedule()
        observe()
        // Réglage « Rappeler les tâches du jour à ».
        NotificationCenter.default.addObserver(self, selector: #selector(schedule), name: UserDefaults.didChangeNotification, object: defaults)
    }

    private func observe() {
        withObservationTracking {
            _ = store.todos
        } onChange: { [weak self] in
            // Appelé juste avant la modification : on reprogramme une fois qu'elle est faite.
            DispatchQueue.main.async {
                self?.schedule()
                self?.observe()
            }
        }
    }

    @objc private func schedule() {
        let wanted = Self.reminders(
            for: store.todos, hour: defaults.integer(forKey: SettingsKey.reminderHour), now: clock.now(), calendar: calendar
        )
        guard wanted != scheduled else { return }
        scheduled = wanted
        center.removeAllPendingNotificationRequests()
        for reminder in wanted {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = "C'est pour aujourd'hui."
            content.sound = .default
            let when = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.date)
            center.add(UNNotificationRequest(
                identifier: reminder.id, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: false)
            ))
        }
        // Autorisation demandée à la première tâche datée seulement ; une fois accordée, on reprogramme.
        guard !wanted.isEmpty, !hasAskedPermission else { return }
        hasAskedPermission = true
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                self.scheduled = []
                self.schedule()
            }
        }
    }

    /// Rappel affiché même quand une fenêtre de Doneko est au premier plan (réglages).
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        DispatchQueue.main.async(execute: onOpen)
        completionHandler()
    }
}

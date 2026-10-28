import SwiftUI

/// App iPhone : la liste est sur l'appareil, ou dans le dossier iCloud Drive partagé avec le Mac s'il a été choisi.
/// Au lancement : store, synchronisation, purge quotidienne, rappels, pastille de l'icône.
@main
struct DonekoiOSApp: App {
    @State private var store: TodoStore
    @State private var sync: FolderSync
    @State private var dailyPurge: DailyPurge
    @State private var reminders: Reminders
    @State private var badge: Badge
    @Environment(\.scenePhase) private var scenePhase

    init() {
        UserDefaults.standard.register(defaults: [SettingsKey.reminderHour: 9, SettingsKey.showBadge: true])
        let folder = FolderSync.savedFolder()
        let store = TodoStore(persistence: folder.map(FolderSync.persistence(in:)) ?? Persistence())
        let sync = FolderSync(store: store, folder: folder)
        _store = State(initialValue: store)
        _sync = State(initialValue: sync)
        _dailyPurge = State(initialValue: DailyPurge(store: store, sync: sync))
        // Toucher un rappel ouvre l'app : rien de plus à faire.
        _reminders = State(initialValue: Reminders(store: store, onOpen: {}))
        _badge = State(initialValue: Badge(store: store))
    }

    var body: some Scene {
        WindowGroup {
            TodoListView(store: store, sync: sync)
        }
        // Retour au premier plan : ce que le Mac a changé entre-temps est relu tout de suite, et le jour a pu changer.
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            sync.check()
            dailyPurge.purge()
        }
    }
}

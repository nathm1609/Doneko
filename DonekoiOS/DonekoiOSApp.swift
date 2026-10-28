import SwiftUI

/// App iPhone : la liste est sur l'appareil, ou dans le dossier iCloud Drive partagé avec le Mac s'il a été choisi.
@main
struct DonekoiOSApp: App {
    @State private var store: TodoStore
    @State private var sync: FolderSync
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let folder = FolderSync.savedFolder()
        let store = TodoStore(persistence: folder.map(FolderSync.persistence(in:)) ?? Persistence())
        _store = State(initialValue: store)
        _sync = State(initialValue: FolderSync(store: store, folder: folder))
    }

    var body: some Scene {
        WindowGroup {
            TodoListView(store: store, sync: sync)
        }
        // Retour au premier plan : ce que le Mac a changé entre-temps est relu tout de suite.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { sync.check() }
        }
    }
}

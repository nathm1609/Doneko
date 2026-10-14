import SwiftUI

@main
struct DonekoApp: App {
    @State private var store = TodoStore(persistence: Persistence())

    var body: some Scene {
        MenuBarExtra {
            PanelView(store: store)
        } label: {
            let remaining = store.todos.count
            // Éveillé s'il reste des tâches, endormi sinon ; compteur masqué à 0.
            Image(remaining > 0 ? "MenuIconAwake" : "MenuIconAsleep")
                .help(store.summary)
                .accessibilityLabel(store.summary)
            if remaining > 0 {
                Text("\(remaining)")
                    .font(Theme.Typography.counter)
            }
        }
        .menuBarExtraStyle(.window)
    }
}

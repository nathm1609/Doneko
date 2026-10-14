import SwiftUI

@main
struct DonekoApp: App {
    @State private var store = TodoStore(persistence: Persistence())

    var body: some Scene {
        MenuBarExtra {
            PanelView(store: store)
        } label: {
            // Passage éveillé / endormi et compteur : étape 8.
            Image("MenuIconAwake")
                .accessibilityLabel("Doneko")
        }
        .menuBarExtraStyle(.window)
    }
}

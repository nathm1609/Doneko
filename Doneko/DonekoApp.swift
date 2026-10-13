import SwiftUI

@main
struct DonekoApp: App {
    var body: some Scene {
        // Icône provisoire (SF Symbol) : remplacée par MenuIconAwake / MenuIconAsleep à l'étape 4.
        MenuBarExtra("Doneko", systemImage: "cat") {
            VStack {
                Text("Doneko")
                Button("Laisser Doneko dormir (Quitter)") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q")
            }
            .padding()
        }
        .menuBarExtraStyle(.window)
    }
}

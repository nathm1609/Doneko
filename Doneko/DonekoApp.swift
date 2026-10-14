import SwiftUI

@main
struct DonekoApp: App {
    var body: some Scene {
        MenuBarExtra {
            VStack {
                Text("Doneko")
                Button("Laisser Doneko dormir (Quitter)") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q")
            }
            .padding()
        } label: {
            // Passage éveillé / endormi et compteur : étape 8.
            Image("MenuIconAwake")
                .accessibilityLabel("Doneko")
        }
        .menuBarExtraStyle(.window)
    }
}

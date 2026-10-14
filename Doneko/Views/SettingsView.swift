import KeyboardShortcuts
import SwiftUI

/// Fenêtre « Réglages », ouverte par le bouton ⚙︎ du panneau.
struct SettingsView: View {
    @AppStorage(SettingsKey.purgeHour) private var purgeHour = 0
    @AppStorage(SettingsKey.soundEnabled) private var soundEnabled = false
    @AppStorage(SettingsKey.showCounter) private var showCounter = true
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        Form {
            KeyboardShortcuts.Recorder("Raccourci pour appeler Doneko", name: .openPanel)
            Picker("Vider « Tombé aujourd'hui » à", selection: $purgeHour) {
                ForEach(0..<24, id: \.self) { hour in
                    Text(hour == 0 ? "minuit" : "\(hour) h").tag(hour)
                }
            }
            Toggle("Petit « pop » quand une tâche tombe", isOn: $soundEnabled)
            Toggle("Afficher le compteur dans la barre de menu", isOn: $showCounter)
            Toggle("Lancer au démarrage", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, enabled in
                    LaunchAtLogin.set(enabled)
                    // Reflète un refus de macOS (version de développement, validation demandée).
                    launchAtLogin = LaunchAtLogin.isEnabled
                }
        }
        .formStyle(.grouped)
        .fontDesign(.rounded)
        .frame(width: Theme.Layout.settingsWidth)
    }
}

import KeyboardShortcuts
import SwiftUI
import UniformTypeIdentifiers

/// Fenêtre « Réglages », ouverte par le bouton ⚙︎ du panneau.
struct SettingsView: View {
    @AppStorage(SettingsKey.purgeHour) private var purgeHour = 0
    @AppStorage(SettingsKey.reminderHour) private var reminderHour = 9
    @AppStorage(SettingsKey.soundEnabled) private var soundEnabled = false
    @AppStorage(SettingsKey.showCounter) private var showCounter = true
    @AppStorage(SettingsKey.obsidianFolder) private var obsidianFolder = ""
    @AppStorage(SettingsKey.iCloudSync) private var iCloudSync = false
    @State private var isChoosingFolder = false
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        Form {
            KeyboardShortcuts.Recorder("Raccourci pour appeler Doneko", name: .openPanel)
            Picker("Vider « Tombé aujourd'hui » à", selection: $purgeHour) {
                ForEach(0..<24, id: \.self) { hour in
                    Text(hour == 0 ? "minuit" : "\(hour) h").tag(hour)
                }
            }
            Picker("Rappeler les tâches datées à", selection: $reminderHour) {
                Text("jamais").tag(-1)
                ForEach(0..<24, id: \.self) { hour in
                    Text(hour == 0 ? "minuit" : "\(hour) h").tag(hour)
                }
            }
            Toggle("Petit « pop » quand une tâche tombe", isOn: $soundEnabled)
            Toggle("Afficher le compteur dans la barre de menu", isOn: $showCounter)
            LabeledContent {
                if !obsidianFolder.isEmpty {
                    Button("Arrêter") { obsidianFolder = "" }
                }
                Button(obsidianFolder.isEmpty ? "Choisir…" : "Changer…") { isChoosingFolder = true }
            } label: {
                Text("Exporter les tâches faites dans Obsidian")
                Text(obsidianFolder.isEmpty
                     ? "Une note par jour, section « Fait avec Doneko »"
                     : "Dossier « \(URL(fileURLWithPath: obsidianFolder).lastPathComponent) »")
            }
            .help((obsidianFolder as NSString).abbreviatingWithTildeInPath)
            .fileImporter(isPresented: $isChoosingFolder, allowedContentTypes: [.folder]) { result in
                if case let .success(url) = result { obsidianFolder = url.path }
            }
            Toggle(isOn: $iCloudSync) {
                Text("Synchroniser avec iCloud Drive")
                Text(ICloudSync.isDriveAvailable ? "Les mêmes tâches sur tous tes Mac" : "iCloud Drive n'est pas activé sur ce Mac")
            }
            .disabled(!ICloudSync.isDriveAvailable && !iCloudSync)
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

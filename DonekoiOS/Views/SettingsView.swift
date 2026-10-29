import SwiftUI
import UniformTypeIdentifiers

/// « Réglages », ouverts par le bouton ⚙︎ en haut de la liste : synchronisation avec le Mac, vidage de « Tombé
/// aujourd'hui », rappels, son, pastille.
struct SettingsView: View {
    let sync: FolderSync

    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.purgeHour) private var purgeHour = 0
    @AppStorage(SettingsKey.reminderHour) private var reminderHour = 9
    @AppStorage(SettingsKey.soundEnabled) private var soundEnabled = false
    @AppStorage(SettingsKey.showBadge) private var showBadge = true
    @AppStorage(SettingsKey.appearance) private var appearance = ""
    @State private var isPickingFolder = false
    @State private var isFolderRefused = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let name = sync.folderName {
                        LabeledContent("Dossier", value: name)
                        Button("Arrêter la synchronisation", role: .destructive) { sync.detach() }
                    } else {
                        Button("Choisir le dossier Doneko…") { isPickingFolder = true }
                    }
                } header: {
                    Text("Synchronisation avec le Mac")
                } footer: {
                    Text("Dans Fichiers : iCloud Drive › Doneko, le dossier de la synchronisation du Mac.")
                }
                .listRowBackground(Theme.Palette.coussin)

                Section {
                    Picker("Apparence", selection: $appearance) {
                        Text("Automatique").tag("")
                        Text("Clair").tag("light")
                        Text("Sombre").tag("dark")
                    }
                    Picker("Vider « Tombé aujourd'hui » à", selection: $purgeHour) {
                        hours
                    }
                    Picker("Rappeler les tâches datées à", selection: $reminderHour) {
                        Text("jamais").tag(-1)
                        hours
                    }
                    Toggle("Petit « pop » quand une tâche tombe", isOn: $soundEnabled)
                    Toggle("Afficher le nombre de tâches sur l'icône", isOn: $showBadge)
                } footer: {
                    if sync.folderName != nil {
                        Text("Synchronisé : les tâches de la veille disparaissent d'ici, le Mac les exporte dans Obsidian.")
                    }
                }
                .listRowBackground(Theme.Palette.coussin)
            }
            // Fond Crème de la feuille, cases Coussin : la même matière que la liste.
            .scrollContentBackground(.hidden)
            .navigationTitle("Réglages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
            .fileImporter(isPresented: $isPickingFolder, allowedContentTypes: [.folder]) { result in
                if case .success(let folder) = result, !sync.attach(folder) { isFolderRefused = true }
            }
            .alert("Ce dossier ne peut pas être utilisé", isPresented: $isFolderRefused) {
                Button("OK") {}
            } message: {
                Text("Choisis le dossier Doneko dans iCloud Drive.")
            }
        }
        .presentationBackground(Theme.Palette.creme)
        .fontDesign(.rounded)
    }

    private var hours: some View {
        ForEach(0..<24, id: \.self) { hour in
            Text(hour == 0 ? "minuit" : "\(hour) h").tag(hour)
        }
    }
}

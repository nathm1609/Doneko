import SwiftUI

/// Barre de dossiers sous le champ : « Tout », les dossiers, puis « + ». Le dossier choisi filtre la liste et reçoit
/// les nouvelles tâches. Clic droit sur un dossier : renommer, déplacer, supprimer.
struct FolderBar: View {
    let store: TodoStore
    /// `nil` : « Tout ».
    @Binding var selection: Folder.ID?
    /// « Supprimer le dossier » : le panneau le supprime et propose d'annuler.
    let onDelete: (Folder) -> Void
    /// Fin de la saisie d'un nom : le curseur retourne dans le champ des tâches.
    let onEditEnd: () -> Void

    /// Dossier qu'on renomme.
    @State private var renaming: Folder.ID?
    @State private var isCreating = false
    @State private var draft = ""
    @FocusState private var isNameFocused: Bool

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Layout.smallSpacing) {
                chip("Tout", isSelected: selection == nil) { selection = nil }
                ForEach(store.folders) { folder in
                    if renaming == folder.id {
                        nameField { store.renameFolder(folder.id, to: draft) }
                    } else {
                        chip(folder.name, isSelected: selection == folder.id) { selection = folder.id }
                            .contextMenu { menu(for: folder) }
                    }
                }
                if isCreating {
                    nameField {
                        if let id = store.addFolder(draft) { selection = id }
                    }
                } else {
                    Button { startEditing(nil) } label: {
                        Image(systemName: "plus")
                            .font(Theme.Typography.caption)
                            .padding(.horizontal, Theme.Layout.folderChipPadding)
                            .frame(height: Theme.Layout.folderChipHeight)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.pressable)
                    .foregroundStyle(Theme.Palette.moustache)
                    .help("Nouveau dossier")
                    .accessibilityLabel("Nouveau dossier")
                }
            }
        }
    }

    private func chip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Typography.caption)
                .lineLimit(1)
                .foregroundStyle(isSelected ? Theme.Palette.encre : Theme.Palette.moustache)
                .padding(.horizontal, Theme.Layout.folderChipPadding)
                .frame(height: Theme.Layout.folderChipHeight)
                .background(isSelected ? Theme.Palette.coussin : .clear, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func menu(for folder: Folder) -> some View {
        let folders = store.folders
        let i = folders.firstIndex(of: folder) ?? 0
        Button("Renommer") { startEditing(folder) }
        Button("Vers la gauche") { store.moveFolder(folder.id, to: folders[i - 1].id) }
            .disabled(i == 0)
        Button("Vers la droite") { store.moveFolder(folder.id, to: folders[i + 1].id) }
            .disabled(i >= folders.count - 1)
        Divider()
        Button("Supprimer le dossier") { onDelete(folder) }
    }

    /// Entrée valide, Échap ou un clic ailleurs abandonnent.
    private func nameField(onCommit: @escaping () -> Void) -> some View {
        TextField("Nom du dossier", text: $draft)
            .textFieldStyle(.plain)
            .font(Theme.Typography.caption)
            .foregroundStyle(Theme.Palette.encre)
            .focused($isNameFocused)
            .frame(width: Theme.Layout.folderNameWidth)
            .padding(.horizontal, Theme.Layout.folderChipPadding)
            .frame(height: Theme.Layout.folderChipHeight)
            .background(Theme.Palette.coussin, in: Capsule())
            .overlay { Capsule().strokeBorder(Theme.Palette.mandarine, lineWidth: Theme.Layout.focusRingWidth) }
            .onSubmit {
                onCommit()
                stopEditing()
            }
            .onExitCommand(perform: stopEditing)
            .onChange(of: isNameFocused) { _, focused in
                if !focused { stopEditing() }
            }
    }

    /// `nil` : nouveau dossier.
    private func startEditing(_ folder: Folder?) {
        draft = folder?.name ?? ""
        renaming = folder?.id
        isCreating = folder == nil
        isNameFocused = true
    }

    private func stopEditing() {
        guard renaming != nil || isCreating else { return }
        renaming = nil
        isCreating = false
        onEditEnd()
    }
}

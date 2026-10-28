import SwiftUI

/// Barre de dossiers au-dessus de la saisie : « Tout », les dossiers, puis « + ». Le dossier choisi filtre la liste et
/// reçoit les nouvelles tâches. Appui long sur un dossier : renommer, déplacer, supprimer. Le nom se tape dans une alerte.
struct FolderBar: View {
    let store: TodoStore
    /// `nil` : « Tout ».
    @Binding var selection: Folder.ID?
    /// « Supprimer le dossier » : la liste le supprime et propose d'annuler.
    let onDelete: (Folder) -> Void

    /// Dossier qu'on renomme ; `nil` pendant la saisie d'un nom : nouveau dossier.
    @State private var renaming: Folder?
    @State private var isNaming = false
    @State private var draft = ""

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Layout.smallSpacing) {
                chip("Tout", isSelected: selection == nil) { selection = nil }
                ForEach(store.folders) { folder in
                    chip(folder.name, isSelected: selection == folder.id) { selection = folder.id }
                        .contextMenu { menu(for: folder) }
                }
                Button { startNaming(nil) } label: {
                    Image(systemName: "plus")
                        .font(Theme.Typography.touchChip)
                        .frame(width: Theme.Layout.touchTarget, height: Theme.Layout.touchTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.Palette.moustache)
                .accessibilityLabel("Nouveau dossier")
            }
        }
        .alert(renaming == nil ? "Nouveau dossier" : "Renommer le dossier", isPresented: $isNaming) {
            TextField("Nom du dossier", text: $draft)
            Button("Annuler", role: .cancel) {}
            Button(renaming == nil ? "Créer" : "Renommer", action: commitName)
        }
    }

    private func chip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Typography.touchChip)
                .lineLimit(1)
                .foregroundStyle(isSelected ? Theme.Palette.encre : Theme.Palette.moustache)
                .padding(.horizontal, Theme.Layout.touchChipPadding)
                .frame(height: Theme.Layout.touchChipHeight)
                .background(isSelected ? Theme.Palette.coussin : .clear, in: Capsule())
                // Pastille de 32 pt, zone de toucher de 44 pt.
                .frame(minHeight: Theme.Layout.touchTarget)
                .contentShape(Rectangle())
                .contentShape(.contextMenuPreview, Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func menu(for folder: Folder) -> some View {
        let folders = store.folders
        let i = folders.firstIndex(of: folder) ?? 0
        Button { startNaming(folder) } label: {
            Label("Renommer", systemImage: "pencil")
        }
        Button { store.moveFolder(folder.id, to: folders[i - 1].id) } label: {
            Label("Vers la gauche", systemImage: "arrow.left")
        }
        .disabled(i == 0)
        Button { store.moveFolder(folder.id, to: folders[i + 1].id) } label: {
            Label("Vers la droite", systemImage: "arrow.right")
        }
        .disabled(i >= folders.count - 1)
        Divider()
        Button(role: .destructive) { onDelete(folder) } label: {
            Label("Supprimer le dossier", systemImage: "trash")
        }
    }

    /// `nil` : nouveau dossier.
    private func startNaming(_ folder: Folder?) {
        renaming = folder
        draft = folder?.name ?? ""
        isNaming = true
    }

    /// Le store ignore un nom vide ou déjà pris ; un nouveau dossier devient le dossier choisi.
    private func commitName() {
        if let renaming {
            store.renameFolder(renaming.id, to: draft)
        } else if let id = store.addFolder(draft) {
            selection = id
        }
    }
}

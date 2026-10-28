import SwiftUI
import UniformTypeIdentifiers

/// Écran principal : les tâches à faire, un rond pour les faire tomber, la saisie en bas, au-dessus du clavier,
/// et en haut le bouton de synchronisation avec le Mac.
struct TodoListView: View {
    let store: TodoStore
    let sync: FolderSync
    @State private var text = ""
    @State private var isPickingFolder = false
    @State private var isFolderRefused = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        List(store.todos) { item in
            HStack(spacing: Theme.Layout.rowContentSpacing) {
                Button { store.complete(item.id) } label: {
                    Circle()
                        .strokeBorder(Theme.Palette.moustache, lineWidth: Theme.Layout.pawPadStroke)
                        .frame(width: Theme.Layout.pawPadDiameter, height: Theme.Layout.pawPadDiameter)
                        .frame(width: Theme.Layout.touchTarget, height: Theme.Layout.touchTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Faire tomber « \(item.title) »")
                Text(item.title)
                    .font(Theme.Typography.task)
                    .foregroundStyle(Theme.Palette.encre)
            }
            .listRowBackground(Theme.Palette.creme)
            .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable { sync.check() }
        .overlay {
            if store.todos.isEmpty { EmptyState(allDone: !store.done.isEmpty) }
        }
        .safeAreaInset(edge: .top) { syncBar }
        .safeAreaInset(edge: .bottom) { input }
        .background(Theme.Palette.creme)
        .fontDesign(.rounded)
        .fileImporter(isPresented: $isPickingFolder, allowedContentTypes: [.folder]) { result in
            if case .success(let folder) = result, !sync.attach(folder) { isFolderRefused = true }
        }
        .alert("Ce dossier ne peut pas être utilisé", isPresented: $isFolderRefused) {
            Button("OK") {}
        } message: {
            Text("Choisis le dossier Doneko dans iCloud Drive.")
        }
    }

    private var syncBar: some View {
        HStack {
            Spacer()
            if let name = sync.folderName {
                Menu {
                    Text("Synchronisé avec « \(name) »")
                    Button("Arrêter la synchronisation") { sync.detach() }
                } label: {
                    syncIcon("checkmark.icloud")
                }
                .accessibilityLabel("Synchronisé avec « \(name) »")
            } else {
                Button { isPickingFolder = true } label: {
                    syncIcon("icloud")
                }
                .accessibilityLabel("Synchroniser avec le Mac")
            }
        }
        .padding(.horizontal, Theme.Layout.panelPadding)
        .background(Theme.Palette.creme)
    }

    private func syncIcon(_ name: String) -> some View {
        Image(systemName: name)
            .foregroundStyle(Theme.Palette.moustache)
            .frame(width: Theme.Layout.touchTarget, height: Theme.Layout.touchTarget)
    }

    private var input: some View {
        TextField(
            "Nouvelle tâche",
            text: $text,
            prompt: Text("Qu'est-ce qu'on fait tomber aujourd'hui ?").foregroundStyle(Theme.Palette.moustache)
        )
        .font(Theme.Typography.input)
        .foregroundStyle(Theme.Palette.encre)
        .focused($isInputFocused)
        .padding(.horizontal, Theme.Layout.rowHorizontalPadding)
        .frame(height: Theme.Layout.touchTarget)
        .background(Theme.Palette.coussin, in: RoundedRectangle(cornerRadius: Theme.Layout.rowCornerRadius))
        .padding(Theme.Layout.panelPadding)
        .background(Theme.Palette.creme)
        .onSubmit {
            store.add(text)
            text = ""
            // Retour garde le clavier ouvert pour enchaîner les tâches.
            isInputFocused = true
        }
    }
}

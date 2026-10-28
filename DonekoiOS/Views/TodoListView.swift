import SwiftUI
import UniformTypeIdentifiers

/// Écran principal : en haut, le bouton de synchronisation avec le Mac ; puis « Aujourd'hui », « Plus tard » et
/// « Tombé aujourd'hui » ; en bas, au-dessus du clavier, le toast d'annulation, la barre de dossiers et la saisie.
struct TodoListView: View {
    let store: TodoStore
    let sync: FolderSync

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(SettingsKey.selectedFolder) private var selectedFolderID = ""
    @AppStorage("doneSectionExpanded") private var isDoneExpanded = true
    @State private var text = ""
    @State private var toast: Toast?
    @State private var isPickingFolder = false
    @State private var isFolderRefused = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        let today = store.today(in: folder)
        let later = store.later(in: folder)
        let done = store.done(in: folder)
        List {
            // Sans tâche pour plus tard, pas de titres : une seule liste.
            if !later.isEmpty {
                sectionTitle("Aujourd'hui")
            }
            if today.isEmpty {
                // Liste entièrement vide : la mascotte est au centre de l'écran, pas en ligne.
                if !later.isEmpty || !done.isEmpty {
                    EmptyState(allDone: !done.isEmpty, font: Theme.Typography.touchCaption)
                        .plainRow()
                }
            } else {
                rows(today)
            }
            if !later.isEmpty {
                sectionTitle("Plus tard")
                rows(later, showsDueDate: true)
            }
            if !done.isEmpty {
                doneSection(done)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .refreshable { sync.check() }
        .overlay {
            if today.isEmpty, later.isEmpty, done.isEmpty {
                EmptyState(allDone: false, font: Theme.Typography.touchCaption)
            }
        }
        .safeAreaInset(edge: .top) { syncBar }
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
        .background(Theme.Palette.creme)
        .fontDesign(.rounded)
        .task(id: toast) {
            guard toast != nil else { return }
            try? await Task.sleep(for: .seconds(Theme.Motion.undoToastDuration))
            withAnimation(motion(.easeOut(duration: Theme.Motion.reducedMotionFade))) { toast = nil }
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

    /// Dossier choisi dans la barre, mémorisé sur cet iPhone ; supprimé entre-temps (ou « Tout ») : `nil`.
    private var folder: Folder.ID? {
        store.folders.first { $0.id.uuidString == selectedFolderID }?.id
    }

    private var folderSelection: Binding<Folder.ID?> {
        Binding { folder } set: { selectedFolderID = $0?.uuidString ?? "" }
    }

    private func rows(_ items: [TodoItem], showsDueDate: Bool = false) -> some View {
        ForEach(items) { item in
            TodoRow(
                item: item,
                showsDueDate: showsDueDate,
                folderName: folder == nil ? store.folder(of: item)?.name : nil,
                folders: store.folders,
                onFile: { target in animate { store.file(item.id, in: target) } },
                onPriority: { isPriority in animate { store.setPriority(item.id, isPriority) } },
                onComplete: { complete(item.id) },
                onEdit: { title in
                    store.edit(item.id, title: title)
                    // Le toast annulerait désormais la modification, pas la chute : on le retire.
                    toast = nil
                },
                onDelete: { delete(item.id) }
            )
            .plainRow()
            .accessibilityAction(named: "Monter") { reorder(item.id, in: items, by: -1) }
            .accessibilityAction(named: "Descendre") { reorder(item.id, in: items, by: 1) }
        }
        // Appui long puis glisser : la tâche change de place dans sa section.
        .onMove { from, to in
            guard let i = from.first else { return }
            // `to` compte encore la ligne déplacée : vers le bas, elle prend la place de celle juste avant.
            store.move(items[i].id, to: items[to > i ? to - 1 : to].id)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .textCase(.uppercase)
            .tracking(Theme.Typography.sectionTitleTracking)
            .sectionTitleStyle()
            .accessibilityAddTraits(.isHeader)
            .plainRow()
    }

    /// « Tombé aujourd'hui (3) », repliable. Toucher le rond coché remet la tâche sur la table.
    @ViewBuilder
    private func doneSection(_ items: [TodoItem]) -> some View {
        Button {
            animate { isDoneExpanded.toggle() }
        } label: {
            HStack(spacing: Theme.Layout.smallSpacing) {
                Image(systemName: "chevron.right")
                    .rotationEffect(isDoneExpanded ? .degrees(90) : .zero)
                Text("Tombé aujourd'hui (\(items.count))")
                    .textCase(.uppercase)
                    .tracking(Theme.Typography.sectionTitleTracking)
            }
            .sectionTitleStyle()
            .frame(maxWidth: .infinity, minHeight: Theme.Layout.touchTarget, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Tombé aujourd'hui, \(items.count) \(items.count == 1 ? "tâche" : "tâches")")
        .accessibilityValue(isDoneExpanded ? "Déplié" : "Replié")
        .plainRow()

        if isDoneExpanded {
            ForEach(items) { item in
                HStack(spacing: 0) {
                    Button { uncomplete(item.id) } label: {
                        PawPad(isChecked: true, diameter: Theme.Layout.touchPawPadDiameter)
                            .frame(width: Theme.Layout.touchTarget, height: Theme.Layout.touchTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Text(item.title)
                        .font(Theme.Typography.touchBody)
                        .foregroundStyle(Theme.Palette.moustache)
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Fait : \(item.title)")
                .accessibilityAction(named: "Remettre sur la table") { uncomplete(item.id) }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) { delete(item.id) } label: {
                        Label("Supprimer", systemImage: "trash")
                    }
                }
                .plainRow()
            }
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

    /// À portée de pouce : le toast, les dossiers (où ira la tâche tapée), puis le champ.
    private var bottomBar: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let toast {
                UndoToast(toast: toast, font: Theme.Typography.touchCaption, height: Theme.Layout.touchTarget, onUndo: undo)
                    .padding(.bottom, Theme.Layout.smallSpacing)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
            FolderBar(store: store, selection: folderSelection, onDelete: deleteFolder)
            input
        }
        .padding([.horizontal, .bottom], Theme.Layout.panelPadding)
        .background(Theme.Palette.creme)
    }

    private var input: some View {
        TextField(
            "Nouvelle tâche",
            text: $text,
            prompt: Text("Qu'est-ce qu'on fait tomber aujourd'hui ?").foregroundStyle(Theme.Palette.moustache)
        )
        .font(Theme.Typography.touchBody)
        .foregroundStyle(Theme.Palette.encre)
        .focused($isInputFocused)
        .submitLabel(.send)
        .padding(.horizontal, Theme.Layout.panelPadding)
        .frame(minHeight: Theme.Layout.touchTarget)
        .background(Theme.Palette.coussin, in: RoundedRectangle(cornerRadius: Theme.Layout.rowCornerRadius))
        .onSubmit {
            withAnimation(motion(.easeOut(duration: Theme.Motion.rowAppear))) { store.add(text, in: folder) }
            text = ""
            // Retour garde le clavier ouvert pour enchaîner les tâches.
            isInputFocused = true
        }
    }

    private func complete(_ id: TodoItem.ID) {
        // Les lignes suivantes remontent combler la place.
        animate {
            store.complete(id)
            toast = Toast(message: "Doneko l'a fait tomber")
        }
    }

    private func uncomplete(_ id: TodoItem.ID) {
        animate {
            store.uncomplete(id)
            toast = nil
        }
    }

    private func delete(_ id: TodoItem.ID) {
        animate {
            store.delete(id)
            toast = Toast(message: "Tâche supprimée")
        }
    }

    private func undo() {
        animate {
            store.undo()
            toast = nil
        }
    }

    private func deleteFolder(_ deleted: Folder) {
        animate {
            store.deleteFolder(deleted.id)
            toast = Toast(message: "Dossier supprimé")
        }
    }

    /// VoiceOver : même effet qu'un appui long puis glisser sur la ligne voisine.
    private func reorder(_ id: TodoItem.ID, in items: [TodoItem], by delta: Int) {
        guard let i = items.firstIndex(where: { $0.id == id }), items.indices.contains(i + delta) else { return }
        animate { store.move(id, to: items[i + delta].id) }
    }

    /// Ressort doux des lignes qui bougent ; fondu de 150 ms si « Réduire les animations » est activé.
    private func animate(_ change: () -> Void) {
        withAnimation(motion(.spring(duration: Theme.Motion.closeGap, bounce: Theme.Motion.springBounce)), change)
    }

    private func motion(_ animation: Animation) -> Animation {
        reduceMotion ? .easeOut(duration: Theme.Motion.reducedMotionFade) : animation
    }
}

private extension View {
    /// Ligne sur le fond Crème, sans séparateur, alignée sur le bord du champ de saisie.
    func plainRow() -> some View {
        listRowBackground(Theme.Palette.creme)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(
                top: 0, leading: Theme.Layout.smallSpacing, bottom: 0, trailing: Theme.Layout.panelPadding
            ))
    }

    /// Titres de section : petites capitales Moustache, alignées sur le rond des lignes.
    func sectionTitleStyle() -> some View {
        font(Theme.Typography.touchSectionTitle)
            .foregroundStyle(Theme.Palette.moustache)
            .padding(.leading, (Theme.Layout.touchTarget - Theme.Layout.touchPawPadDiameter) / 2)
    }
}

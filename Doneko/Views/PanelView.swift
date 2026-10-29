import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Champ de saisie → barre de dossiers → tâches à faire → « Tombé aujourd'hui » → barre basse.
/// Le calendrier « Pour quand ? » prend la place des tâches le temps de choisir une date.
struct PanelView: View {
    let store: TodoStore
    /// Ferme le panneau (Échap).
    let close: () -> Void
    /// Bouton ⚙︎ : fenêtre « Réglages ».
    let openSettings: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(SettingsKey.selectedFolder) private var selectedFolderID = ""
    @State private var newTitle = ""
    @State private var toast: Toast?
    @State private var selection: TodoItem.ID?
    @State private var knockOffRequest: KnockOffRequest?
    /// Date choisie au calendrier pour la prochaine tâche, et calendrier ouvert (pour elle ou pour une tâche).
    @State private var pickedDate: Date?
    @State private var datePicking: DatePicking?
    /// Tâche attrapée par glisser-déposer.
    @State private var draggedID: TodoItem.ID?
    @State private var listHeight: CGFloat = 0
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Layout.panelPadding) {
            InputField(
                text: $newTitle,
                isFocused: $isInputFocused,
                dueDate: pickedDate,
                isPickingDate: datePicking == .newTask,
                onCalendar: { togglePicking(.newTask) },
                onSubmit: { title in
                    withAnimation(motion(.spring(duration: Theme.Motion.rowAppear, bounce: Theme.Motion.settleBounce))) {
                        store.add(title, in: folder, due: pickedDate)
                    }
                    pickedDate = nil
                    datePicking = nil
                },
                onListKey: handleListKey
            )

            FolderBar(store: store, selection: folderSelection, onDelete: deleteFolder) {
                isInputFocused = true
            }

            if let datePicking {
                datePanel(datePicking)
            } else {
                // Hauteur au contenu, puis défilement une fois le maximum atteint. Hauteur explicite : MenuBarExtra
                // mesure le panneau en partant de 0, et une zone de défilement sans hauteur s'y écrase à 0.
                ScrollViewReader { proxy in
                    ScrollView {
                        lists.onGeometryChange(for: CGFloat.self) { $0.size.height } action: { listHeight = $0 }
                    }
                    .frame(height: min(listHeight, Theme.Layout.listMaxHeight))
                    .onChange(of: selection) { _, id in
                        if let id { proxy.scrollTo(id) }
                    }
                }
            }

            // Quitter : clic droit sur l'icône de la barre de menu, ou ⌘Q.
            Button(action: openSettings) {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.pressable)
            .foregroundStyle(Theme.Palette.moustache)
            .accessibilityLabel("Réglages")
        }
        .padding(Theme.Layout.panelPadding)
        // Raccourcis invisibles : la fenêtre les reçoit avant le menu Édition (⌘Z) et quel que soit le focus (Échap, ⌘Q).
        .background {
            Group {
                // Champ non vide : désactivé, ⌘Z garde son sens habituel (annuler la frappe).
                Button("Annuler", action: undo)
                    .keyboardShortcut("z")
                    .disabled(!newTitle.isEmpty)
                // Calendrier ouvert : Échap le referme, sans fermer le panneau.
                Button("Fermer") {
                    if datePicking != nil { togglePicking(datePicking) } else { close() }
                }
                .keyboardShortcut(.cancelAction)
                Button("Quitter") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q")
                // ⌘1 : « Tout » ; ⌘2 à ⌘9 : les dossiers, dans l'ordre de la barre.
                ForEach(1...9, id: \.self) { n in
                    Button("Dossier \(n)") { selectFolder(number: n) }
                        .keyboardShortcut(KeyEquivalent(Character(String(n))))
                }
            }
            .opacity(0)
            .accessibilityHidden(true)
        }
        .overlay(alignment: .bottom) {
            if let toast {
                UndoToast(toast: toast, onUndo: undo)
                    .padding(Theme.Layout.panelPadding)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
        .task(id: toast) {
            guard toast != nil else { return }
            try? await Task.sleep(for: .seconds(Theme.Motion.undoToastDuration))
            withAnimation(motion(.easeOut(duration: Theme.Motion.reducedMotionFade))) { toast = nil }
        }
        // Le curseur est dans le champ à chaque ouverture du panneau.
        .onAppear(perform: focusInput)
        .background(OnHostWindowBecomeKey { window in
            // Un champ a déjà le curseur (saisie ou modification d'une tâche) : ne rien lui voler.
            guard !(window.firstResponder is NSTextView) else { return }
            focusInput()
        })
        // Dès qu'on tape, les touches servent à la frappe : plus de tâche sélectionnée.
        .onChange(of: newTitle) { _, title in
            if !title.isEmpty { selection = nil }
        }
        .frame(width: Theme.Layout.panelWidth)
        .frame(maxHeight: Theme.Layout.panelMaxHeight)
        .background { PanelBackground() }
        .clipShape(RoundedRectangle(cornerRadius: Theme.Layout.panelCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Layout.panelCornerRadius)
                .strokeBorder(Theme.Palette.encre.opacity(Theme.Layout.panelEdgeOpacity), lineWidth: Theme.Layout.panelEdgeWidth)
        }
        .fontDesign(.rounded)
    }

    /// Dossier choisi dans la barre, mémorisé sur ce Mac ; supprimé entre-temps (ou « Tout ») : `nil`.
    private var folder: Folder.ID? {
        store.folders.first { $0.id.uuidString == selectedFolderID }?.id
    }

    private var folderSelection: Binding<Folder.ID?> {
        Binding {
            folder
        } set: { id in
            selectedFolderID = id?.uuidString ?? ""
            selection = nil
        }
    }

    private var lists: some View {
        VStack(alignment: .leading, spacing: Theme.Layout.rowSpacing) {
            let today = store.today(in: folder)
            let later = store.later(in: folder)
            let done = store.done(in: folder)
            // Sans tâche pour plus tard, pas de titres : une seule liste.
            if !later.isEmpty {
                SectionTitle(title: "Aujourd'hui")
            }
            if today.isEmpty {
                EmptyState(allDone: !done.isEmpty)
                    // Liste vide : une tâche faite glissée ici revient quand même.
                    .onDrop(of: [.donekoTask], delegate: ReorderDropDelegate(draggedID: $draggedID, onEnter: uncomplete))
            } else {
                rows(today)
            }
            if !later.isEmpty {
                SectionTitle(title: "Plus tard")
                    .padding(.top, Theme.Layout.panelPadding)
                rows(later, showsDueDate: true)
            }
            if !done.isEmpty {
                DoneSection(items: done, onUncomplete: uncomplete, onDelete: delete, onDrag: dragProvider)
                    .padding(.top, Theme.Layout.panelPadding)
            }
        }
    }

    private func rows(_ items: [TodoItem], showsDueDate: Bool = false) -> some View {
        ForEach(items) { item in
            TodoRow(
                item: item,
                isSelected: item.id == selection,
                showsDueDate: showsDueDate,
                folderName: folder == nil ? store.folder(of: item)?.name : nil,
                folders: store.folders,
                onFile: { file(item.id, in: $0) },
                onPickDate: { togglePicking(.task(item.id)) },
                knockOffRequest: knockOffRequest,
                onComplete: { complete(item) },
                onEditEnd: { title in
                    if let title {
                        store.edit(item.id, title: title)
                        // Le toast annulerait désormais la modification, pas la chute : on le retire.
                        toast = nil
                    }
                    isInputFocused = true
                },
                onDelete: { delete(item.id) }
            )
            // Glisser-déposer : la liste se réordonne en direct au passage sur chaque ligne.
            .onDrag { dragProvider(item.id) }
            .onDrop(of: [.donekoTask], delegate: ReorderDropDelegate(draggedID: $draggedID) { id in
                guard id != item.id else { return }
                // Une tâche faite qui revient : le toast annulerait ce retour, pas la dernière action affichée.
                if store.done.contains(where: { $0.id == id }) { toast = nil }
                withAnimation(motion(.spring(duration: Theme.Motion.closeGap, bounce: Theme.Motion.settleBounce))) {
                    store.move(id, to: item.id)
                }
            })
            .accessibilityAction(named: "Monter") { reorder(item.id, in: items, by: -1) }
            .accessibilityAction(named: "Descendre") { reorder(item.id, in: items, by: 1) }
            .transition(
                reduceMotion
                    ? .opacity
                    : .asymmetric(
                        insertion: .offset(y: -Theme.Motion.rowAppearOffset).combined(with: .opacity),
                        removal: .identity
                    )
            )
        }
    }

    /// ↑/↓ naviguer, Espace faire tomber, ⌫ supprimer (⌘Z et Échap : raccourcis du panneau).
    private func handleListKey(_ press: KeyPress) -> KeyPress.Result {
        switch press.key {
        case .downArrow:
            moveSelection(by: 1)
        case .upArrow:
            moveSelection(by: -1)
        case .space:
            guard let selection else { return .ignored }
            knockOffRequest = KnockOffRequest(id: selection)
        // La touche ⌫ du Mac envoie U+007F, que ni .delete (U+0008) ni .deleteForward (U+F728) ne couvrent.
        case .delete, .deleteForward, KeyEquivalent("\u{7F}"):
            guard let selection else { return .ignored }
            delete(selection)
        default:
            return .ignored
        }
        return .handled
    }

    private func moveSelection(by delta: Int) {
        let ids = store.todos(in: folder).map(\.id)
        guard let current = selection, let index = ids.firstIndex(of: current) else {
            if delta > 0 { selection = ids.first }
            return
        }
        let next = index + delta
        // ↑ sur la première tâche : plus de sélection, retour à la saisie.
        selection = next < 0 ? nil : ids[min(next, ids.count - 1)]
    }

    /// La tâche qui va disparaître cède la sélection à sa voisine (suivante, sinon précédente).
    private func selectNeighbor(of id: TodoItem.ID) {
        guard selection == id else { return }
        let ids = store.todos(in: folder).map(\.id)
        guard let index = ids.firstIndex(of: id) else { return }
        if index + 1 < ids.count {
            selection = ids[index + 1]
        } else if index > 0 {
            selection = ids[index - 1]
        } else {
            selection = nil
        }
    }

    private func complete(_ item: TodoItem) {
        selectNeighbor(of: item.id)
        // Les lignes suivantes remontent combler la place.
        withAnimation(motion(.spring(duration: Theme.Motion.closeGap, bounce: Theme.Motion.settleBounce))) {
            store.complete(item.id)
            toast = Toast(message: "Doneko l'a fait tomber")
        }
    }

    private func uncomplete(_ id: TodoItem.ID) {
        withAnimation(motion(.spring(duration: Theme.Motion.closeGap, bounce: Theme.Motion.settleBounce))) {
            store.uncomplete(id)
            toast = nil
        }
    }

    /// VoiceOver : même effet qu'un glisser-déposer sur la ligne voisine.
    private func reorder(_ id: TodoItem.ID, in items: [TodoItem], by delta: Int) {
        guard let i = items.firstIndex(where: { $0.id == id }), items.indices.contains(i + delta) else { return }
        withAnimation(motion(.spring(duration: Theme.Motion.closeGap, bounce: Theme.Motion.settleBounce))) {
            store.move(id, to: items[i + delta].id)
        }
    }

    /// Type propre à Doneko, réservé à l'app : ni le champ ni une autre app ne reçoivent de texte.
    private func dragProvider(_ id: TodoItem.ID) -> NSItemProvider {
        draggedID = id
        let provider = NSItemProvider()
        provider.registerDataRepresentation(forTypeIdentifier: UTType.donekoTask.identifier, visibility: .ownProcess) { done in
            done(Data(id.uuidString.utf8), nil)
            return nil
        }
        return provider
    }

    private func delete(_ id: TodoItem.ID) {
        selectNeighbor(of: id)
        withAnimation(motion(.spring(duration: Theme.Motion.closeGap, bounce: Theme.Motion.settleBounce))) {
            store.delete(id)
            toast = Toast(message: "Tâche supprimée")
        }
    }

    private func undo() {
        withAnimation(motion(.spring(duration: Theme.Motion.closeGap, bounce: Theme.Motion.settleBounce))) {
            store.undo()
            toast = nil
        }
    }

    /// « Pour quand ? » à la place des tâches : un clic sur un jour le choisit et referme le calendrier.
    private func datePanel(_ picking: DatePicking) -> some View {
        let task: TodoItem? = if case .task(let id) = picking { store.todos.first { $0.id == id } } else { nil }
        let current = task.map(\.dueDate) ?? pickedDate
        return VStack(alignment: .leading, spacing: Theme.Layout.smallSpacing) {
            SectionTitle(title: "Pour quand ?")
            if let task {
                Text(task.title)
                    .font(Theme.Typography.task)
                    .foregroundStyle(Theme.Palette.encre)
                    .lineLimit(1)
                    .padding(.horizontal, Theme.Layout.rowHorizontalPadding)
            }
            DueDatePicker(selection: current, today: store.currentDay) { pick($0, for: picking) }
                .frame(maxWidth: .infinity)
            HStack {
                Button("Sans échéance") { pick(nil, for: picking) }
                    .disabled(current == nil)
                Spacer()
                // Valide le jour sélectionné (aujourd'hui s'il n'y avait pas de date) ; Échap annule.
                Button("OK") { pick(current ?? store.currentDay, for: picking) }
            }
            .buttonStyle(.plain)
            .font(Theme.Typography.caption)
            .foregroundStyle(Theme.Palette.moustache)
            .padding(.horizontal, Theme.Layout.rowHorizontalPadding)
        }
    }

    /// Ouvre le calendrier pour `picking`, ou le referme s'il l'est déjà ; le curseur revient dans le champ.
    private func togglePicking(_ picking: DatePicking?) {
        datePicking = datePicking == picking ? nil : picking
        selection = nil
        isInputFocused = true
    }

    private func pick(_ date: Date?, for picking: DatePicking) {
        switch picking {
        case .newTask:
            pickedDate = date
        case .task(let id):
            withAnimation(motion(.spring(duration: Theme.Motion.closeGap, bounce: Theme.Motion.settleBounce))) {
                store.setDueDate(id, date)
            }
        }
        togglePicking(picking)
    }

    /// « Ranger dans » : rangée ailleurs, la tâche quitte la liste du dossier affiché.
    private func file(_ id: TodoItem.ID, in target: Folder.ID?) {
        if target != folder { selectNeighbor(of: id) }
        withAnimation(motion(.spring(duration: Theme.Motion.closeGap, bounce: Theme.Motion.settleBounce))) {
            store.file(id, in: target)
        }
    }

    private func deleteFolder(_ deleted: Folder) {
        withAnimation(motion(.spring(duration: Theme.Motion.closeGap, bounce: Theme.Motion.settleBounce))) {
            store.deleteFolder(deleted.id)
            toast = Toast(message: "Dossier supprimé")
        }
    }

    /// ⌘1 : « Tout » ; ⌘2 à ⌘9 : le dossier à cette place, s'il existe.
    private func selectFolder(number: Int) {
        if number == 1 {
            folderSelection.wrappedValue = nil
        } else if store.folders.indices.contains(number - 2) {
            folderSelection.wrappedValue = store.folders[number - 2].id
        }
    }

    /// Repasse par false : redemander true alors que l'état vaut déjà true (posé avant que la fenêtre
    /// soit active) ne redonne pas le focus au champ.
    private func focusInput() {
        isInputFocused = false
        DispatchQueue.main.async { isInputFocused = true }
    }

    /// « Réduire les animations » : tout mouvement devient un fondu de 150 ms.
    private func motion(_ animation: Animation) -> Animation {
        reduceMotion ? .easeOut(duration: Theme.Motion.reducedMotionFade) : animation
    }
}

private extension UTType {
    /// Tâche glissée dans le panneau (déclarée dans Info.plist).
    static let donekoTask = UTType(exportedAs: "com.nathanmarchant.doneko.task")
}

/// Glisser-déposer interne : agit dès le survol (la tâche prend la place de la ligne), sans attendre le lâcher.
private struct ReorderDropDelegate: DropDelegate {
    @Binding var draggedID: TodoItem.ID?
    let onEnter: (TodoItem.ID) -> Void

    func dropEntered(info: DropInfo) {
        if let draggedID { onEnter(draggedID) }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedID = nil
        return true
    }
}

/// Appelle `action` quand la fenêtre qui héberge la vue devient active (ouverture du panneau),
/// et seulement elle : écouter toutes les fenêtres ferait réagir le panneau caché à celles des autres.
private struct OnHostWindowBecomeKey: NSViewRepresentable {
    let action: (NSWindow) -> Void

    func makeNSView(context: Context) -> ObserverView { ObserverView() }
    func updateNSView(_ view: ObserverView, context: Context) { view.action = action }

    final class ObserverView: NSView {
        var action: (NSWindow) -> Void = { _ in }
        private var observer: NSObjectProtocol?

        override func viewDidMoveToWindow() {
            if let observer { NotificationCenter.default.removeObserver(observer) }
            observer = window.map { window in
                NotificationCenter.default.addObserver(
                    forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main
                ) { [weak self] _ in self?.action(window) }
            }
        }
    }
}

/// Matière des panneaux de la barre de menu (comme le Centre de contrôle), teintée de Crème : le bureau transparaît à
/// peine. « Réduire la transparence » : Crème plein.
private struct PanelBackground: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        if reduceTransparency {
            Theme.Palette.creme
        } else {
            VisualEffect().overlay(Theme.Palette.creme.opacity(Theme.Layout.panelTintOpacity))
        }
    }

    private struct VisualEffect: NSViewRepresentable {
        func makeNSView(context: Context) -> NSVisualEffectView {
            let view = NSVisualEffectView()
            view.material = .popover
            view.blendingMode = .behindWindow
            // Active même quand le panneau n'a pas le focus : la matière ne vire pas au gris.
            view.state = .active
            return view
        }

        func updateNSView(_ view: NSVisualEffectView, context: Context) {}
    }
}

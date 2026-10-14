import AppKit
import SwiftUI

/// Champ de saisie → tâches à faire → « Tombé aujourd'hui » → barre basse.
struct PanelView: View {
    let store: TodoStore
    /// Ferme le panneau (Échap).
    let close: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var newTitle = ""
    @State private var toast: Toast?
    @State private var selection: TodoItem.ID?
    @State private var knockOffRequest: KnockOffRequest?
    @State private var listHeight: CGFloat = 0
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Layout.panelPadding) {
            InputField(
                text: $newTitle,
                isFocused: $isInputFocused,
                onSubmit: { title in
                    withAnimation(motion(.easeOut(duration: Theme.Motion.rowAppear))) { store.add(title) }
                },
                onListKey: handleListKey
            )

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

            HStack {
                Menu {
                    Toggle("Lancer au démarrage", isOn: Binding(get: { LaunchAtLogin.isEnabled }, set: { LaunchAtLogin.set($0) }))
                } label: {
                    Image(systemName: "gearshape")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .foregroundStyle(Theme.Palette.moustache)
                .accessibilityLabel("Réglages")
                Spacer()
                Button("Laisser Doneko dormir (Quitter)") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.moustache)
                    .keyboardShortcut("q")
            }
        }
        .padding(Theme.Layout.panelPadding)
        // Raccourcis invisibles : la fenêtre les reçoit avant le menu Édition (⌘Z) et quel que soit le focus (Échap).
        .background {
            Group {
                // Champ non vide : désactivé, ⌘Z garde son sens habituel (annuler la frappe).
                Button("Annuler", action: undo)
                    .keyboardShortcut("z")
                    .disabled(!newTitle.isEmpty)
                Button("Fermer", action: close)
                    .keyboardShortcut(.cancelAction)
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
        .background(Theme.Palette.creme, in: RoundedRectangle(cornerRadius: Theme.Layout.panelCornerRadius))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Layout.panelCornerRadius))
        .fontDesign(.rounded)
    }

    private var lists: some View {
        VStack(alignment: .leading, spacing: Theme.Layout.rowSpacing) {
            if store.todos.isEmpty {
                EmptyState(allDone: !store.done.isEmpty)
            } else {
                ForEach(store.todos) { item in
                    TodoRow(
                        item: item,
                        isSelected: item.id == selection,
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
            if !store.done.isEmpty {
                DoneSection(items: store.done, onDelete: delete)
                    .padding(.top, Theme.Layout.panelPadding)
            }
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
        let ids = store.todos.map(\.id)
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
        let ids = store.todos.map(\.id)
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
        withAnimation(motion(.spring(duration: Theme.Motion.closeGap, bounce: Theme.Motion.springBounce))) {
            store.complete(item.id)
            toast = Toast(message: "Doneko l'a fait tomber")
        }
    }

    private func delete(_ id: TodoItem.ID) {
        selectNeighbor(of: id)
        withAnimation(motion(.spring(duration: Theme.Motion.closeGap, bounce: Theme.Motion.springBounce))) {
            store.delete(id)
            toast = Toast(message: "Tâche supprimée")
        }
    }

    private func undo() {
        withAnimation(motion(.spring(duration: Theme.Motion.closeGap, bounce: Theme.Motion.springBounce))) {
            store.undo()
            toast = nil
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

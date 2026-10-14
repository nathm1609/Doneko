import AppKit
import SwiftUI

/// Champ de saisie → tâches à faire → « Tombé aujourd'hui » → barre basse.
struct PanelView: View {
    let store: TodoStore

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var toast: Toast?
    @State private var selection: TodoItem.ID?
    @State private var knockOffRequest: KnockOffRequest?
    @FocusState private var isInputFocused: Bool
    @FocusState private var isListFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Layout.panelPadding) {
            InputField(
                isFocused: $isInputFocused,
                onSubmit: { title in
                    withAnimation(motion(.easeOut(duration: Theme.Motion.rowAppear))) { store.add(title) }
                },
                onArrowDown: {
                    guard let first = store.todos.first else { return }
                    selection = first.id
                    isListFocused = true
                },
                onUndo: undo
            )

            // Hauteur au contenu, puis défilement une fois le maximum atteint.
            ViewThatFits(in: .vertical) {
                lists
                ScrollViewReader { proxy in
                    ScrollView { lists }
                        .onChange(of: selection) { _, id in
                            if let id { proxy.scrollTo(id) }
                        }
                }
            }
            .focusable()
            .focusEffectDisabled() // la ligne sélectionnée (fond Coussin) sert d'indicateur
            .focused($isListFocused)
            .onChange(of: isListFocused) { _, focused in
                selection = focused ? (selection ?? store.todos.first?.id) : nil
            }
            .onKeyPress(.upArrow) {
                moveSelection(by: -1)
                return .handled
            }
            .onKeyPress(.downArrow) {
                moveSelection(by: 1)
                return .handled
            }
            .onKeyPress(.space) {
                guard let selection else { return .ignored }
                knockOffRequest = KnockOffRequest(id: selection)
                return .handled
            }
            .onKeyPress(.delete) {
                guard let selection else { return .ignored }
                delete(selection)
                return .handled
            }
            .onKeyPress(keys: ["z"]) { press in
                guard press.modifiers == .command else { return .ignored }
                undo()
                return .handled
            }

            HStack {
                Spacer()
                Button("Laisser Doneko dormir (Quitter)") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.moustache)
                    .keyboardShortcut("q")
            }
        }
        .padding(Theme.Layout.panelPadding)
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
        // Échap ferme le panneau (sauf pendant la modification d'une tâche, qui l'intercepte avant).
        .onExitCommand { NSApp.keyWindow?.close() }
        .frame(width: Theme.Layout.panelWidth)
        .frame(maxHeight: Theme.Layout.panelMaxHeight)
        .background(Theme.Palette.creme)
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
                        onEdit: { title in
                            store.edit(item.id, title: title)
                            // Le toast annulerait désormais la modification, pas la chute : on le retire.
                            toast = nil
                        }
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
                DoneSection(items: store.done)
                    .padding(.top, Theme.Layout.panelPadding)
            }
        }
    }

    private func moveSelection(by delta: Int) {
        let ids = store.todos.map(\.id)
        guard let current = selection, let index = ids.firstIndex(of: current) else {
            selection = ids.first
            return
        }
        let next = index + delta
        if next < 0 {
            // ↑ sur la première tâche : retour au champ de saisie.
            isInputFocused = true
        } else if next < ids.count {
            selection = ids[next]
        }
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
            isInputFocused = true
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

    /// « Réduire les animations » : tout mouvement devient un fondu de 150 ms.
    private func motion(_ animation: Animation) -> Animation {
        reduceMotion ? .easeOut(duration: Theme.Motion.reducedMotionFade) : animation
    }
}

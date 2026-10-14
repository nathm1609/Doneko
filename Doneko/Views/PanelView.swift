import SwiftUI

/// Champ de saisie → tâches à faire → « Tombé aujourd'hui » → barre basse.
struct PanelView: View {
    let store: TodoStore

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var toast: Toast?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Layout.panelPadding) {
            InputField { title in
                withAnimation(motion(.easeOut(duration: Theme.Motion.rowAppear))) { store.add(title) }
            }

            // Hauteur au contenu, puis défilement une fois le maximum atteint.
            ViewThatFits(in: .vertical) {
                lists
                ScrollView { lists }
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

    private func complete(_ item: TodoItem) {
        // Les lignes suivantes remontent combler la place.
        withAnimation(motion(.spring(duration: Theme.Motion.closeGap, bounce: Theme.Motion.springBounce))) {
            store.complete(item.id)
            toast = Toast(message: "Doneko l'a fait tomber")
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

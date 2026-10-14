import SwiftUI

/// Champ de saisie → tâches à faire → « Tombé aujourd'hui » → barre basse.
struct PanelView: View {
    let store: TodoStore

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Layout.panelPadding) {
            InputField { store.add($0) }

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
                        onComplete: { store.complete(item.id) },
                        onEdit: { store.edit(item.id, title: $0) }
                    )
                }
            }
            if !store.done.isEmpty {
                DoneSection(items: store.done)
                    .padding(.top, Theme.Layout.panelPadding)
            }
        }
    }
}

import SwiftUI

struct InputField: View {
    var isFocused: FocusState<Bool>.Binding
    let onSubmit: (String) -> Void
    /// ↓ : passer à la liste.
    let onArrowDown: () -> Void
    /// ⌘Z quand le champ est vide : annuler la dernière action sur les tâches.
    let onUndo: () -> Void

    @State private var text = ""

    var body: some View {
        TextField(
            "Nouvelle tâche",
            text: $text,
            prompt: Text("Qu'est-ce qu'on fait tomber aujourd'hui ?").foregroundStyle(Theme.Palette.moustache)
        )
        .textFieldStyle(.plain)
        .font(Theme.Typography.input)
        .foregroundStyle(Theme.Palette.encre)
        .focused(isFocused)
        .padding(.horizontal, Theme.Layout.rowHorizontalPadding)
        .frame(height: Theme.Layout.rowHeight)
        .background(Theme.Palette.coussin, in: RoundedRectangle(cornerRadius: Theme.Layout.rowCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Layout.rowCornerRadius)
                .strokeBorder(Theme.Palette.mandarine, lineWidth: isFocused.wrappedValue ? Theme.Layout.focusRingWidth : 0)
        }
        // Entrée ajoute la tâche ; le champ garde le focus pour enchaîner.
        .onSubmit {
            onSubmit(text)
            text = ""
        }
        .onKeyPress(.downArrow) {
            onArrowDown()
            return .handled
        }
        // Champ non vide : ⌘Z garde son sens habituel (annuler la frappe).
        .onKeyPress(keys: ["z"]) { press in
            guard press.modifiers == .command, text.isEmpty else { return .ignored }
            onUndo()
            return .handled
        }
        .onAppear { isFocused.wrappedValue = true }
    }
}

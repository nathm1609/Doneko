import SwiftUI

/// Champ de saisie. Il garde le focus en permanence : quand il est vide, il pilote aussi la liste au clavier.
struct InputField: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    let onSubmit: (String) -> Void
    /// ↑ ↓ Espace ⌫, reçues seulement quand le champ est vide (sinon elles servent à la frappe).
    let onListKey: (KeyPress) -> KeyPress.Result

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
        .onKeyPress { press in
            text.isEmpty ? onListKey(press) : .ignored
        }
    }
}

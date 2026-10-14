import SwiftUI

struct InputField: View {
    let onSubmit: (String) -> Void

    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField(
            "Nouvelle tâche",
            text: $text,
            prompt: Text("Qu'est-ce qu'on fait tomber aujourd'hui ?").foregroundStyle(Theme.Palette.moustache)
        )
        .textFieldStyle(.plain)
        .font(Theme.Typography.input)
        .foregroundStyle(Theme.Palette.encre)
        .focused($isFocused)
        .padding(.horizontal, Theme.Layout.rowHorizontalPadding)
        .frame(height: Theme.Layout.rowHeight)
        .background(Theme.Palette.coussin, in: RoundedRectangle(cornerRadius: Theme.Layout.rowCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Layout.rowCornerRadius)
                .strokeBorder(Theme.Palette.mandarine, lineWidth: isFocused ? Theme.Layout.focusRingWidth : 0)
        }
        // Entrée ajoute la tâche ; le champ garde le focus pour enchaîner.
        .onSubmit {
            onSubmit(text)
            text = ""
        }
        .onAppear { isFocused = true }
    }
}

import SwiftUI

/// Champ de saisie. Il garde le focus en permanence : quand il est vide, il pilote aussi la liste au clavier.
/// Au bout, le bouton calendrier (ou la date choisie) ouvre « Pour quand ? ».
struct InputField: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    /// Date choisie au calendrier pour la prochaine tâche.
    let dueDate: Date?
    let isPickingDate: Bool
    let onCalendar: () -> Void
    let onSubmit: (String) -> Void
    /// ↑ ↓ Espace ⌫, reçues seulement quand le champ est vide (sinon elles servent à la frappe).
    let onListKey: (KeyPress) -> KeyPress.Result

    var body: some View {
        HStack(spacing: Theme.Layout.smallSpacing) {
            TextField(
                "Nouvelle tâche",
                text: $text,
                prompt: Text("Qu'est-ce qu'on fait tomber aujourd'hui ?").foregroundStyle(Theme.Palette.moustache)
            )
            .textFieldStyle(.plain)
            .font(Theme.Typography.input)
            .foregroundStyle(Theme.Palette.encre)
            .focused(isFocused)
            // Entrée ajoute la tâche ; le champ garde le focus pour enchaîner.
            .onSubmit {
                onSubmit(text)
                text = ""
            }
            .onKeyPress { press in
                text.isEmpty ? onListKey(press) : .ignored
            }

            Button(action: onCalendar) {
                if let dueDate {
                    Text(dueDate, format: .dueDate)
                        .font(Theme.Typography.caption)
                } else {
                    Image(systemName: "calendar")
                }
            }
            .buttonStyle(.pressable)
            .foregroundStyle(isPickingDate ? Theme.Palette.mandarine : Theme.Palette.moustache)
            .help(dueDate == nil ? "Choisir une date" : "Changer la date")
            .accessibilityLabel(dueDate.map { "Échéance : \($0.formatted(.dueDate))" } ?? "Choisir une date")
        }
        .padding(.horizontal, Theme.Layout.rowHorizontalPadding)
        .frame(height: Theme.Layout.rowHeight)
        .background(Theme.Palette.coussin, in: RoundedRectangle(cornerRadius: Theme.Layout.rowCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Layout.rowCornerRadius)
                .strokeBorder(Theme.Palette.mandarine, lineWidth: isFocused.wrappedValue ? Theme.Layout.focusRingWidth : 0)
        }
    }
}

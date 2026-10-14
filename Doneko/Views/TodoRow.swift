import SwiftUI

struct TodoRow: View {
    let item: TodoItem
    let onComplete: () -> Void
    let onEdit: (String) -> Void

    @State private var isHovered = false
    @State private var isPadHovered = false
    @State private var isEditing = false
    @State private var draft = ""
    @FocusState private var isEditFocused: Bool

    var body: some View {
        HStack(spacing: Theme.Layout.rowContentSpacing) {
            Button(action: onComplete) {
                PawPad(isChecked: false, isHovered: isPadHovered)
            }
            .buttonStyle(.plain)
            .onHover { isPadHovered = $0 }
            .accessibilityLabel("Faire tomber « \(item.title) »")

            if isEditing {
                TextField("Modifier la tâche", text: $draft)
                    .textFieldStyle(.plain)
                    .font(Theme.Typography.task)
                    .foregroundStyle(Theme.Palette.encre)
                    .focused($isEditFocused)
                    .onSubmit {
                        onEdit(draft)
                        isEditing = false
                    }
                    .onExitCommand { isEditing = false }
                    // Clic ailleurs : on abandonne la modification.
                    .onChange(of: isEditFocused) { _, focused in
                        if !focused { isEditing = false }
                    }
            } else {
                Text(item.title)
                    .font(Theme.Typography.task)
                    .foregroundStyle(Theme.Palette.encre)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, Theme.Layout.rowHorizontalPadding)
        .frame(height: Theme.Layout.rowHeight)
        .background(
            isHovered ? Theme.Palette.coussin : .clear,
            in: RoundedRectangle(cornerRadius: Theme.Layout.rowCornerRadius)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture(count: 2, perform: startEditing)
        .accessibilityAction(named: "Modifier", startEditing)
    }

    private func startEditing() {
        guard !isEditing else { return }
        draft = item.title
        isEditing = true
        isEditFocused = true
    }
}

/// Rond « coussinet de patte » : contour Moustache, Mandarine + empreinte au survol, Matcha + coche une fois fait.
struct PawPad: View {
    let isChecked: Bool
    let isHovered: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isChecked ? Theme.Palette.matcha : .clear)
            Circle()
                .strokeBorder(strokeColor, lineWidth: Theme.Layout.pawPadStroke)
            if isChecked {
                Image(systemName: "checkmark")
                    .font(.system(size: Theme.Layout.pawPadGlyphSize, weight: .bold))
                    .foregroundStyle(Theme.Palette.checkmark)
            } else if isHovered {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: Theme.Layout.pawPadGlyphSize))
                    .foregroundStyle(Theme.Palette.mandarine)
            }
        }
        .frame(width: Theme.Layout.pawPadDiameter, height: Theme.Layout.pawPadDiameter)
        .contentShape(Circle())
    }

    private var strokeColor: Color {
        if isChecked { return Theme.Palette.matcha }
        return isHovered ? Theme.Palette.mandarine : Theme.Palette.moustache
    }
}

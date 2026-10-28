import SwiftUI

struct Toast: Identifiable, Equatable {
    let id = UUID()
    let message: String
}

/// « Doneko l'a fait tomber · Annuler », en bas du panneau (Mac) ou au-dessus de la saisie (iPhone, plus grand).
struct UndoToast: View {
    let toast: Toast
    var font = Theme.Typography.caption
    var height = Theme.Layout.rowHeight
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: Theme.Layout.smallSpacing) {
            Text(toast.message)
            Text("·")
                .accessibilityHidden(true)
            Button(action: onUndo) {
                Text("Annuler")
                    .fontWeight(.bold)
                    // Toute la hauteur du toast se touche, pas seulement le mot.
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .font(font)
        .foregroundStyle(Theme.Palette.creme)
        .padding(.horizontal, Theme.Layout.panelPadding)
        .frame(height: height)
        .background(Theme.Palette.encre, in: RoundedRectangle(cornerRadius: Theme.Layout.rowCornerRadius))
        .onAppear { AccessibilityNotification.Announcement(toast.message).post() }
    }
}

import SwiftUI

struct Toast: Identifiable, Equatable {
    let id = UUID()
    let message: String
}

/// « Doneko l'a fait tomber · Annuler », en bas du panneau.
struct UndoToast: View {
    let toast: Toast
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: Theme.Layout.smallSpacing) {
            Text(toast.message)
            Text("·")
                .accessibilityHidden(true)
            Button("Annuler", action: onUndo)
                .buttonStyle(.plain)
                .fontWeight(.bold)
        }
        .font(Theme.Typography.caption)
        .foregroundStyle(Theme.Palette.creme)
        .padding(.horizontal, Theme.Layout.panelPadding)
        .frame(height: Theme.Layout.rowHeight)
        .background(Theme.Palette.encre, in: RoundedRectangle(cornerRadius: Theme.Layout.rowCornerRadius))
        .onAppear { AccessibilityNotification.Announcement(toast.message).post() }
    }
}

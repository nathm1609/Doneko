import SwiftUI

/// Section repliable « Tombé aujourd'hui ».
struct DoneSection: View {
    let items: [TodoItem]
    /// Glissement à deux doigts vers la gauche sur une tâche faite.
    let onDelete: (TodoItem.ID) -> Void

    @AppStorage("doneSectionExpanded") private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Layout.rowSpacing) {
            Button { isExpanded.toggle() } label: {
                HStack(spacing: Theme.Layout.smallSpacing) {
                    Image(systemName: "chevron.right")
                        .rotationEffect(isExpanded ? .degrees(90) : .zero)
                    Text("Tombé aujourd'hui (\(items.count))")
                        .textCase(.uppercase)
                        .tracking(Theme.Typography.sectionTitleTracking)
                }
                .font(Theme.Typography.sectionTitle)
                .foregroundStyle(Theme.Palette.moustache)
                .padding(.horizontal, Theme.Layout.rowHorizontalPadding)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Tombé aujourd'hui, \(items.count) \(items.count == 1 ? "tâche" : "tâches")")
            .accessibilityValue(isExpanded ? "Déplié" : "Replié")

            if isExpanded {
                ForEach(items) { item in
                    HStack(spacing: Theme.Layout.rowContentSpacing) {
                        PawPad(isChecked: true, isHovered: false)
                        Text(item.title)
                            .font(Theme.Typography.task)
                            .foregroundStyle(Theme.Palette.moustache)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, Theme.Layout.rowHorizontalPadding)
                    .frame(height: Theme.Layout.rowHeight)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Fait : \(item.title)")
                    .swipeToDelete { onDelete(item.id) }
                }
            }
        }
    }
}

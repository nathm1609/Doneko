import SwiftUI

/// Section repliable « Tombé aujourd'hui ».
struct DoneSection: View {
    let items: [TodoItem]
    /// Clic sur le rond coché : la tâche revient dans la liste.
    let onUncomplete: (TodoItem.ID) -> Void
    /// Glissement à deux doigts vers la gauche sur une tâche faite.
    let onDelete: (TodoItem.ID) -> Void
    /// Glisser-déposer vers la liste des tâches à faire.
    let onDrag: (TodoItem.ID) -> NSItemProvider

    @AppStorage("doneSectionExpanded") private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Layout.rowSpacing) {
            Button { isExpanded.toggle() } label: {
                HStack(spacing: Theme.Layout.smallSpacing) {
                    Image(systemName: "chevron.right")
                        .rotationEffect(isExpanded ? Theme.Layout.disclosureRotation : .zero)
                    Text("Tombé aujourd'hui (\(items.count))")
                        .textCase(.uppercase)
                        .tracking(Theme.Typography.sectionTitleTracking)
                }
                .sectionTitleStyle()
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Tombé aujourd'hui, \(items.count) \(items.count == 1 ? "tâche" : "tâches")")
            .accessibilityValue(isExpanded ? "Déplié" : "Replié")

            if isExpanded {
                ForEach(items) { item in
                    HStack(spacing: Theme.Layout.rowContentSpacing) {
                        Button { onUncomplete(item.id) } label: {
                            PawPad(isChecked: true, isHovered: false)
                        }
                        .buttonStyle(.plain)
                        .help("Remettre sur la table")
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
                    .accessibilityAction(named: "Remettre sur la table") { onUncomplete(item.id) }
                    .onDrag { onDrag(item.id) }
                    .swipeToDelete { onDelete(item.id) }
                }
            }
        }
    }
}

/// Titre de section : « Aujourd'hui », « Plus tard ».
struct SectionTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .textCase(.uppercase)
            .tracking(Theme.Typography.sectionTitleTracking)
            .sectionTitleStyle()
            .accessibilityAddTraits(.isHeader)
    }
}

private extension View {
    func sectionTitleStyle() -> some View {
        font(Theme.Typography.sectionTitle)
            .foregroundStyle(Theme.Palette.moustache)
            .padding(.horizontal, Theme.Layout.rowHorizontalPadding)
    }
}

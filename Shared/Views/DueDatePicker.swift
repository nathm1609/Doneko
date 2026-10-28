import SwiftUI

/// Pour qui on choisit une date au calendrier : la tâche qu'on va taper, ou une tâche de la liste (« Échéance… »).
enum DatePicking: Identifiable, Equatable {
    case newTask
    case task(TodoItem.ID)

    var id: String {
        switch self {
        case .newTask: "newTask"
        case .task(let id): id.uuidString
        }
    }
}

/// Calendrier « Pour quand ? », en français : toucher un jour en fait l'échéance ; les jours passés ne sont pas
/// proposés. Sans échéance, aujourd'hui apparaît sélectionné (le calendrier ne sait pas n'en montrer aucun) : toucher
/// ce jour-là ne change rien, d'où le bouton « OK » qui valide le jour sélectionné.
struct DueDatePicker: View {
    let selection: Date?
    let today: Date
    let onPick: (Date) -> Void

    var body: some View {
        DatePicker(
            "Pour quand ?",
            selection: Binding(get: { selection ?? today }, set: onPick),
            in: today...,
            displayedComponents: .date
        )
        .datePickerStyle(.graphical)
        .labelsHidden()
        .tint(Theme.Palette.mandarine)
        .environment(\.locale, Locale(identifier: "fr_FR"))
    }
}

extension FormatStyle where Self == Date.FormatStyle {
    /// « Ven. 25 déc. » : en français comme le reste de l'interface, quelle que soit la langue de l'appareil.
    static var dueDate: Date.FormatStyle {
        .dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(Locale(identifier: "fr_FR"))
    }
}

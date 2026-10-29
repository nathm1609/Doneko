import AppKit
import SwiftUI

/// Demande de coup de patte venue du clavier (Espace). Le jeton rend chaque demande unique.
struct KnockOffRequest: Equatable {
    let id: TodoItem.ID
    let token = UUID()
}

struct TodoRow: View {
    let item: TodoItem
    /// Sélection clavier (↑/↓).
    let isSelected: Bool
    /// Échéance affichée à droite (section « Plus tard »).
    var showsDueDate = false
    /// Nom du dossier, discret au bout de la ligne (dans « Tout »).
    var folderName: String?
    /// Clic droit › « Ranger dans » : les dossiers, et le choix (`nil` : aucun dossier).
    var folders: [Folder] = []
    var onFile: (Folder.ID?) -> Void = { _ in }
    /// Clic droit › « Échéance… » : le calendrier du panneau.
    var onPickDate: () -> Void = {}
    let knockOffRequest: KnockOffRequest?
    /// Appelé une fois l'animation « coup de patte » terminée.
    let onComplete: () -> Void
    /// Fin de la modification : le nouveau titre, ou nil si elle a été abandonnée.
    let onEditEnd: (String?) -> Void
    /// Glissement à deux doigts vers la gauche.
    let onDelete: () -> Void

    /// Étapes du coup de patte : coche Matcha → patte qui touche la ligne → chute hors de la table.
    private enum Phase: Int, Comparable {
        case idle, checked, pawed, falling
        static func < (a: Phase, b: Phase) -> Bool { a.rawValue < b.rawValue }
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(SettingsKey.soundEnabled) private var soundEnabled = false
    @State private var phase = Phase.idle
    /// Début du geste de la patte (images PawPush), au moment où elle entre.
    @State private var pawStart: Date?
    @State private var isHovered = false
    @State private var isPadHovered = false
    @State private var isEditing = false
    @State private var draft = ""
    @FocusState private var isEditFocused: Bool

    var body: some View {
        ZStack(alignment: .leading) {
            row
                .offset(x: phase == .falling && !reduceMotion ? Theme.Motion.fallDistance : 0)
                .rotationEffect(phase == .falling && !reduceMotion ? Theme.Motion.fallRotation : .zero, anchor: .leading)
                .opacity(phase == .falling ? 0 : 1)

            if let pawStart {
                paw(from: pawStart)
            }
        }
        .onChange(of: knockOffRequest) { _, request in
            if request?.id == item.id { knockOff() }
        }
        .swipeToDelete(isEnabled: !isEditing && phase == .idle, onDelete: onDelete)
    }

    private var row: some View {
        HStack(spacing: Theme.Layout.rowContentSpacing) {
            Button(action: knockOff) {
                PawPad(isChecked: phase >= .checked, isHovered: isPadHovered)
            }
            .buttonStyle(.pressable)
            .onHover { isPadHovered = $0 }
            .accessibilityLabel("Faire tomber « \(item.title) »")

            if isEditing {
                TextField("Modifier la tâche", text: $draft)
                    .textFieldStyle(.plain)
                    .font(Theme.Typography.task)
                    .foregroundStyle(Theme.Palette.encre)
                    .focused($isEditFocused)
                    .onSubmit { finishEditing(saving: true) }
                    .onExitCommand { finishEditing(saving: false) }
                    // Clic ailleurs : on abandonne la modification.
                    .onChange(of: isEditFocused) { _, focused in
                        if !focused { finishEditing(saving: false) }
                    }
            } else {
                HStack(spacing: Theme.Layout.smallSpacing) {
                    if item.isPriority {
                        Circle()
                            .fill(Theme.Palette.sakura)
                            .frame(width: Theme.Layout.priorityDotSize, height: Theme.Layout.priorityDotSize)
                            .accessibilityHidden(true)
                    }
                    Text(item.title)
                        .font(Theme.Typography.task)
                        .foregroundStyle(Theme.Palette.encre)
                        .lineLimit(1)
                        .accessibilityLabel(item.isPriority ? "Prioritaire : \(item.title)" : item.title)
                }
                Spacer(minLength: 0)
                if let details {
                    Text(details.text)
                        .font(Theme.Typography.caption)
                        .monospacedDigit()
                        .foregroundStyle(Theme.Palette.moustache)
                        .lineLimit(1)
                        .accessibilityLabel(details.spoken)
                }
            }
        }
        .padding(.horizontal, Theme.Layout.rowHorizontalPadding)
        .frame(height: Theme.Layout.rowHeight)
        .background(
            (isHovered || isSelected) && phase == .idle ? Theme.Palette.coussin : .clear,
            in: RoundedRectangle(cornerRadius: Theme.Layout.rowCornerRadius)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture(count: 2, perform: startEditing)
        .accessibilityAction(named: "Modifier", startEditing)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .contextMenu {
            Button("Échéance…", action: onPickDate)
            if !folders.isEmpty {
                Picker("Ranger dans", selection: Binding(get: { item.folderID }, set: onFile)) {
                    Text("Aucun dossier").tag(Folder.ID?.none)
                    ForEach(folders) { folder in
                        Text(folder.name).tag(Folder.ID?.some(folder.id))
                    }
                }
            }
        }
    }

    /// Dossier et échéance en une seule étiquette discrète au bout de la ligne : « courses · Sam. 16 janv. ».
    private var details: (text: String, spoken: String)? {
        let due = showsDueDate ? item.dueDate?.formatted(.dueDate) : nil
        let text = [folderName, due].compactMap { $0 }
        guard !text.isEmpty else { return nil }
        let spoken = [folderName.map { "Dossier \($0)" }, due.map { "échéance \($0)" }].compactMap { $0 }
        return (text.joined(separator: " · "), spoken.joined(separator: ", "))
    }

    /// Patte rousse qui entre par le bord gauche de la ligne (la liste coupe ce qui dépasse), se pose sur le rond, recule
    /// un peu et pousse la tâche hors de la table, en s'effaçant pendant la chute.
    private func paw(from start: Date) -> some View {
        PawPush(start: start)
            .frame(width: Theme.Layout.pawWidth, height: Theme.Layout.pawHeight)
            .offset(x: Theme.Layout.pawReach - Theme.Layout.pawWidth * Theme.Layout.pawRestTip)
            .opacity(phase == .falling ? 0 : 1)
            .accessibilityHidden(true)
    }

    private func knockOff() {
        guard phase == .idle, !isEditing else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        if soundEnabled { Self.pop?.play() }

        if reduceMotion {
            withAnimation(.easeOut(duration: Theme.Motion.reducedMotionFade)) {
                phase = .falling
            } completion: {
                onComplete()
            }
            return
        }

        withAnimation(.easeOut(duration: Theme.Motion.checkFill)) {
            phase = .checked
        } completion: {
            phase = .pawed
            pawStart = .now
            Task {
                try? await Task.sleep(for: .seconds(PawPush.entryDuration))
                withAnimation(.spring(duration: Theme.Motion.fall, bounce: Theme.Motion.springBounce)) {
                    phase = .falling
                } completion: {
                    onComplete()
                }
            }
        }
    }

    /// « Pop » feutré du système (réglage, désactivé par défaut).
    private static let pop: NSSound? = {
        let sound = NSSound(named: "Pop")
        sound?.volume = Theme.Sound.popVolume
        return sound
    }()

    private func startEditing() {
        guard !isEditing, phase == .idle else { return }
        // Le « ! » reste visible pendant la modification : l'effacer retire la priorité.
        draft = item.isPriority ? "\(item.title) !" : item.title
        isEditing = true
        isEditFocused = true
    }

    private func finishEditing(saving: Bool) {
        guard isEditing else { return }
        isEditing = false
        onEditEnd(saving ? draft : nil)
    }
}

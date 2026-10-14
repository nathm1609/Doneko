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

            if !reduceMotion {
                paw
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
            .buttonStyle(.plain)
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
    }

    /// Patte Mandarine qui arrive de la gauche et touche le bord de la ligne.
    private var paw: some View {
        Image(systemName: "pawprint.fill")
            .font(.system(size: Theme.Layout.pawSize))
            .rotationEffect(.degrees(90))
            .foregroundStyle(Theme.Palette.mandarine)
            .offset(x: phase >= .pawed ? -Theme.Layout.pawSize / 2 : -Theme.Layout.pawSize * 2)
            .opacity(phase == .pawed ? 1 : 0)
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
            withAnimation(.easeOut(duration: Theme.Motion.pawSlide)) {
                phase = .pawed
            } completion: {
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

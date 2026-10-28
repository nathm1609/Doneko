import AVFoundation
import SwiftUI

/// Une tâche sur l'iPhone. Toucher le rond : coup de patte. Toucher le texte : modifier. Balayer vers la gauche :
/// supprimer. Appui long : « Prioritaire », « Ranger dans », « Supprimer ».
struct TodoRow: View {
    let item: TodoItem
    /// Échéance affichée à droite (section « Plus tard »).
    var showsDueDate = false
    /// Nom du dossier, discret au bout de la ligne (dans « Tout »).
    var folderName: String?
    /// Appui long › « Ranger dans » : les dossiers, et le choix (`nil` : aucun dossier).
    var folders: [Folder] = []
    var onFile: (Folder.ID?) -> Void = { _ in }
    var onPriority: (Bool) -> Void = { _ in }
    /// Appelé une fois l'animation « coup de patte » terminée.
    let onComplete: () -> Void
    /// Fin de la modification : le nouveau titre (le store ignore un titre vide ou inchangé).
    let onEdit: (String) -> Void
    let onDelete: () -> Void

    /// Étapes du coup de patte : coche Matcha → patte qui touche la ligne → chute hors de la table.
    private enum Phase: Int, Comparable {
        case idle, checked, pawed, falling
        static func < (a: Phase, b: Phase) -> Bool { a.rawValue < b.rawValue }
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(SettingsKey.soundEnabled) private var soundEnabled = false
    @State private var phase = Phase.idle
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
        // Vibration légère au moment où la coche se remplit.
        .sensoryFeedback(.impact(weight: .light), trigger: phase > .idle)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) {
                Label("Supprimer", systemImage: "trash")
            }
        }
        .contextMenu { menu }
    }

    private var row: some View {
        HStack(spacing: 0) {
            Button(action: knockOff) {
                PawPad(isChecked: phase >= .checked, diameter: Theme.Layout.touchPawPadDiameter)
                    .frame(width: Theme.Layout.touchTarget, height: Theme.Layout.touchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Faire tomber « \(item.title) »")

            if isEditing {
                TextField("Modifier la tâche", text: $draft)
                    .font(Theme.Typography.touchBody)
                    .foregroundStyle(Theme.Palette.encre)
                    .focused($isEditFocused)
                    .submitLabel(.done)
                    .onSubmit(finishEditing)
                    // Toucher ailleurs garde la modification : retaper au doigt coûte plus cher qu'au clavier du Mac.
                    .onChange(of: isEditFocused) { _, focused in
                        if !focused { finishEditing() }
                    }
            } else {
                HStack(spacing: Theme.Layout.rowContentSpacing) {
                    HStack(spacing: Theme.Layout.smallSpacing) {
                        if item.isPriority {
                            Circle()
                                .fill(Theme.Palette.sakura)
                                .frame(width: Theme.Layout.priorityDotSize, height: Theme.Layout.priorityDotSize)
                                .accessibilityHidden(true)
                        }
                        Text(item.title)
                            .font(Theme.Typography.touchBody)
                            .foregroundStyle(Theme.Palette.encre)
                            .accessibilityLabel(item.isPriority ? "Prioritaire : \(item.title)" : item.title)
                    }
                    Spacer(minLength: 0)
                    if let folderName {
                        Text(folderName)
                            .font(Theme.Typography.touchCaption)
                            .foregroundStyle(Theme.Palette.moustache)
                            .lineLimit(1)
                            .accessibilityLabel("Dossier \(folderName)")
                    }
                    if showsDueDate, let dueDate = item.dueDate {
                        Text(dueDate, format: Self.dueDateFormat)
                            .font(Theme.Typography.touchCaption)
                            .foregroundStyle(Theme.Palette.moustache)
                    }
                }
                .frame(minHeight: Theme.Layout.touchTarget)
                .contentShape(Rectangle())
                .onTapGesture(perform: startEditing)
                .accessibilityAction(named: "Modifier", startEditing)
            }
        }
    }

    @ViewBuilder
    private var menu: some View {
        Toggle(isOn: Binding(get: { item.isPriority }, set: onPriority)) {
            Label("Prioritaire", systemImage: "exclamationmark")
        }
        if !folders.isEmpty {
            Picker(selection: Binding(get: { item.folderID }, set: onFile)) {
                Text("Aucun dossier").tag(Folder.ID?.none)
                ForEach(folders) { folder in
                    Text(folder.name).tag(Folder.ID?.some(folder.id))
                }
            } label: {
                Label("Ranger dans", systemImage: "folder")
            }
            .pickerStyle(.menu)
        }
        Divider()
        Button(role: .destructive, action: onDelete) {
            Label("Supprimer", systemImage: "trash")
        }
    }

    /// Patte rousse qui entre par le bord gauche de la ligne, se pose sur le rond et pousse la tâche hors de la table.
    private var paw: some View {
        Image("Paw")
            .resizable()
            .frame(width: Theme.Layout.touchPawWidth, height: Theme.Layout.touchPawHeight)
            .offset(x: pawOffset)
            .opacity(phase == .pawed ? 1 : 0)
            .accessibilityHidden(true)
    }

    /// Cachée à gauche de la ligne, posée sur le rond, puis poussant avec la chute.
    private var pawOffset: CGFloat {
        switch phase {
        case .idle, .checked: -Theme.Layout.touchPawWidth
        case .pawed: Theme.Layout.touchPawReach - Theme.Layout.touchPawWidth
        case .falling: Theme.Layout.touchPawReach + Theme.Layout.pawPush - Theme.Layout.touchPawWidth
        }
    }

    private func knockOff() {
        guard phase == .idle, !isEditing else { return }
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

    /// « Lun. 19 oct. » : en français comme le reste de l'interface, quelle que soit la langue de l'iPhone.
    private static let dueDateFormat = Date.FormatStyle.dateTime
        .weekday(.abbreviated).day().month(.abbreviated)
        .locale(Locale(identifier: "fr_FR"))

    /// « Pop » feutré (réglage, désactivé par défaut), muet quand l'iPhone est en silencieux.
    private static let pop: AVAudioPlayer? = {
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        guard let url = Bundle.main.url(forResource: "Pop", withExtension: "wav"),
              let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
        player.volume = Theme.Sound.popVolume
        player.prepareToPlay()
        return player
    }()

    private func startEditing() {
        guard !isEditing, phase == .idle else { return }
        // Le « ! » reste visible pendant la modification : l'effacer retire la priorité.
        draft = item.isPriority ? "\(item.title) !" : item.title
        isEditing = true
        isEditFocused = true
    }

    private func finishEditing() {
        guard isEditing else { return }
        isEditing = false
        onEdit(draft)
    }
}

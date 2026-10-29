import SwiftUI

/// Liste vide : mascotte endormie qui fait la sieste (vidéo en boucle : elle respire, ses « z » montent), ou contente si
/// tout a été fait aujourd'hui, qui se balance et saute de joie en arrivant. Un clic la fait sauter, ou se tortiller dans
/// son sommeil.
struct EmptyState: View {
    let allDone: Bool
    /// Plus grand sur l'iPhone (Dynamic Type).
    var font = Theme.Typography.caption

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBreathingIn = false
    @State private var hop: CGFloat = 0
    @State private var wiggle = Angle.zero
    @State private var isCheering = false

    var body: some View {
        VStack(spacing: Theme.Layout.panelPadding) {
            mascot
                .frame(width: Theme.Layout.mascotSize, height: Theme.Layout.mascotSize)
                .rotationEffect(sway, anchor: .bottom)
                .rotationEffect(wiggle, anchor: .bottom)
                .offset(y: -hop)
                .contentShape(Rectangle())
                .onTapGesture { allDone ? jump() : stir() }
                .accessibilityHidden(true)
            Text(allDone ? "Table rase ! Bien joué." : "Plus rien sur la table. Doneko fait la sieste.")
                .font(font)
                .foregroundStyle(Theme.Palette.moustache)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Layout.panelPadding)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: Theme.Motion.breathePeriod).repeatForever(autoreverses: true)) {
                isBreathingIn = true
            }
            if allDone { jump() }
        }
        .onChange(of: allDone) { _, done in
            if done { jump() }
        }
    }

    /// Endormie : la vidéo de la sieste, ou l'image fixe si on réduit les animations. Contente : son image, et celle de la
    /// joie superposée en fondu le temps d'un saut.
    @ViewBuilder
    private var mascot: some View {
        if allDone {
            ZStack {
                image("MascotContent", shown: !isCheering)
                image("MascotCheer", shown: isCheering)
            }
        } else if !reduceMotion, let nap = Bundle.main.url(forResource: "MascotNap", withExtension: "mov") {
            LoopingVideo(url: nap)
        } else {
            image("MascotAsleep", shown: true)
        }
    }

    /// Contente, la tête se balance d'un côté à l'autre au rythme de la respiration ; immobile si on réduit les animations.
    private var sway: Angle {
        guard allDone, !reduceMotion else { return .zero }
        return isBreathingIn ? Theme.Motion.mascotSwayContent : -Theme.Motion.mascotSwayContent
    }

    private func image(_ name: String, shown: Bool) -> some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .opacity(shown ? 1 : 0)
    }

    /// Saut de joie, l'air ravi : montée rapide, retombée avec un petit rebond.
    private func jump() {
        guard !reduceMotion else { return }
        Task {
            withAnimation(.easeInOut(duration: Theme.Motion.mascotPoseFade)) { isCheering = true }
            try? await Task.sleep(for: .seconds(Theme.Motion.mascotCheer))
            withAnimation(.easeInOut(duration: Theme.Motion.mascotPoseFade)) { isCheering = false }
        }
        withAnimation(.easeOut(duration: Theme.Motion.mascotHopRise)) {
            hop = Theme.Motion.mascotHopHeight
        } completion: {
            withAnimation(.spring(duration: Theme.Motion.mascotLanding, bounce: Theme.Motion.mascotBounce)) { hop = 0 }
        }
    }

    /// Dérangé pendant sa sieste : il se tortille, puis se rendort.
    private func stir() {
        guard !reduceMotion else { return }
        withAnimation(.easeOut(duration: Theme.Motion.mascotHopRise)) {
            wiggle = Theme.Motion.mascotWiggleAngle
        } completion: {
            withAnimation(.spring(duration: Theme.Motion.mascotLanding, bounce: Theme.Motion.mascotBounce)) { wiggle = .zero }
        }
    }
}

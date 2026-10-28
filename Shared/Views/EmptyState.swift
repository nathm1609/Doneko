import SwiftUI

/// Liste vide : mascotte endormie qui respire, ou contente si tout a été fait aujourd'hui.
/// Endormie, elle remue une oreille ou bâille de temps en temps. Contente, elle saute de joie en arrivant.
/// Un clic la fait sauter, ou remuer dans son sommeil.
struct EmptyState: View {
    let allDone: Bool

    /// Image-clé montrée à la place de la mascotte au repos, le temps d'un petit mouvement.
    private enum Pose { case rest, ear, yawn, cheer }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBreathingIn = false
    @State private var hop: CGFloat = 0
    @State private var wiggle = Angle.zero
    @State private var pose = Pose.rest

    var body: some View {
        VStack(spacing: Theme.Layout.panelPadding) {
            ZStack {
                mascot(allDone ? "MascotContent" : "MascotAsleep", shown: pose == .rest)
                mascot("MascotAsleepEar", shown: pose == .ear)
                mascot("MascotYawn", shown: pose == .yawn)
                mascot("MascotCheer", shown: pose == .cheer)
            }
            .frame(width: Theme.Layout.mascotSize, height: Theme.Layout.mascotSize)
            .scaleEffect(isBreathingIn && !allDone ? Theme.Motion.breatheScale : 1)
            .rotationEffect(sway, anchor: .bottom)
            .rotationEffect(wiggle, anchor: .bottom)
            .offset(y: -hop)
            .contentShape(Rectangle())
            .onTapGesture { allDone ? jump() : stir() }
            .accessibilityHidden(true)
            Text(allDone ? "Table rase ! Bien joué." : "Plus rien sur la table. Doneko fait la sieste.")
                .font(Theme.Typography.caption)
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
        .task(id: allDone) { await nap() }
    }

    /// Léger balancement de la tête, d'un côté à l'autre au rythme de la respiration ; immobile si on réduit les animations.
    private var sway: Angle {
        guard !reduceMotion else { return .zero }
        let angle = allDone ? Theme.Motion.mascotSwayContent : Theme.Motion.mascotSwayAsleep
        return isBreathingIn ? angle : -angle
    }

    /// Les images-clés sont superposées : une seule visible, les autres en fondu.
    private func mascot(_ name: String, shown: Bool) -> some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .opacity(shown ? 1 : 0)
    }

    /// Montre une image-clé pendant `duration` secondes, avec un fondu à l'entrée et à la sortie.
    private func show(_ pose: Pose, for duration: Double) async {
        withAnimation(.easeInOut(duration: Theme.Motion.mascotPoseFade)) { self.pose = pose }
        try? await Task.sleep(for: .seconds(duration))
        withAnimation(.easeInOut(duration: Theme.Motion.mascotPoseFade)) { self.pose = .rest }
    }

    /// Pendant la sieste, de temps en temps : une oreille qui frémit, et une fois sur trois un bâillement.
    private func nap() async {
        guard !allDone, !reduceMotion else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(.random(in: Theme.Motion.mascotNapEvery)))
            guard !Task.isCancelled else { return }
            if Int.random(in: 0..<3) == 0 {
                await show(.yawn, for: Theme.Motion.mascotYawn)
            } else {
                await show(.ear, for: Theme.Motion.mascotEarTwitch)
            }
        }
    }

    /// Saut de joie, l'air ravi : montée rapide, retombée avec un petit rebond.
    private func jump() {
        guard !reduceMotion else { return }
        Task { await show(.cheer, for: Theme.Motion.mascotCheer) }
        withAnimation(.easeOut(duration: Theme.Motion.mascotHopRise)) {
            hop = Theme.Motion.mascotHopHeight
        } completion: {
            withAnimation(.spring(duration: Theme.Motion.mascotLanding, bounce: Theme.Motion.mascotBounce)) { hop = 0 }
        }
    }

    /// Dérangé pendant sa sieste : il remue une oreille et se tortille, puis se rendort.
    private func stir() {
        guard !reduceMotion else { return }
        Task { await show(.ear, for: Theme.Motion.mascotEarTwitch) }
        withAnimation(.easeOut(duration: Theme.Motion.mascotHopRise)) {
            wiggle = Theme.Motion.mascotWiggleAngle
        } completion: {
            withAnimation(.spring(duration: Theme.Motion.mascotLanding, bounce: Theme.Motion.mascotBounce)) { wiggle = .zero }
        }
    }
}

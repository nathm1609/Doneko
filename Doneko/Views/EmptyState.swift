import SwiftUI

/// Liste vide : mascotte endormie qui respire, ou contente si tout a été fait aujourd'hui.
struct EmptyState: View {
    let allDone: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBreathingIn = false

    var body: some View {
        VStack(spacing: Theme.Layout.panelPadding) {
            Image(allDone ? "MascotContent" : "MascotAsleep")
                .resizable()
                .scaledToFit()
                .frame(width: Theme.Layout.mascotSize, height: Theme.Layout.mascotSize)
                .scaleEffect(isBreathingIn && !allDone ? Theme.Motion.breatheScale : 1)
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
        }
    }
}

import SwiftUI

/// Réponse dès l'appui, pas au relâchement : le bouton se resserre un peu, ou pâlit si on réduit les animations.
struct PressableStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? Theme.Motion.pressScale : 1)
            .opacity(configuration.isPressed && reduceMotion ? Theme.Motion.pressedOpacity : 1)
            .animation(.spring(duration: Theme.Motion.press, bounce: Theme.Motion.settleBounce), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableStyle {
    static var pressable: PressableStyle { PressableStyle() }
}

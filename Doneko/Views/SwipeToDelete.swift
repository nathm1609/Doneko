import AppKit
import SwiftUI

extension View {
    /// Glisser à deux doigts vers la gauche (trackpad, Magic Mouse) pour supprimer la ligne.
    func swipeToDelete(isEnabled: Bool = true, onDelete: @escaping () -> Void) -> some View {
        modifier(SwipeToDelete(isEnabled: isEnabled, onDelete: onDelete))
    }
}

/// La ligne suit les doigts ; au-delà du seuil elle part et `onDelete` est appelé, sinon elle revient.
/// SwiftUI n'offre ce geste que dans une List : on lit donc les événements de défilement du trackpad.
private struct SwipeToDelete: ViewModifier {
    let isEnabled: Bool
    let onDelete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var offset: CGFloat = 0
    /// Cadre de la ligne dans la fenêtre (origine en haut à gauche), pour ne réagir que sous le pointeur.
    @State private var frameInWindow: CGRect = .zero
    /// nil tant que la direction du geste en cours n'est pas connue.
    @State private var isHorizontal: Bool?
    @State private var monitor: Any?

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .opacity(1 - Theme.Motion.swipeFade * min(-offset / Theme.Layout.swipeDeleteThreshold, 1))
            // Cadre fixe : la ligne qui glisse ne le déplace pas.
            .frame(maxWidth: .infinity, alignment: .leading)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frameInWindow = $0 }
            .onAppear {
                monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
                    handle(event) ? nil : event
                }
            }
            .onDisappear {
                if let monitor { NSEvent.removeMonitor(monitor) }
                monitor = nil
            }
            .accessibilityAction(named: "Supprimer", onDelete)
    }

    /// true si l'événement appartient au glissement : il ne doit alors pas faire défiler la liste.
    private func handle(_ event: NSEvent) -> Bool {
        guard isEnabled, event.hasPreciseScrollingDeltas, event.momentumPhase.isEmpty,
              let height = event.window?.contentView?.bounds.height,
              frameInWindow.contains(CGPoint(x: event.locationInWindow.x, y: height - event.locationInWindow.y))
        else { return false }

        if event.phase.contains(.began) { isHorizontal = nil }
        if isHorizontal == nil, event.scrollingDeltaX != 0 || event.scrollingDeltaY != 0 {
            isHorizontal = abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY)
        }
        guard isHorizontal == true else { return false }

        if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
            isHorizontal = nil
            settle()
        } else {
            // Défilement naturel : le delta suit déjà les doigts ; sinon il est inversé.
            let fingerDeltaX = event.isDirectionInvertedFromDevice ? event.scrollingDeltaX : -event.scrollingDeltaX
            offset = min(0, offset + fingerDeltaX)
        }
        return true
    }

    private func settle() {
        guard offset <= -Theme.Layout.swipeDeleteThreshold else {
            withAnimation(reduceMotion
                ? .easeOut(duration: Theme.Motion.reducedMotionFade)
                : .spring(duration: Theme.Motion.closeGap, bounce: Theme.Motion.springBounce)) {
                offset = 0
            }
            return
        }
        if reduceMotion {
            onDelete()
            return
        }
        withAnimation(.easeOut(duration: Theme.Motion.reducedMotionFade)) {
            offset = -Theme.Layout.panelWidth
        } completion: {
            onDelete()
        }
    }
}

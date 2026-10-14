import AppKit
import Observation
import SwiftUI

/// Icône de la barre de menu (éveillée / endormie, compteur) et panneau des tâches.
/// AppKit plutôt que MenuBarExtra : sous macOS 27, un MenuBarExtra ne peut pas être ouvert par code (⌃⌥⌘D).
@MainActor
final class MenuBarController: NSObject {
    private let store: TodoStore
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    /// Non activant, comme Spotlight : il prend le clavier sans que macOS ait à activer l'app (activation
    /// souvent refusée pour une app de barre de menu, ce qui cachait le panneau).
    private let panel = KeyPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
    /// Coin haut-gauche du panneau : il reste fixe quand la liste grandit.
    private var topLeft = NSPoint.zero
    private var lastHide = Date.distantPast

    init(store: TodoStore) {
        self.store = store
        super.init()

        let hosting = NSHostingController(rootView: PanelView(store: store, close: { [weak self] in self?.hide() }))
        hosting.sizingOptions = .preferredContentSize
        panel.contentViewController = hosting
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        NotificationCenter.default.addObserver(self, selector: #selector(keepTopLeft), name: NSWindow.didResizeNotification, object: panel)
        NotificationCenter.default.addObserver(self, selector: #selector(panelDidResignKey), name: NSWindow.didResignKeyNotification, object: panel)

        statusItem.button?.target = self
        statusItem.button?.action = #selector(toggle)
        statusItem.button?.imagePosition = .imageLeading
        statusItem.button?.font = Self.counterFont
        updateStatusItem()
    }


    /// Ouvre le panneau (icône ou ⌃⌥⌘D), curseur dans le champ.
    func show() {
        let screen = statusItem.button?.window?.screen ?? NSScreen.main
        topLeft = Self.panelTopLeft(
            size: panel.frame.size,
            icon: statusItem.button?.window?.frame,
            screen: screen?.frame ?? .zero,
            visible: screen?.visibleFrame ?? .zero
        )
        panel.setFrameTopLeftPoint(topLeft)
        panel.makeKeyAndOrderFront(nil)
    }

    @objc func hide() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        lastHide = Date()
    }

    @objc private func toggle() {
        // Cliquer sur l'icône panneau ouvert le ferme d'abord (perte d'activation) : ne pas le rouvrir aussitôt.
        if panel.isVisible || Date().timeIntervalSince(lastHide) < 0.3 {
            hide()
        } else {
            show()
        }
    }

    /// Clic dans une autre app : le panneau se ferme, comme un menu. Une fenêtre système de l'app
    /// (indicateur de source de saisie) qui prend la main un instant ne compte pas.
    @objc private func panelDidResignKey() {
        DispatchQueue.main.async {
            if NSApp.keyWindow == nil { self.hide() }
        }
    }

    @objc private func keepTopLeft() {
        if panel.isVisible { panel.setFrameTopLeftPoint(topLeft) }
    }

    /// Sous l'icône sans déborder de l'écran ; icône cachée (gestionnaire de barre, encoche) : en haut au centre.
    nonisolated static func panelTopLeft(size: NSSize, icon: NSRect?, screen: NSRect, visible: NSRect) -> NSPoint {
        let gap = Theme.Layout.panelScreenGap
        let top = visible.maxY - gap
        guard let icon, screen.intersects(icon) else {
            return NSPoint(x: visible.midX - size.width / 2, y: top)
        }
        let x = min(max(icon.minX, visible.minX + gap), visible.maxX - size.width - gap)
        return NSPoint(x: x, y: top)
    }

    /// Icône éveillée s'il reste des tâches, endormie sinon ; compteur masqué à 0. Suit le store.
    private func updateStatusItem() {
        guard let button = statusItem.button else { return }
        withObservationTracking {
            let remaining = store.todos.count
            let image = NSImage(named: remaining > 0 ? "MenuIconAwake" : "MenuIconAsleep")
            image?.isTemplate = true
            button.image = image
            button.title = remaining > 0 ? "\(remaining)" : ""
            button.toolTip = store.summary
            button.setAccessibilityLabel(store.summary)
        } onChange: { [weak self] in
            Task { @MainActor in self?.updateStatusItem() }
        }
    }

    private static let counterFont: NSFont = {
        let font = NSFont.monospacedDigitSystemFont(ofSize: Theme.Typography.counterSize, weight: .medium)
        return font.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: 0) } ?? font
    }()
}

/// Panneau sans bordure qui accepte le clavier.
private final class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

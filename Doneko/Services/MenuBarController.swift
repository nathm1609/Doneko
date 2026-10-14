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
    private var settingsWindow: NSWindow?

    init(store: TodoStore) {
        self.store = store
        super.init()

        let hosting = NSHostingController(rootView: PanelView(
            store: store,
            close: { [weak self] in self?.hide() },
            openSettings: { [weak self] in self?.openSettings() }
        ))
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
        statusItem.button?.action = #selector(statusItemClicked)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem.button?.setAccessibilityCustomActions([
            NSAccessibilityCustomAction(name: "Réglages") { [weak self] in self?.openSettings(); return true },
            NSAccessibilityCustomAction(name: "Quitter") { NSApp.terminate(nil); return true },
        ])
        statusItem.button?.imagePosition = .imageLeading
        statusItem.button?.font = Self.counterFont
        observeStore()
        // Réglage « Afficher le compteur ».
        NotificationCenter.default.addObserver(self, selector: #selector(applyStatusItem), name: UserDefaults.didChangeNotification, object: nil)
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

    /// Fenêtre « Réglages » : le panneau se ferme, la fenêtre passe au premier plan.
    @objc func openSettings() {
        hide()
        let window = settingsWindow ?? Self.makeSettingsWindow()
        settingsWindow = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    /// À la taille de son contenu : sans `preferredContentSize`, le formulaire (qui défile) ne donne aucune
    /// hauteur et la fenêtre s'ouvre réduite à sa barre de titre.
    static func makeSettingsWindow() -> NSWindow {
        let hosting = NSHostingController(rootView: SettingsView())
        hosting.sizingOptions = .preferredContentSize
        let window = NSWindow(contentViewController: hosting)
        window.title = "Réglages"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }

    /// Clic gauche : le panneau. Clic droit (ou ⌃ clic) : le menu Réglages / Quitter.
    @objc private func statusItemClicked() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showMenu()
        } else {
            toggle()
        }
    }

    private func showMenu() {
        hide()
        guard let button = statusItem.button else { return }
        button.highlight(true)
        // Sous l'icône, comme un menu de barre de menu ; popUp rend la main une fois le menu fermé.
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.isFlipped ? button.bounds.maxY : 0), in: button)
        button.highlight(false)
    }

    private lazy var menu: NSMenu = {
        let menu = NSMenu()
        let settings = NSMenuItem(title: "Réglages…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Laisser Doneko dormir (Quitter)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }()

    private func toggle() {
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

    /// Suit le store : l'icône se met à jour à chaque changement de la liste.
    private func observeStore() {
        withObservationTracking {
            applyStatusItem()
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeStore() }
        }
    }

    /// Icône éveillée s'il reste des tâches pour aujourd'hui, endormie sinon ; compteur masqué à 0 ou si le réglage le cache.
    @objc private func applyStatusItem() {
        guard let button = statusItem.button else { return }
        let remaining = store.today.count
        let image = NSImage(named: remaining > 0 ? "MenuIconAwake" : "MenuIconAsleep")
        image?.isTemplate = true
        button.image = image
        button.title = remaining > 0 && UserDefaults.standard.bool(forKey: SettingsKey.showCounter) ? "\(remaining)" : ""
        button.toolTip = store.summary
        button.setAccessibilityLabel(store.summary)
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

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
    /// Nombre de tâches du jour à la dernière mise à jour de l'icône (aucune réaction au lancement).
    private var lastRemaining: Int?
    private var iconAnimation: Timer?

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
        scheduleIdle()
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
    /// Quand le nombre change, la tête réagit (voir `IconAnimation`).
    @objc private func applyStatusItem() {
        guard let button = statusItem.button else { return }
        let remaining = store.today.count
        if let last = lastRemaining, let reaction = IconAnimation(from: last, to: remaining),
           !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            play(reaction)
        } else if iconAnimation == nil {
            button.image = Self.image(IconFrame(awake: remaining > 0))
        }
        lastRemaining = remaining
        button.title = remaining > 0 && UserDefaults.standard.bool(forKey: SettingsKey.showCounter) ? "\(remaining)" : ""
        button.toolTip = store.summary
        button.setAccessibilityLabel(store.summary)
    }

    /// Joue une animation image par image, puis l'icône reprend l'état de la liste.
    private func play(_ animation: IconAnimation) {
        iconAnimation?.invalidate()
        let start = Date()
        iconAnimation = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard let self, let button = self.statusItem.button else { return timer.invalidate() }
                let t = Date().timeIntervalSince(start) / animation.duration
                if t < 1 {
                    button.image = Self.image(animation.frame(at: t))
                } else {
                    timer.invalidate()
                    self.iconAnimation = nil
                    button.image = Self.image(IconFrame(awake: self.store.today.count > 0))
                }
            }
        }
    }

    /// De temps en temps, quand rien ne se passe : clignement des yeux si la tête est éveillée, « z » si elle dort.
    private func scheduleIdle() {
        let timer = Timer.scheduledTimer(withTimeInterval: .random(in: Theme.Motion.iconIdleDelay), repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if self.iconAnimation == nil, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                    self.play(self.store.today.count > 0 ? .blink : .snore)
                }
                self.scheduleIdle()
            }
        }
        timer.tolerance = 1
    }

    /// Dessine l'icône dans un bitmap : le vide autour de la patte efface le trait de la tête dessous, sans percer la
    /// barre de menu. Cadre un peu plus haut que la tête, pour qu'elle saute sans être coupée.
    static func image(_ frame: IconFrame) -> NSImage? {
        guard let head = NSImage(named: frame.awake ? (frame.blink ? "MenuIconBlink" : "MenuIconAwake") : "MenuIconAsleepHead"),
              let z = NSImage(named: "MenuIconZ"), let paw = NSImage(named: "MenuIconPaw") else { return nil }
        let headroom = Theme.Motion.iconHopLift
        let size = NSSize(width: head.size.width, height: head.size.height + 2 * headroom)
        let pixelsPerPoint = 2 // net sur un écran Retina, réduit proprement ailleurs
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width) * pixelsPerPoint,
                                            pixelsHigh: Int(size.height) * pixelsPerPoint, bitsPerSample: 8, samplesPerPixel: 4,
                                            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
        else { return nil }
        bitmap.size = size

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let rest = NSRect(origin: .zero, size: size).insetBy(dx: 0, dy: headroom)
        let moved = rest.offsetBy(dx: 0, dy: frame.lift)
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: moved.midX, yBy: moved.midY)
        transform.rotate(byDegrees: frame.angle)
        transform.translateX(by: -moved.midX, yBy: -moved.midY)
        transform.concat()
        head.draw(in: moved)
        NSGraphicsContext.restoreGraphicsState()
        if !frame.awake {
            z.draw(in: rest.offsetBy(dx: 0, dy: frame.zLift), from: .zero, operation: .sourceOver, fraction: frame.zOpacity)
        }
        if frame.paw {
            let gap = Theme.Motion.iconPawGap
            for (dx, dy) in [(-gap, 0), (gap, 0), (0, -gap), (0, gap), (-gap, -gap), (gap, gap), (-gap, gap), (gap, -gap)] {
                paw.draw(in: rest.offsetBy(dx: dx, dy: dy), from: .zero, operation: .destinationOut, fraction: 1)
            }
            paw.draw(in: rest)
        }
        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: size)
        image.addRepresentation(bitmap)
        image.isTemplate = true
        return image
    }

    private static let counterFont: NSFont = {
        let font = NSFont.monospacedDigitSystemFont(ofSize: Theme.Typography.counterSize, weight: .medium)
        return font.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: 0) } ?? font
    }()
}

/// Ce que montre la tête de chat à un instant donné ; par défaut, au repos.
struct IconFrame {
    var awake: Bool
    var lift: CGFloat = 0
    /// En degrés, négatif = vers la droite.
    var angle: CGFloat = 0
    var blink = false
    var paw = false
    var zLift: CGFloat = 0
    var zOpacity: CGFloat = 1
}

/// Animations de la tête de chat. Quand le nombre de tâches du jour change : petit saut quand une tâche arrive, coup de
/// tête vers la droite et patte levée quand une tâche part, comme si le chat la poussait hors de la table. Au repos :
/// clignement des yeux (éveillée) ou « z » qui monte en s'effaçant (endormie).
enum IconAnimation {
    case hop, swat, blink, snore

    init?(from old: Int, to new: Int) {
        if new > old { self = .hop } else if new < old { self = .swat } else { return nil }
    }

    var duration: Double {
        switch self {
        case .hop, .swat: Theme.Motion.iconReaction
        case .blink: Theme.Motion.iconBlink
        case .snore: Theme.Motion.iconSnore
        }
    }

    /// Image à l'instant `t` (0 → 1), au repos aux deux bouts. Saut et coup se jouent tête éveillée : le chat se réveille
    /// pour sauter, et pousse la dernière tâche avant de s'endormir.
    func frame(at t: Double) -> IconFrame {
        switch self {
        case .hop:
            IconFrame(awake: true, lift: Theme.Motion.iconHopLift * sin(.pi * t))
        case .swat:
            // Le coup part fort, puis la tête revient en se balançant un peu de l'autre côté.
            IconFrame(awake: true, angle: -Theme.Motion.iconSwatAngle * sin(2 * .pi * t) * (1 - t), paw: t > 0.1 && t < 0.6)
        case .blink:
            IconFrame(awake: true, blink: t > 0 && t < 1)
        case .snore:
            // Le « z » monte en s'effaçant, puis réapparaît à sa place.
            t < 0.7
                ? IconFrame(awake: false, zLift: Theme.Motion.iconZLift * t / 0.7, zOpacity: 1 - t / 0.7)
                : IconFrame(awake: false, zOpacity: (t - 0.7) / 0.3)
        }
    }
}

/// Panneau sans bordure qui accepte le clavier.
private final class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

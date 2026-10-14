import AppKit
import XCTest
@testable import Doneko

/// Position du panneau : sous l'icône, sans déborder, ou centré si l'icône est cachée.
final class MenuBarControllerTests: XCTestCase {
    private let screen = NSRect(x: 0, y: 0, width: 1710, height: 1107)
    private let visible = NSRect(x: 0, y: 0, width: 1710, height: 1073) // sous la barre de menu
    private let size = NSSize(width: 320, height: 290)

    func testPanelOpensUnderIcon() {
        let icon = NSRect(x: 1018, y: 1073, width: 34, height: 34)
        let topLeft = MenuBarController.panelTopLeft(size: size, icon: icon, screen: screen, visible: visible)
        XCTAssertEqual(topLeft, NSPoint(x: 1018, y: 1069))
    }

    func testPanelStaysOnScreenNearRightEdge() {
        let icon = NSRect(x: 1690, y: 1073, width: 20, height: 34)
        let topLeft = MenuBarController.panelTopLeft(size: size, icon: icon, screen: screen, visible: visible)
        XCTAssertEqual(topLeft.x, 1710 - 320 - 4)
    }

    func testHiddenIconCentersPanelAtTop() {
        let hidden = NSRect(x: 0, y: -34, width: 34, height: 34) // icône rangée hors écran (Thaw, encoche)
        let topLeft = MenuBarController.panelTopLeft(size: size, icon: hidden, screen: screen, visible: visible)
        XCTAssertEqual(topLeft, NSPoint(x: 855 - 160, y: 1069))
    }

    func testIconHopsWhenATaskArrivesAndSwatsWhenOneLeaves() {
        XCTAssertEqual(IconAnimation(from: 0, to: 1), .hop) // réveil
        XCTAssertEqual(IconAnimation(from: 2, to: 3), .hop)
        XCTAssertEqual(IconAnimation(from: 3, to: 2), .swat)
        XCTAssertEqual(IconAnimation(from: 1, to: 0), .swat) // dernière tâche, puis sieste
        XCTAssertNil(IconAnimation(from: 2, to: 2))
    }

    /// Une animation qui ne reviendrait pas au repos laisserait l'icône penchée, la patte levée ou sans « z ».
    func testIconAnimationsStartAndEndAtRest() {
        for (animation, awake) in [(IconAnimation.hop, true), (.swat, true), (.blink, true), (.snore, false)] {
            for t in [0.0, 1.0] {
                let frame = animation.frame(at: t)
                XCTAssertEqual(frame.awake, awake)
                XCTAssertEqual(frame.lift, 0, accuracy: 1e-9)
                XCTAssertEqual(frame.angle, 0, accuracy: 1e-9)
                XCTAssertFalse(frame.blink)
                XCTAssertFalse(frame.paw)
                XCTAssertEqual(frame.zLift, 0, accuracy: 1e-9)
                XCTAssertEqual(frame.zOpacity, 1, accuracy: 1e-9)
            }
        }
        XCTAssertEqual(IconAnimation.hop.frame(at: 0.5).lift, Theme.Motion.iconHopLift, accuracy: 1e-9)
        let swat = IconAnimation.swat.frame(at: 0.2)
        XCTAssertLessThan(swat.angle, 0) // vers la droite, comme la tâche qui tombe
        XCTAssertTrue(swat.paw)
        XCTAssertTrue(IconAnimation.blink.frame(at: 0.5).blink)
    }

    @MainActor func testEveryIconFrameDraws() {
        for frame in [IconFrame(awake: true), IconFrame(awake: false), IconFrame(awake: true, blink: true, paw: true)] {
            let image = MenuBarController.image(frame)
            XCTAssertNotNil(image)
            XCTAssertEqual(image?.size, NSSize(width: 18, height: 18 + 2 * Theme.Motion.iconHopLift))
        }
    }

    @MainActor func testSettingsWindowShowsItsWholeContent() {
        let window = MenuBarController.makeSettingsWindow()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))

        XCTAssertGreaterThan(window.contentLayoutRect.height, 300) // pas seulement la barre de titre
    }
}

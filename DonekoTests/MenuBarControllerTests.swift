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

    @MainActor func testSettingsWindowShowsItsWholeContent() {
        let window = MenuBarController.makeSettingsWindow()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))

        XCTAssertGreaterThan(window.contentLayoutRect.height, 300) // pas seulement la barre de titre
    }
}

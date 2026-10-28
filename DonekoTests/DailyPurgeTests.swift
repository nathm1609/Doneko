import AppKit
import XCTest
@testable import Doneko

final class DailyPurgeTests: XCTestCase {
    private var clock: FakeClock!
    private var store: TodoStore!
    private var defaults: UserDefaults!
    private let hour: TimeInterval = 3600
    private let day: TimeInterval = 24 * 3600

    override func setUp() {
        super.setUp()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        clock = FakeClock() // 15 janvier 2027, 08:00 UTC
        store = TodoStore(clock: clock, calendar: calendar)
        defaults = UserDefaults(suiteName: "DailyPurgeTests")!
        defaults.removePersistentDomain(forName: "DailyPurgeTests")
    }

    /// Fait tomber la tâche `title` à l'heure actuelle de l'horloge.
    private func addDone(_ title: String) {
        store.add(title)
        store.complete(store.todos.first { $0.title == title }!.id)
    }

    private func pump(_ seconds: TimeInterval) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    func testPurgeKeepsTodayAndTodosAndRemovesYesterday() {
        addDone("Hier")
        clock.current += day
        addDone("Aujourd'hui")
        store.add("À faire")

        store.purgeDone()

        XCTAssertEqual(store.done.map(\.title), ["Aujourd'hui"])
        XCTAssertEqual(store.todos.map(\.title), ["À faire"])
    }

    func testHideDoneMasksYesterdayButKeepsItForTheMac() {
        addDone("Hier")
        clock.current += day
        addDone("Aujourd'hui")

        store.hideDone(atHour: 0)

        XCTAssertEqual(store.done.map(\.title), ["Aujourd'hui"])
        // Toujours dans la liste enregistrée : le Mac l'exportera dans Obsidian, puis la videra.
        XCTAssertEqual(Set(store.items.map(\.title)), ["Hier", "Aujourd'hui"])
    }

    func testDoneJustBeforeMidnightIsPurgedRightAfter() {
        clock.current += 16 * hour - 1 // 23:59:59
        addDone("Tard")
        clock.current += 1 // minuit pile

        store.purgeDone()

        XCTAssertTrue(store.done.isEmpty)
    }

    func testPurgeAtChosenHourUsesLastPassageOfThatHour() {
        clock.current -= 3 * hour // 05:00
        addDone("Avant 6 h")
        clock.current += 2 * hour // 07:00
        addDone("Après 6 h")
        clock.current += hour // 08:00

        store.purgeDone(atHour: 6)

        XCTAssertEqual(store.done.map(\.title), ["Après 6 h"])
    }

    func testBeforeChosenHourTheBoundaryIsYesterday() {
        clock.current += 2 * hour // hier soir pour la purge de demain 6 h : fait à 10:00
        addDone("Fait à 10 h")
        clock.current += 17 * hour // lendemain 03:00, avant 6 h

        store.purgeDone(atHour: 6)

        XCTAssertEqual(store.done.map(\.title), ["Fait à 10 h"])
    }

    func testUndoCannotBringBackPurgedTask() {
        addDone("Hier")
        store.delete(store.done[0].id)
        store.undo() // la tâche revient, faite hier
        clock.current += day

        store.purgeDone()
        store.undo()

        XCTAssertTrue(store.items.isEmpty)
    }

    func testPurgesOnStartOnWakeAndEachCheckAtChosenHour() {
        let workspace = NotificationCenter()
        defaults.set(6, forKey: SettingsKey.purgeHour)
        clock.current -= 3 * hour // 05:00
        addDone("Avant 6 h")
        clock.current += 3 * hour // 08:00

        let purge = DailyPurge(store: store, defaults: defaults, workspaceCenter: workspace, checkInterval: 0.05) // démarrage
        XCTAssertTrue(store.done.isEmpty)

        addDone("Lundi")
        clock.current += day
        workspace.post(name: NSWorkspace.didWakeNotification, object: nil) // réveil
        pump(0.02)
        XCTAssertTrue(store.done.isEmpty)

        addDone("Mardi")
        clock.current += day
        pump(0.2) // vérification périodique
        XCTAssertTrue(store.done.isEmpty)
        _ = purge
    }
}

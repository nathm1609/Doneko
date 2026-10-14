import AppKit
import XCTest
@testable import Doneko

final class DailyPurgeTests: XCTestCase {
    private var clock: FakeClock!
    private var store: TodoStore!
    private let day: TimeInterval = 24 * 3600

    override func setUp() {
        super.setUp()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        clock = FakeClock() // 15 janvier 2027, 08:00 UTC
        store = TodoStore(clock: clock, calendar: calendar)
    }

    /// Fait tomber la tâche `title` à l'heure actuelle de l'horloge.
    private func addDone(_ title: String) {
        store.add(title)
        store.complete(store.todos.first { $0.title == title }!.id)
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

    func testDoneJustBeforeMidnightIsPurgedRightAfter() {
        clock.current += 16 * 3600 - 1 // 23:59:59
        addDone("Tard")
        clock.current += 1 // minuit pile

        store.purgeDone()

        XCTAssertTrue(store.done.isEmpty)
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

    func testPurgesOnStartMidnightAndWake() {
        let workspace = NotificationCenter()
        addDone("Hier")
        clock.current += day

        let purge = DailyPurge(store: store, workspaceCenter: workspace) // démarrage
        XCTAssertTrue(store.done.isEmpty)

        addDone("Lundi")
        clock.current += day
        NotificationCenter.default.post(name: .NSCalendarDayChanged, object: nil) // minuit
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        XCTAssertTrue(store.done.isEmpty)

        addDone("Mardi")
        clock.current += day
        workspace.post(name: NSWorkspace.didWakeNotification, object: nil) // réveil
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        XCTAssertTrue(store.done.isEmpty)
        _ = purge
    }
}

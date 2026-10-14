import XCTest
@testable import Doneko

final class RemindersTests: XCTestCase {
    private var clock: FakeClock!
    private var store: TodoStore!
    private var calendar = Calendar(identifier: .gregorian)

    override func setUp() {
        super.setUp()
        calendar.timeZone = TimeZone(identifier: "UTC")!
        clock = FakeClock() // vendredi 15 janvier 2027, 08:00 UTC
        store = TodoStore(clock: clock, calendar: calendar)
    }

    private func reminders(hour: Int) -> [Reminders.Reminder] {
        Reminders.reminders(for: store.todos, hour: hour, now: clock.now(), calendar: calendar)
    }

    private func at(day: Int, hour: Int) -> Date? {
        calendar.date(from: DateComponents(year: 2027, month: 1, day: day, hour: hour))
    }

    func testDatedTasksAreRemindedOnTheirDayAtChosenHour() {
        ["Sans date", "Véto demain", "Courses lundi !"].forEach(store.add)

        let reminders = reminders(hour: 9)

        XCTAssertEqual(reminders.first { $0.title == "Véto" }?.date, at(day: 16, hour: 9))
        XCTAssertEqual(reminders.first { $0.title == "Courses" }?.date, at(day: 18, hour: 9))
        XCTAssertEqual(reminders.count, 2)
        XCTAssertEqual(reminders.first { $0.title == "Véto" }?.id, store.todos.first { $0.title == "Véto" }?.id.uuidString)
    }

    func testPastTimesDoneTasksAndNeverAreNotReminded() {
        ["Ce matin aujourd'hui", "Ce soir aujourd'hui", "Fait demain"].forEach(store.add)
        store.complete(store.todos.first { $0.title == "Fait" }!.id)

        XCTAssertEqual(reminders(hour: 7), []) // 7 h est passé : il est 8 h
        XCTAssertEqual(Set(reminders(hour: 18).map(\.title)), ["Ce matin", "Ce soir"])
        XCTAssertEqual(reminders(hour: -1), [])
    }
}

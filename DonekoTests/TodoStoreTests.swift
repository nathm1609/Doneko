import XCTest
@testable import Doneko

final class FakeClock: Clock {
    var current = Date(timeIntervalSince1970: 1_800_000_000)
    func now() -> Date { current }
}

final class TodoStoreTests: XCTestCase {
    private var clock: FakeClock!
    private var store: TodoStore!
    private var calendar = Calendar(identifier: .gregorian)

    override func setUp() {
        super.setUp()
        calendar.timeZone = TimeZone(identifier: "UTC")!
        clock = FakeClock() // vendredi 15 janvier 2027, 8 h UTC
        store = TodoStore(clock: clock, calendar: calendar)
    }

    private func day(_ month: Int, _ day: Int) -> Date? {
        calendar.date(from: DateComponents(year: 2027, month: month, day: day))
    }

    private func due(_ title: String) -> Date? {
        store.todos.first { $0.title == title }?.dueDate
    }

    func testAddTrimsTitleAndAppendsInOrder() {
        store.add("  Acheter des croquettes \n")
        store.add("Vider la litière")

        XCTAssertEqual(store.todos.map(\.title), ["Acheter des croquettes", "Vider la litière"])
        XCTAssertEqual(store.todos.first?.createdAt, clock.current)
        XCTAssertFalse(store.canUndo)
    }

    func testAddIgnoresBlankTitle() {
        store.add("   ")
        XCTAssertTrue(store.items.isEmpty)
    }

    func testCompleteMovesItemToDoneWithClockDate() {
        store.add("A")
        store.add("B")
        let a = store.todos[0]
        clock.current += 60

        store.complete(a.id)

        XCTAssertEqual(store.todos.map(\.title), ["B"])
        XCTAssertEqual(store.done.map(\.title), ["A"])
        XCTAssertEqual(store.done.first?.completedAt, clock.current)
    }

    func testCompleteTwiceIsIgnored() {
        store.add("A")
        let id = store.todos[0].id
        store.complete(id)
        store.complete(id)

        store.undo()

        XCTAssertEqual(store.todos.map(\.title), ["A"])
        XCTAssertFalse(store.canUndo)
    }

    func testUndoCompleteRestoresTodoAtSamePlace() {
        store.add("A")
        store.add("B")
        store.complete(store.todos[0].id)

        store.undo()

        XCTAssertEqual(store.todos.map(\.title), ["A", "B"])
        XCTAssertTrue(store.done.isEmpty)
    }

    func testDeleteAndUndoReinsertsItem() {
        store.add("A")
        store.add("B")
        store.delete(store.todos[0].id)
        XCTAssertEqual(store.todos.map(\.title), ["B"])

        store.undo()

        XCTAssertEqual(store.todos.map(\.title), ["A", "B"])
    }

    func testEditChangesTitleAndUndoRestoresIt() {
        store.add("A")
        let id = store.todos[0].id

        store.edit(id, title: " Nouveau titre ")
        XCTAssertEqual(store.todos[0].title, "Nouveau titre")

        store.undo()
        XCTAssertEqual(store.todos[0].title, "A")
    }

    func testEditIgnoresBlankOrUnchangedTitle() {
        store.add("A")
        let id = store.todos[0].id

        store.edit(id, title: "  ")
        store.edit(id, title: "A")

        XCTAssertEqual(store.todos[0].title, "A")
        XCTAssertFalse(store.canUndo)
    }

    func testExclamationMarkAtEndMakesPriorityTaskOnTop() {
        store.add("Arroser le basilic")
        store.add("Payer le loyer !")
        store.add("Appeler le véto!!")

        XCTAssertEqual(store.todos.map(\.title), ["Payer le loyer", "Appeler le véto", "Arroser le basilic"])
        XCTAssertEqual(store.todos.map(\.isPriority), [true, true, false])
    }

    func testExclamationMarkElsewhereOrAloneIsNotPriority() {
        store.add("!important : relire")
        store.add(" ! ")

        XCTAssertEqual(store.todos.map(\.title), ["!important : relire"])
        XCTAssertFalse(store.todos[0].isPriority)
    }

    func testEditAddsOrRemovesPriorityAndUndoRestoresIt() {
        store.add("A")
        store.add("B")
        let b = store.todos[1].id

        store.edit(b, title: "B !")
        XCTAssertEqual(store.todos.map(\.title), ["B", "A"])

        store.edit(b, title: "B")
        XCTAssertEqual(store.todos.map(\.title), ["A", "B"])

        store.undo()
        XCTAssertEqual(store.todos.first?.isPriority, true)
    }

    func testMoveDownAndUp() {
        ["A", "B", "C"].forEach(store.add)
        let ids = store.todos.map(\.id)

        store.move(ids[0], to: ids[2])
        XCTAssertEqual(store.todos.map(\.title), ["B", "C", "A"])

        store.move(ids[0], to: ids[1])
        XCTAssertEqual(store.todos.map(\.title), ["A", "B", "C"])
    }

    func testMoveKeepsPriorityTasksOnTop() {
        ["Urgent !", "A", "B"].forEach(store.add)
        let urgent = store.todos[0].id
        let b = store.todos[2].id

        store.move(b, to: urgent) // une tâche normale ne passe pas devant une prioritaire
        XCTAssertEqual(store.todos.map(\.title), ["Urgent", "B", "A"])
    }

    func testMovedOrderIsSavedAndSurvivesUndoOfEarlierEdit() {
        ["A", "B"].forEach(store.add)
        let a = store.todos[0].id
        store.edit(a, title: "A2")
        store.move(a, to: store.todos[1].id)

        store.undo() // annule la modification, pas le déplacement

        XCTAssertEqual(store.todos.map(\.title), ["B", "A"])
    }

    func testFrenchDateAtEndSetsDueDateAndLeavesTitle() {
        [
            "Appeler le véto demain", "Sport Après-demain", "Courses lundi", "Ménage vendredi",
            "Payer le loyer le 20 !", "Rendre le livre le 3", "Banque le 14", "Gâteau pour le 1er", "Arroser aujourd’hui",
        ].forEach(store.add)

        XCTAssertEqual(due("Appeler le véto"), day(1, 16))
        XCTAssertEqual(due("Sport"), day(1, 17))
        XCTAssertEqual(due("Courses"), day(1, 18))
        XCTAssertEqual(due("Ménage"), day(1, 22)) // vendredi un vendredi : la semaine prochaine
        XCTAssertEqual(due("Payer le loyer"), day(1, 20))
        XCTAssertEqual(store.todos.first { $0.title == "Payer le loyer" }?.isPriority, true)
        XCTAssertEqual(due("Rendre le livre"), day(2, 3)) // jour passé : le mois suivant
        XCTAssertEqual(due("Banque"), day(2, 14))
        XCTAssertEqual(due("Gâteau"), day(2, 1))
        XCTAssertEqual(due("Arroser"), day(1, 15))
    }

    func testDateWordsElsewhereOrAloneAreKeptInTitle() {
        ["demain", "Demain matin réunion", "Revoir le 40", "Payer ! demain"].forEach(store.add)

        XCTAssertEqual(store.todos.compactMap(\.dueDate), [day(1, 16)])
        XCTAssertEqual(Set(store.todos.map(\.title)), ["demain", "Demain matin réunion", "Revoir le 40", "Payer"])
    }

    func testLaterTasksComeAfterTodayAndJoinItOnTheirDay() {
        ["B lundi", "C demain", "A"].forEach(store.add)
        XCTAssertEqual(store.today.map(\.title), ["A"])
        XCTAssertEqual(store.later.map(\.title), ["C", "B"])
        XCTAssertEqual(store.summary, "Doneko — 1 tâche sur la table")

        clock.current += 86_400
        store.refreshDay()
        XCTAssertEqual(store.today.map(\.title), ["C", "A"])
        XCTAssertEqual(store.later.map(\.title), ["B"])

        store.move(store.later[0].id, to: store.today[0].id) // pas de passage d'une section à l'autre
        XCTAssertEqual(store.todos.map(\.title), ["C", "A", "B"])
    }

    func testEditKeepsDueDateUnlessANewOneIsTyped() {
        store.add("A demain")
        let id = store.todos[0].id

        store.edit(id, title: "A2")
        XCTAssertEqual(store.later.map(\.title), ["A2"])

        store.edit(id, title: "A2 aujourd'hui")
        XCTAssertEqual(store.today.map(\.title), ["A2"])

        store.undo()
        XCTAssertEqual(store.later.map(\.title), ["A2"])
    }

    func testSummaryCountsRemainingTasksWithPlural() {
        XCTAssertEqual(store.summary, "Doneko — plus rien sur la table")
        store.add("A")
        XCTAssertEqual(store.summary, "Doneko — 1 tâche sur la table")
        store.add("B")
        store.add("C")
        store.complete(store.todos[0].id)
        XCTAssertEqual(store.summary, "Doneko — 2 tâches sur la table")
    }

    func testUndoIsLastInFirstOutAndKeepsLaterAdds() {
        store.add("A")
        let id = store.todos[0].id
        store.complete(id)
        store.add("B")
        store.delete(id)

        store.undo() // annule la suppression : A revient, toujours faite
        XCTAssertEqual(store.done.map(\.title), ["A"])
        store.undo() // annule la complétion
        XCTAssertEqual(store.todos.map(\.title), ["A", "B"])
        XCTAssertFalse(store.canUndo)

        store.undo() // pile vide : rien ne se passe
        XCTAssertEqual(store.todos.map(\.title), ["A", "B"])
    }
}

import XCTest
@testable import Doneko

final class FakeClock: Clock {
    var current = Date(timeIntervalSince1970: 1_800_000_000)
    func now() -> Date { current }
}

final class TodoStoreTests: XCTestCase {
    private var clock: FakeClock!
    private var store: TodoStore!

    override func setUp() {
        super.setUp()
        clock = FakeClock()
        store = TodoStore(clock: clock)
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

import XCTest
@testable import Doneko

final class FolderTests: XCTestCase {
    private var clock: FakeClock!
    private var store: TodoStore!
    private var calendar = Calendar(identifier: .gregorian)

    override func setUp() {
        super.setUp()
        calendar.timeZone = TimeZone(identifier: "UTC")!
        clock = FakeClock() // vendredi 15 janvier 2027, 8 h UTC
        store = TodoStore(clock: clock, calendar: calendar)
    }

    private func task(_ title: String) -> TodoItem {
        (store.todos + store.done).first { $0.title == title }!
    }

    func testAddFolderTrimsTheNameAndReusesAnExistingOne() {
        let courses = store.addFolder("  Courses ")
        let maison = store.addFolder("Maison")

        XCTAssertEqual(store.addFolder("courses"), courses)
        XCTAssertNil(store.addFolder("   "))
        XCTAssertEqual(store.folders.map(\.name), ["Courses", "Maison"])
        XCTAssertEqual(store.folders.map(\.id), [courses, maison])
    }

    func testHashtagFilesTheTaskAndCreatesTheFolder() {
        store.add("Lait #courses demain !")
        store.add("Pain #Courses")

        let lait = task("Lait")
        XCTAssertTrue(lait.isPriority)
        XCTAssertEqual(lait.dueDate, calendar.date(from: DateComponents(year: 2027, month: 1, day: 16)))
        XCTAssertEqual(store.folders.map(\.name), ["courses"])
        XCTAssertEqual(lait.folderID, store.folders[0].id)
        XCTAssertEqual(task("Pain").folderID, store.folders[0].id)
    }

    func testChosenFolderReceivesNewTasksAndFiltersTheLists() {
        let maison = store.addFolder("Maison")
        store.add("Litière", in: maison)
        store.add("Banque")
        store.add("Croquettes #courses", in: maison)
        store.add("Aspirateur demain", in: maison)

        XCTAssertEqual(store.today(in: maison).map(\.title), ["Litière"])
        XCTAssertEqual(store.later(in: maison).map(\.title), ["Aspirateur"])
        XCTAssertEqual(store.todos.count, 4)

        store.complete(task("Litière").id)
        XCTAssertEqual(store.done(in: maison).map(\.title), ["Litière"])
        XCTAssertEqual(store.done(in: store.addFolder("courses")), [])
    }

    func testFilingAndEditingMoveATaskAndUndoPutsItBack() {
        let courses = store.addFolder("Courses")
        store.add("Lait")

        store.file(task("Lait").id, in: courses)
        XCTAssertEqual(task("Lait").folderID, courses)

        store.edit(task("Lait").id, title: "Lait demi-écrémé")
        XCTAssertEqual(task("Lait demi-écrémé").folderID, courses)

        store.edit(task("Lait demi-écrémé").id, title: "Lait #maison")
        XCTAssertEqual(store.folder(of: task("Lait"))?.name, "maison")

        store.undo()
        XCTAssertEqual(task("Lait demi-écrémé").folderID, courses)
        store.file(task("Lait demi-écrémé").id, in: nil)
        XCTAssertNil(task("Lait demi-écrémé").folderID)
    }

    func testRenameAndReorderFolders() {
        let courses = store.addFolder("Courses")!
        let maison = store.addFolder("Maison")!
        let travail = store.addFolder("Travail")!

        store.renameFolder(courses, to: " Marché ")
        store.renameFolder(maison, to: "marché") // déjà pris : ignoré
        store.moveFolder(travail, to: courses)

        XCTAssertEqual(store.folders.map(\.name), ["Travail", "Marché", "Maison"])
    }

    func testDeletingAFolderReturnsItsTasksToEverythingUntilUndo() {
        let courses = store.addFolder("Courses")!
        store.add("Lait", in: courses)
        store.add("Pain", in: courses)

        store.deleteFolder(courses)
        XCTAssertEqual(store.folders, [])
        XCTAssertEqual(store.todos.compactMap(\.folderID), [])

        store.undo()
        XCTAssertEqual(store.folders.map(\.name), ["Courses"])
        XCTAssertEqual(store.todos(in: courses).map(\.title), ["Lait", "Pain"])
    }

    func testFoldersReachTheOtherDevice() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let shared = Persistence(url: directory.appendingPathComponent("todos.json"))
        let phoneClock = FakeClock()
        let mac = TodoStore(persistence: shared, clock: clock, calendar: calendar)
        let phone = TodoStore(persistence: shared, clock: phoneClock, calendar: calendar)

        mac.add("Lait #courses")
        phone.reloadIfChangedOnDisk()
        XCTAssertEqual(phone.folders.map(\.name), ["courses"])
        XCTAssertEqual(phone.todos(in: phone.folders[0].id).map(\.title), ["Lait"])

        phoneClock.current += 60
        phone.deleteFolder(phone.folders[0].id)
        mac.reloadIfChangedOnDisk()
        XCTAssertEqual(mac.folders, [])
        XCTAssertNil(mac.todos[0].folderID)
        XCTAssertEqual(shared.load().folders.count, 1) // gardé 30 jours pour l'autre appareil
    }
}

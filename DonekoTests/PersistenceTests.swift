import XCTest
@testable import Doneko

final class PersistenceTests: XCTestCase {
    private var directory: URL!
    private var persistence: Persistence!

    override func setUp() {
        super.setUp()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        // Sous-dossier inexistant : save doit le créer.
        persistence = Persistence(url: directory.appendingPathComponent("Doneko/todos.json"))
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
        super.tearDown()
    }

    func testLoadWithoutFileReturnsEmptyList() {
        XCTAssertEqual(persistence.load(), [])
    }

    func testSaveThenLoadRoundTripsEveryField() throws {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let items = [
            TodoItem(title: "Faite", createdAt: date, completedAt: date + 60, isPriority: true, dueDate: date + 3600, order: 0),
            TodoItem(title: "À faire", createdAt: date, order: 1),
        ]

        try persistence.save(items)

        XCTAssertEqual(persistence.load(), items)
    }

    func testCorruptedFileIsMovedToBakAndLoadsEmpty() throws {
        try persistence.save([])
        try Data("pas du json".utf8).write(to: persistence.url)

        XCTAssertEqual(persistence.load(), [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: persistence.url.path))
        XCTAssertEqual(try String(contentsOf: persistence.backupURL, encoding: .utf8), "pas du json")
    }

    func testStoreSavesEveryChangeAndReloadsIt() {
        let store = TodoStore(persistence: persistence, clock: FakeClock())
        store.add("A")
        store.add("B")
        store.complete(store.todos[0].id)
        store.delete(store.todos[0].id)
        store.undo()

        let reloaded = TodoStore(persistence: persistence, clock: FakeClock())

        XCTAssertEqual(reloaded.todos, store.todos)
        XCTAssertEqual(reloaded.done, store.done)
        XCTAssertEqual(reloaded.todos.map(\.title), ["B"])
        XCTAssertEqual(reloaded.done.map(\.title), ["A"])
    }

    /// Doneko 1.1 n'écrivait ni `updatedAt` ni `deletedAt`.
    func testFileFromVersion1StillLoads() throws {
        try persistence.save([])
        let json = #"[{"createdAt":"2027-01-15T08:00:00Z","id":"6F1C1E52-8B0A-4F7C-9A11-2D8E5B7C4A10","isPriority":false,"order":0,"title":"Lait"}]"#
        try Data(json.utf8).write(to: persistence.url)

        XCTAssertEqual(persistence.load().map(\.title), ["Lait"])
    }
}

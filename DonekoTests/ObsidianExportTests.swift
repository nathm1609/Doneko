import XCTest
@testable import Doneko

final class ObsidianExportTests: XCTestCase {
    private var clock: FakeClock!
    private var store: TodoStore!
    private var defaults: UserDefaults!
    private var folder: URL!
    private var export: ObsidianExport!

    override func setUpWithError() throws {
        try super.setUpWithError()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        clock = FakeClock() // 15 janvier 2027, 08:00 UTC
        store = TodoStore(clock: clock, calendar: calendar)
        defaults = UserDefaults(suiteName: "ObsidianExportTests")!
        defaults.removePersistentDomain(forName: "ObsidianExportTests")
        folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defaults.set(folder.path, forKey: SettingsKey.obsidianFolder)
        export = ObsidianExport(store: store, defaults: defaults, calendar: calendar)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
        try super.tearDownWithError()
    }

    private var note: URL { folder.appendingPathComponent("2027-01-15.md") }

    private func complete(_ title: String) {
        store.add(title)
        store.complete(store.todos.first { $0.title == title }!.id)
        export.sync()
    }

    func testMergeCreatesSectionAfterExistingContent() {
        XCTAssertEqual(ObsidianExport.merge("", ensuring: ["A"], removing: []), "## Fait avec Doneko\n- [x] A\n")
        XCTAssertEqual(
            ObsidianExport.merge("# Journal\nRéunion", ensuring: ["A"], removing: []),
            "# Journal\nRéunion\n\n## Fait avec Doneko\n- [x] A\n"
        )
        XCTAssertEqual(ObsidianExport.merge("Rien", ensuring: [], removing: ["A"]), "Rien")
    }

    func testMergeAddsAndRemovesInsideSectionOnly() {
        let note = "## Fait avec Doneko\n- [x] A\n\n## Notes\n- [x] A\nIdées\n"

        XCTAssertEqual(
            ObsidianExport.merge(note, ensuring: ["A", "B"], removing: []),
            "## Fait avec Doneko\n- [x] A\n- [x] B\n\n## Notes\n- [x] A\nIdées\n"
        )
        XCTAssertEqual(
            ObsidianExport.merge(note, ensuring: [], removing: ["A"]),
            "## Fait avec Doneko\n\n## Notes\n- [x] A\nIdées\n"
        )
        // Deux tâches du même nom : deux lignes, pas plus.
        XCTAssertEqual(
            ObsidianExport.merge(note, ensuring: ["A", "A"], removing: []),
            "## Fait avec Doneko\n- [x] A\n- [x] A\n\n## Notes\n- [x] A\nIdées\n"
        )
    }

    func testCompletedTasksGoToTheNoteOfTheDayAndUncheckedOnesLeaveIt() throws {
        try "# 15 janvier\nRéunion à 10 h\n".write(to: note, atomically: true, encoding: .utf8)

        complete("Payer le loyer")
        clock.current += 60
        complete("Arroser le basilic")
        XCTAssertEqual(
            try String(contentsOf: note, encoding: .utf8),
            "# 15 janvier\nRéunion à 10 h\n\n## Fait avec Doneko\n- [x] Payer le loyer\n- [x] Arroser le basilic\n"
        )

        store.uncomplete(store.done.first { $0.title == "Payer le loyer" }!.id)
        export.sync()
        XCTAssertEqual(
            try String(contentsOf: note, encoding: .utf8),
            "# 15 janvier\nRéunion à 10 h\n\n## Fait avec Doneko\n- [x] Arroser le basilic\n"
        )
    }

    func testPurgeAndDeleteKeepExportedLines() throws {
        complete("A")
        complete("B")
        store.delete(store.done.first { $0.title == "B" }!.id)
        clock.current += 24 * 3600
        store.purgeDone()
        export.sync()

        XCTAssertEqual(try String(contentsOf: note, encoding: .utf8), "## Fait avec Doneko\n- [x] A\n- [x] B\n")
    }

    func testExportFollowsTheStoreOnItsOwn() throws {
        store.add("A")
        store.complete(store.todos[0].id)
        RunLoop.main.run(until: Date().addingTimeInterval(0.2)) // l'observation exporte sur la file principale

        XCTAssertEqual(try String(contentsOf: note, encoding: .utf8), "## Fait avec Doneko\n- [x] A\n")
    }

    func testTasksAlreadyDoneAtLaunchAreExportedBeforeThePurge() throws {
        // Tombée sur l'iPhone hier soir, pendant que Doneko était quitté sur le Mac.
        store.add("Sur l'iPhone")
        store.complete(store.todos[0].id)
        clock.current += 24 * 3600
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        // Au lancement du Mac : l'export d'abord, puis la purge quotidienne.
        export = ObsidianExport(store: store, defaults: defaults, calendar: calendar)
        store.purgeDone()

        XCTAssertEqual(try String(contentsOf: note, encoding: .utf8), "## Fait avec Doneko\n- [x] Sur l'iPhone\n")
    }

    func testNothingIsWrittenWithoutFolder() {
        defaults.removeObject(forKey: SettingsKey.obsidianFolder)
        complete("A")
        XCTAssertFalse(FileManager.default.fileExists(atPath: note.path))
    }
}

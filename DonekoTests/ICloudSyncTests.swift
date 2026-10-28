import XCTest
@testable import Doneko

final class ICloudSyncTests: XCTestCase {
    private var directory: URL!
    private var local: Persistence!
    private var remote: Persistence!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        local = Persistence(url: directory.appendingPathComponent("local/todos.json"))
        remote = Persistence(url: directory.appendingPathComponent("iCloud/Doneko/todos.json"))
        defaults = UserDefaults(suiteName: "ICloudSyncTests")!
        defaults.removePersistentDomain(forName: "ICloudSyncTests")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
        super.tearDown()
    }

    /// L'autre Mac : déjà synchronisé, avec ses tâches.
    @discardableResult
    private func otherMac(_ titles: [String]) -> TodoStore {
        let store = TodoStore(persistence: remote)
        titles.forEach(store.add)
        return store
    }

    func testJoiningICloudMergesBothListsAndLeavingKeepsThem() {
        otherMac(["A", "B"])
        let store = TodoStore(persistence: local)
        store.add("C")

        XCTAssertTrue(store.relocate(to: remote, merging: true))
        XCTAssertEqual(Set(store.todos.map(\.title)), ["A", "B", "C"])
        XCTAssertEqual(Set(remote.load().map(\.title)), ["A", "B", "C"])

        store.add("D")
        XCTAssertTrue(store.relocate(to: local, merging: false))
        XCTAssertEqual(Set(local.load().map(\.title)), ["A", "B", "C", "D"])
        XCTAssertEqual(remote.load().count, 4)
    }

    func testChangesFromAnotherMacAreReloadedButOwnWritesAreNot() {
        let other = otherMac(["A"])
        let store = TodoStore(persistence: remote)

        other.add("B")
        store.reloadIfChangedOnDisk()
        XCTAssertEqual(store.todos.map(\.title), ["A", "B"])

        store.complete(store.todos[0].id)
        store.reloadIfChangedOnDisk() // notre propre écriture : l'annulation reste possible
        XCTAssertTrue(store.canUndo)
    }

    func testUnreadableOrMissingFileKeepsTheList() throws {
        let store = TodoStore(persistence: remote)
        store.add("A")

        try Data("pas du JSON".utf8).write(to: remote.url)
        store.reloadIfChangedOnDisk()
        try FileManager.default.removeItem(at: remote.url)
        store.reloadIfChangedOnDisk()

        XCTAssertEqual(store.todos.map(\.title), ["A"])
    }

    func testUnreadableICloudFileIsNotOverwrittenWhenJoining() throws {
        try FileManager.default.createDirectory(at: remote.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let unreadable = Data("pas du JSON".utf8)
        try unreadable.write(to: remote.url)
        let store = TodoStore(persistence: local)
        store.add("A")

        XCTAssertFalse(store.relocate(to: remote, merging: true))
        XCTAssertEqual(try Data(contentsOf: remote.url), unreadable)
        XCTAssertEqual(local.load().map(\.title), ["A"])
    }

    func testRefusedWriteKeepsCurrentFile() {
        let store = TodoStore(persistence: local)
        store.add("A")

        XCTAssertFalse(store.relocate(to: Persistence(url: URL(fileURLWithPath: "/dev/null/Doneko/todos.json")), merging: true))
        store.add("B")

        XCTAssertEqual(local.load().map(\.title), ["A", "B"])
    }

    func testSettingMovesTheListBetweenThisMacAndICloud() {
        otherMac(["A"])
        let store = TodoStore(persistence: local)
        store.add("B")
        let sync = ICloudSync(store: store, defaults: defaults, local: local, remote: remote, isDriveAvailable: true)

        defaults.set(true, forKey: SettingsKey.iCloudSync)
        XCTAssertEqual(Set(remote.load().map(\.title)), ["A", "B"])

        otherMac([]).add("C")
        sync.check()
        XCTAssertEqual(Set(store.todos.map(\.title)), ["A", "B", "C"])

        defaults.set(false, forKey: SettingsKey.iCloudSync)
        store.add("D")
        XCTAssertEqual(local.load().count, 4)
        XCTAssertEqual(remote.load().count, 3)
    }

    func testAnotherMacsChangesArriveOnTheirOwn() {
        defaults.set(true, forKey: SettingsKey.iCloudSync)
        let store = TodoStore(persistence: remote)
        let sync = ICloudSync(store: store, defaults: defaults, local: local, remote: remote, isDriveAvailable: true, checkInterval: 0.05)

        otherMac(["A"])
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))

        XCTAssertEqual(store.todos.map(\.title), ["A"])
        withExtendedLifetime(sync) {}
    }

    func testSettingIsIgnoredWithoutICloudDrive() {
        let store = TodoStore(persistence: local)
        let sync = ICloudSync(store: store, defaults: defaults, local: local, remote: remote, isDriveAvailable: false)

        defaults.set(true, forKey: SettingsKey.iCloudSync)
        store.add("A")
        sync.check()

        XCTAssertEqual(local.load().map(\.title), ["A"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: remote.url.path))
    }
}

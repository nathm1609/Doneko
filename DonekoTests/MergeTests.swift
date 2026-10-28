import XCTest
@testable import Doneko

/// Le Mac et l'iPhone sur le même fichier iCloud, chacun avec sa propre horloge.
final class MergeTests: XCTestCase {
    private var directory: URL!
    private var shared: Persistence!
    private var macClock: FakeClock!
    private var phoneClock: FakeClock!

    override func setUp() {
        super.setUp()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        shared = Persistence(url: directory.appendingPathComponent("iCloud/todos.json"))
        macClock = FakeClock()
        phoneClock = FakeClock()
    }

    override func tearDown() {
        try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: shared.url.path)
        try? FileManager.default.removeItem(at: directory)
        super.tearDown()
    }

    private func id(_ title: String, in store: TodoStore) -> TodoItem.ID {
        (store.todos + store.done).first { $0.title == title }!.id
    }

    /// iCloud remplace la copie d'un appareil par celle de l'autre.
    private func copy(_ source: Persistence, to destination: Persistence) throws {
        try FileManager.default.createDirectory(at: destination.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: destination.url)
        try FileManager.default.copyItem(at: source.url, to: destination.url)
    }

    func testOfflineChangesOnBothDevicesAreAllKept() throws {
        let phoneFile = Persistence(url: directory.appendingPathComponent("iPhone/todos.json"))
        let mac = TodoStore(persistence: shared, clock: macClock)
        ["Lait", "Pain", "Courrier"].forEach { mac.add($0) }
        try copy(shared, to: phoneFile)
        let phone = TodoStore(persistence: phoneFile, clock: phoneClock)

        // Hors ligne, chacun modifie sa copie ; la même tâche est renommée des deux côtés.
        macClock.current += 60
        mac.complete(id("Lait", in: mac))
        mac.delete(id("Courrier", in: mac))
        mac.edit(id("Pain", in: mac), title: "Baguette")
        mac.add("Banque")
        phoneClock.current += 120
        phone.edit(id("Pain", in: phone), title: "Pain complet")
        phone.add("Croquettes")

        // De retour en ligne : iCloud garde la version de l'iPhone, le Mac la fusionne et renvoie le résultat.
        try copy(phoneFile, to: shared)
        mac.reloadIfChangedOnDisk()
        try copy(shared, to: phoneFile)
        phone.reloadIfChangedOnDisk()

        XCTAssertEqual(Set(mac.todos.map(\.title)), ["Pain complet", "Banque", "Croquettes"])
        XCTAssertEqual(mac.done.map(\.title), ["Lait"])
        XCTAssertEqual(phone.items, mac.items)
    }

    func testSameSecondEditsEndUpIdenticalOnBothDevices() throws {
        let phoneFile = Persistence(url: directory.appendingPathComponent("iPhone/todos.json"))
        let mac = TodoStore(persistence: shared, clock: macClock)
        mac.add("Pain")
        try copy(shared, to: phoneFile)
        let phone = TodoStore(persistence: phoneFile, clock: phoneClock)

        mac.edit(id("Pain", in: mac), title: "Baguette")
        phone.edit(id("Pain", in: phone), title: "Pain complet")
        try copy(phoneFile, to: shared)
        mac.reloadIfChangedOnDisk()
        try copy(shared, to: phoneFile)
        phone.reloadIfChangedOnDisk()

        // Le même gagnant des deux côtés : personne ne réécrit sa version en boucle.
        XCTAssertEqual(phone.items, mac.items)
    }

    func testSavingKeepsWhatTheOtherDeviceJustWrote() {
        let mac = TodoStore(persistence: shared, clock: macClock)
        let phone = TodoStore(persistence: shared, clock: phoneClock)

        phone.add("Croquettes") // le Mac ne l'a pas encore relu
        mac.add("Banque")

        XCTAssertEqual(Set(shared.load().items.map(\.title)), ["Croquettes", "Banque"])
        XCTAssertEqual(Set(mac.todos.map(\.title)), ["Croquettes", "Banque"])
    }

    func testDeletionPurgeAndUndoReachTheOtherDevice() {
        let mac = TodoStore(persistence: shared, clock: macClock)
        ["Lait", "Pain"].forEach { mac.add($0) }
        let phone = TodoStore(persistence: shared, clock: phoneClock)

        macClock.current += 60
        mac.complete(id("Lait", in: mac))
        mac.delete(id("Pain", in: mac))
        phone.reloadIfChangedOnDisk()
        XCTAssertEqual(phone.todos, [])
        XCTAssertEqual(phone.done.map(\.title), ["Lait"])

        macClock.current += 60
        mac.undo()
        macClock.current += 86_400
        mac.purgeDone()
        phone.reloadIfChangedOnDisk()
        XCTAssertEqual(phone.todos.map(\.title), ["Pain"])
        XCTAssertEqual(phone.done, [])
    }

    func testDeletedTasksAreForgottenAfterThirtyDays() {
        let mac = TodoStore(persistence: shared, clock: macClock)
        mac.add("Lait")
        mac.delete(id("Lait", in: mac))
        XCTAssertEqual(shared.load().items.count, 1)

        macClock.current += 29 * 86_400
        mac.purgeDone()
        XCTAssertEqual(shared.load().items.count, 1)

        macClock.current += 2 * 86_400
        mac.purgeDone()
        XCTAssertEqual(shared.load().items, [])
    }

    /// Fichier présent mais pas encore lisible (iCloud le télécharge) : ni mis de côté, ni écrasé par une liste vide.
    func testFileNotReadableYetIsNeitherSetAsideNorOverwritten() throws {
        TodoStore(persistence: shared, clock: macClock).add("Lait")
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: shared.url.path)
        let phone = TodoStore(persistence: shared, clock: phoneClock)
        phone.add("Croquettes")
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: shared.url.path)

        XCTAssertFalse(FileManager.default.fileExists(atPath: shared.backupURL.path))
        XCTAssertEqual(shared.load().items.map(\.title), ["Lait"])

        phone.reloadIfChangedOnDisk()
        XCTAssertEqual(Set(shared.load().items.map(\.title)), ["Lait", "Croquettes"])
    }
}

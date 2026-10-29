import XCTest
@testable import Doneko

final class UpdaterTests: XCTestCase {
    private func answer(tag: String = "v1.4.0", url: String = "https://github.com/nathm1609/Doneko/releases/download/v1.4.0/Doneko.dmg",
                        digest: String? = "sha256:\(String(repeating: "ab", count: 32))") -> Data {
        let digestField = digest.map { ", \"digest\": \"\($0)\"" } ?? ""
        return Data("""
        { "tag_name": "\(tag)", "assets": [
            { "name": "Notes.txt", "browser_download_url": "https://github.com/x/Notes.txt" },
            { "name": "Doneko.dmg", "browser_download_url": "\(url)"\(digestField) }
        ] }
        """.utf8)
    }

    func testReleaseIsReadFromGitHubAnswer() throws {
        let release = try Updater.release(from: answer())

        XCTAssertEqual(release.version, "1.4.0")
        XCTAssertEqual(release.dmg.absoluteString, "https://github.com/nathm1609/Doneko/releases/download/v1.4.0/Doneko.dmg")
        XCTAssertEqual(release.sha256, String(repeating: "ab", count: 32))
    }

    func testReleaseWithoutDigestOrFromElsewhereIsRefused() {
        XCTAssertThrowsError(try Updater.release(from: answer(digest: nil)))
        XCTAssertThrowsError(try Updater.release(from: answer(url: "https://exemple.com/Doneko.dmg")))
        XCTAssertThrowsError(try Updater.release(from: answer(url: "http://github.com/Doneko.dmg")))
    }

    func testVersionsCompareNumerically() {
        XCTAssertTrue(Updater.isVersion("1.4.0", newerThan: "1.3.0"))
        XCTAssertTrue(Updater.isVersion("1.10.0", newerThan: "1.9.2"))
        XCTAssertFalse(Updater.isVersion("1.3.0", newerThan: "1.3.0"))
        XCTAssertFalse(Updater.isVersion("1.2.1", newerThan: "1.3.0"))
    }
}

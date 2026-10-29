import AppKit
import CryptoKit
import Observation

/// Réglage « Mise à jour » : la dernière release GitHub et, si elle est plus récente, son `Doneko.dmg` installé à la
/// place de l'app, puis relancé. Rien ne passe par le réseau tant qu'on n'a pas cliqué.
@MainActor @Observable
final class Updater {
    struct Release: Equatable {
        let version: String
        let dmg: URL
        let sha256: String
    }

    enum State: Equatable {
        case idle, checking, upToDate, checkFailed
        case available(Release)
        case installing, installFailed
    }

    private(set) var state = State.idle

    static let latestRelease = URL(string: "https://api.github.com/repos/nathm1609/Doneko/releases/latest")!
    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    func check() async {
        state = .checking
        do {
            var request = URLRequest(url: Self.latestRelease)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, _) = try await URLSession.shared.data(for: request)
            let release = try Self.release(from: data)
            state = Self.isVersion(release.version, newerThan: Self.currentVersion) ? .available(release) : .upToDate
        } catch {
            NSLog("Doneko : recherche de mise à jour impossible (\(error))")
            state = .checkFailed
        }
    }

    func install(_ release: Release) async {
        state = .installing
        do {
            try await Self.install(release, replacing: Bundle.main.bundleURL)
            Self.relaunch()
        } catch {
            NSLog("Doneko : mise à jour impossible (\(error))")
            state = .installFailed
        }
    }

    /// Réponse de l'API GitHub → release. Refusée sans `Doneko.dmg` servi par github.com en HTTPS, ni empreinte SHA-256.
    nonisolated static func release(from data: Data) throws -> Release {
        struct Answer: Decodable {
            struct Asset: Decodable { let name: String; let browserDownloadUrl: URL; let digest: String? }
            let tagName: String
            let assets: [Asset]
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let answer = try decoder.decode(Answer.self, from: data)
        guard let dmg = answer.assets.first(where: { $0.name == "Doneko.dmg" }),
              dmg.browserDownloadUrl.scheme == "https", dmg.browserDownloadUrl.host == "github.com",
              let digest = dmg.digest, digest.hasPrefix("sha256:")
        else { throw Failure("pas de Doneko.dmg vérifiable dans la release") }
        let version = answer.tagName.hasPrefix("v") ? String(answer.tagName.dropFirst()) : answer.tagName
        return Release(version: version, dmg: dmg.browserDownloadUrl, sha256: String(digest.dropFirst("sha256:".count)))
    }

    /// « 1.10.0 » est plus récent que « 1.9.2 ».
    nonisolated static func isVersion(_ version: String, newerThan other: String) -> Bool {
        version.compare(other, options: .numeric) == .orderedDescending
    }

    /// Télécharge le DMG, vérifie son empreinte et l'app qu'il contient, puis l'échange avec `app` : une copie complète
    /// est préparée à côté (même volume), l'app en place n'est donc jamais à moitié remplacée.
    nonisolated static func install(_ release: Release, replacing app: URL) async throws {
        let (download, _) = try await URLSession.shared.download(from: release.dmg)
        defer { try? FileManager.default.removeItem(at: download) }
        let digest = SHA256.hash(data: try Data(contentsOf: download)).map { String(format: "%02x", $0) }.joined()
        guard digest == release.sha256 else { throw Failure("empreinte du DMG différente de celle de GitHub") }

        let mount = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try run("/usr/bin/hdiutil", "attach", download.path, "-readonly", "-nobrowse", "-noautoopen", "-quiet",
                "-mountpoint", mount.path)
        defer { try? run("/usr/bin/hdiutil", "detach", mount.path, "-quiet") }
        let new = mount.appendingPathComponent("Doneko.app")
        guard let bundle = Bundle(url: new), bundle.bundleIdentifier == "com.nathanmarchant.doneko",
              bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String == release.version
        else { throw Failure("le DMG ne contient pas Doneko \(release.version)") }

        let staged = app.deletingLastPathComponent().appendingPathComponent(".Doneko-\(release.version).app")
        try? FileManager.default.removeItem(at: staged)
        try FileManager.default.copyItem(at: new, to: staged)
        do {
            _ = try FileManager.default.replaceItemAt(app, withItemAt: staged)
        } catch {
            try? FileManager.default.removeItem(at: staged)
            throw error
        }
    }

    /// Relance l'app depuis le même emplacement une fois celle-ci quittée (le raccourci global n'est libre qu'après).
    private static func relaunch() {
        let relaunch = Process()
        relaunch.executableURL = URL(fileURLWithPath: "/bin/sh")
        relaunch.arguments = ["-c", "while kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do sleep 0.2; done; open \"$0\"",
                              Bundle.main.bundlePath]
        try? relaunch.run()
        NSApp.terminate(nil)
    }

    private nonisolated static func run(_ tool: String, _ arguments: String...) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw Failure("\(tool) a échoué (\(process.terminationStatus))") }
    }

    struct Failure: Error, CustomStringConvertible {
        let description: String
        init(_ description: String) { self.description = description }
    }
}

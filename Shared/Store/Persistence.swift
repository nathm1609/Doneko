import Foundation

/// Lecture / écriture de la liste dans un fichier JSON.
struct Persistence {
    static let defaultURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Doneko", isDirectory: true)
        .appendingPathComponent("todos.json")

    let url: URL

    init(url: URL = Persistence.defaultURL) {
        self.url = url
    }

    var backupURL: URL { url.appendingPathExtension("bak") }

    /// Fichier absent → liste vide. Fichier abîmé → mis de côté en `.bak`, liste vide, jamais de crash.
    /// Fichier pas encore téléchargé ou pas accessible → liste vide, mais il n'est pas abîmé : on n'y touche pas.
    func load() -> [TodoItem] {
        let data: Data
        do {
            guard let current = try currentData() else { return [] }
            data = current
        } catch {
            NSLog("Doneko : todos.json pas lisible pour l'instant (\(error))")
            return []
        }
        do {
            return try Self.decode(data)
        } catch {
            NSLog("Doneko : todos.json illisible (\(error)), renommé en todos.json.bak")
            try? FileManager.default.removeItem(at: backupURL)
            try? FileManager.default.moveItem(at: url, to: backupURL)
            return []
        }
    }

    /// Contenu du fichier, `nil` s'il n'existe pas. Fichier iCloud pas à jour sur cet appareil : iCloud est prié de
    /// télécharger la dernière version et l'erreur rend la main tout de suite, sans bloquer l'écran pendant ce temps.
    func currentData() throws -> Data? {
        var url = url
        url.removeAllCachedResourceValues()
        if let status = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]).ubiquitousItemDownloadingStatus,
           status != .current {
            try? FileManager.default.startDownloadingUbiquitousItem(at: url)
            throw CocoaError(.fileReadUnknown)
        }
        do {
            return try data()
        } catch CocoaError.fileReadNoSuchFile {
            return nil
        }
    }

    /// Versions qu'iCloud a mises de côté quand deux appareils ont écrit sans se voir (l'un était hors ligne), avec
    /// leur liste. Celles qu'on ne sait pas lire sont ignorées et restent là.
    /// shortcut: aucun test automatique (il faut un vrai conflit iCloud) ; vérifié par le scénario hors ligne sur iPhone.
    func conflicts() -> [(version: NSFileVersion, items: [TodoItem])] {
        (NSFileVersion.unresolvedConflictVersionsOfItem(at: url) ?? []).compactMap { version in
            (try? Self.decode(Data(contentsOf: version.url))).map { (version, $0) }
        }
    }

    /// Versions dont la liste a été fusionnée puis enregistrée : iCloud peut les oublier.
    func resolve(_ versions: [NSFileVersion]) {
        for version in versions {
            version.isResolved = true
            try? version.remove()
        }
    }

    /// Liste du fichier, `nil` s'il n'existe pas, erreur s'il est illisible.
    func read() throws -> [TodoItem]? {
        do {
            return try Self.decode(data())
        } catch CocoaError.fileReadNoSuchFile {
            return nil
        }
    }

    /// Contenu du fichier, lu en coordination avec iCloud : il finit d'abord de le télécharger ou de l'écrire.
    func data() throws -> Data {
        var result: Result<Data, Error> = .failure(CocoaError(.fileReadUnknown))
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(readingItemAt: url, error: &coordinationError) { url in
            result = Result { try Data(contentsOf: url) }
        }
        if let coordinationError { throw coordinationError }
        return try result.get()
    }

    /// Écriture atomique (fichier temporaire puis remplacement), coordonnée avec iCloud.
    func save(_ items: [TodoItem]) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try Self.encode(items)
        var result: Result<Void, Error> = .success(())
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) { url in
            result = Result { try data.write(to: url, options: .atomic) }
        }
        if let coordinationError { throw coordinationError }
        try result.get()
    }

    /// Toujours le même contenu pour la même liste : on reconnaît ainsi un fichier qu'on vient d'écrire.
    static func encode(_ items: [TodoItem]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(items)
    }

    static func decode(_ data: Data) throws -> [TodoItem] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([TodoItem].self, from: data)
    }
}

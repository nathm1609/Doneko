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

    /// Fichier absent → liste vide. Fichier illisible → mis de côté en `.bak`, liste vide, jamais de crash.
    /// shortcut: sur iPhone hors ligne, un fichier iCloud pas encore téléchargé compte comme illisible ;
    /// la fusion tâche par tâche (étape 3 de PLAN-V3.md) évitera alors d'écraser la liste du Mac.
    func load() -> [TodoItem] {
        do {
            return try read() ?? []
        } catch {
            NSLog("Doneko : todos.json illisible (\(error)), renommé en todos.json.bak")
            try? FileManager.default.removeItem(at: backupURL)
            try? FileManager.default.moveItem(at: url, to: backupURL)
            return []
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

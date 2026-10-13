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
    func load() -> [TodoItem] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([TodoItem].self, from: Data(contentsOf: url))
        } catch {
            NSLog("Doneko : todos.json illisible (\(error)), renommé en todos.json.bak")
            try? FileManager.default.removeItem(at: backupURL)
            try? FileManager.default.moveItem(at: url, to: backupURL)
            return []
        }
    }

    /// Écriture atomique : fichier temporaire puis remplacement.
    func save(_ items: [TodoItem]) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(items).write(to: url, options: .atomic)
    }
}

import Foundation
import Observation

/// Synchronisation sur iPhone. Sans compte développeur payant, l'app n'a pas d'accès direct à iCloud Drive : on choisit
/// une fois dans Fichiers le dossier `iCloud Drive › Doneko` (celui de la sync Mac), et l'accès est mémorisé (signet).
/// La liste y vit alors (`todos.json`), et ce que le Mac y change est fusionné toutes les 5 s quand l'app est ouverte,
/// au retour au premier plan et quand on tire la liste vers le bas.
@Observable
final class FolderSync {
    /// Nom du dossier choisi ; `nil` : la liste reste sur l'iPhone.
    private(set) var folderName: String?
    @ObservationIgnored private let store: TodoStore
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var timer: Timer?

    static func persistence(in folder: URL) -> Persistence {
        Persistence(url: folder.appendingPathComponent("todos.json"))
    }

    /// Dossier mémorisé, accès rouvert ; `nil` s'il n'y en a pas ou s'il n'est plus accessible.
    /// shortcut: l'accès n'est jamais refermé, l'app n'ouvrant qu'un dossier ; le refermer si on en gère plusieurs.
    static func savedFolder(defaults: UserDefaults = .standard) -> URL? {
        guard let bookmark = defaults.data(forKey: SettingsKey.iCloudFolderBookmark) else { return nil }
        var isStale = false
        guard let folder = try? URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &isStale),
              folder.startAccessingSecurityScopedResource() else { return nil }
        if isStale, let fresh = try? folder.bookmarkData() {
            defaults.set(fresh, forKey: SettingsKey.iCloudFolderBookmark)
        }
        return folder
    }

    /// `folder` : celui sur lequel le store a été ouvert (`savedFolder()`).
    init(store: TodoStore, folder: URL?, defaults: UserDefaults = .standard, checkInterval: TimeInterval = 5) {
        self.store = store
        self.defaults = defaults
        folderName = folder?.lastPathComponent
        timer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in self?.check() }
    }

    deinit {
        timer?.invalidate()
    }

    /// Dossier choisi dans Fichiers : la liste le rejoint (les deux listes réunies) et l'accès est mémorisé.
    /// `false` si le dossier n'est pas accessible ou si son fichier est illisible : rien ne change.
    @discardableResult
    func attach(_ folder: URL) -> Bool {
        guard folder.startAccessingSecurityScopedResource() else { return false }
        let persistence = Self.persistence(in: folder)
        guard let bookmark = try? folder.bookmarkData(), store.relocate(to: persistence, merging: true) else {
            folder.stopAccessingSecurityScopedResource()
            return false
        }
        defaults.set(bookmark, forKey: SettingsKey.iCloudFolderBookmark)
        folderName = folder.lastPathComponent
        return true
    }

    /// Fin de la synchronisation : la liste revient sur l'iPhone, telle qu'elle est.
    func detach() {
        guard store.relocate(to: Persistence(), merging: false) else { return }
        defaults.removeObject(forKey: SettingsKey.iCloudFolderBookmark)
        folderName = nil
    }

    /// Fusionne la liste si un autre appareil l'a changée. Fichier pas encore à jour sur l'iPhone : iCloud le télécharge
    /// et la fusion se fait au passage suivant, sans bloquer l'écran (`Persistence.currentData()`).
    func check() {
        if folderName != nil { store.reloadIfChangedOnDisk() }
    }
}

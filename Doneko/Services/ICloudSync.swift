import Foundation

/// Synchronisation iCloud : la liste vit dans iCloud Drive (`Doneko/todos.json`) au lieu de ce Mac, et ce qu'un autre
/// Mac y change est relu dès qu'iCloud le dépose (vérification toutes les 5 s).
/// shortcut: un seul fichier, le dernier qui écrit gagne : deux Mac modifiés dans les mêmes secondes peuvent perdre
/// une modification. Passer à CloudKit (compte Apple Developer payant) pour fusionner tâche par tâche.
final class ICloudSync: NSObject {
    static let driveURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
    static var isDriveAvailable: Bool { FileManager.default.fileExists(atPath: driveURL.path) }
    static let remote = Persistence(url: driveURL.appendingPathComponent("Doneko/todos.json"))

    /// Fichier à ouvrir au lancement, selon le réglage.
    static func persistence(defaults: UserDefaults = .standard) -> Persistence {
        defaults.bool(forKey: SettingsKey.iCloudSync) && isDriveAvailable ? remote : Persistence()
    }

    private let store: TodoStore
    private let defaults: UserDefaults
    private let local: Persistence
    private let remote: Persistence
    private let isDriveAvailable: Bool
    private var isOn: Bool
    private var timer: Timer?

    init(
        store: TodoStore,
        defaults: UserDefaults = .standard,
        local: Persistence = Persistence(),
        remote: Persistence = ICloudSync.remote,
        isDriveAvailable: Bool = ICloudSync.isDriveAvailable,
        checkInterval: TimeInterval = 5
    ) {
        self.store = store
        self.defaults = defaults
        self.local = local
        self.remote = remote
        self.isDriveAvailable = isDriveAvailable
        // Le store a été ouvert sur le bon fichier (`persistence(defaults:)`).
        isOn = defaults.bool(forKey: SettingsKey.iCloudSync) && isDriveAvailable
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(apply), name: UserDefaults.didChangeNotification, object: defaults)
        timer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in self?.check() }
    }

    deinit {
        timer?.invalidate()
    }

    /// Réglage activé : la liste rejoint iCloud Drive (les deux listes réunies). Coupé : elle revient sur ce Mac.
    @objc private func apply() {
        let wanted = defaults.bool(forKey: SettingsKey.iCloudSync) && isDriveAvailable
        guard wanted != isOn else { return }
        if store.relocate(to: wanted ? remote : local, merging: wanted) {
            isOn = wanted
        } else {
            // Écriture refusée : le réglage revient à son état réel.
            defaults.set(isOn, forKey: SettingsKey.iCloudSync)
        }
    }

    func check() {
        if isOn { store.reloadIfChangedOnDisk() }
    }
}

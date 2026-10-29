/// Clés des réglages (UserDefaults). Le raccourci est géré par KeyboardShortcuts.
enum SettingsKey {
    /// Heure (0 à 23) à laquelle « Tombé aujourd'hui » est vidé. 0 = minuit.
    static let purgeHour = "purgeHour"
    /// « Pop » feutré à la chute d'une tâche (désactivé par défaut).
    static let soundEnabled = "soundEnabled"
    /// Compteur de tâches à côté de l'icône (affiché par défaut).
    static let showCounter = "showCounter"
    /// iPhone : nombre de tâches du jour en pastille sur l'icône (affiché par défaut).
    static let showBadge = "showBadge"
    /// iPhone : « light » ou « dark » impose le mode clair ou sombre ; vide = celui du système.
    static let appearance = "appearance"
    /// Chemin du dossier Obsidian où exporter les tâches faites (vide = pas d'export).
    static let obsidianFolder = "obsidianFolder"
    /// Heure (0 à 23) du rappel des tâches datées, le jour venu (9 h par défaut). -1 = jamais.
    static let reminderHour = "reminderHour"
    /// Liste enregistrée dans iCloud Drive plutôt que sur ce Mac (désactivé par défaut).
    static let iCloudSync = "iCloudSync"
    /// Dossier choisi dans la barre (identifiant), mémorisé sur chaque appareil. Vide = « Tout ».
    static let selectedFolder = "selectedFolder"
    /// iPhone : signet du dossier `iCloud Drive › Doneko` choisi dans Fichiers (absent = liste sur l'iPhone).
    static let iCloudFolderBookmark = "iCloudFolderBookmark"
}

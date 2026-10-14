/// Clés des réglages (UserDefaults). Le raccourci est géré par KeyboardShortcuts.
enum SettingsKey {
    /// Heure (0 à 23) à laquelle « Tombé aujourd'hui » est vidé. 0 = minuit.
    static let purgeHour = "purgeHour"
    /// « Pop » feutré à la chute d'une tâche (désactivé par défaut).
    static let soundEnabled = "soundEnabled"
    /// Compteur de tâches à côté de l'icône (affiché par défaut).
    static let showCounter = "showCounter"
    /// Chemin du dossier Obsidian où exporter les tâches faites (vide = pas d'export).
    static let obsidianFolder = "obsidianFolder"
}

import KeyboardShortcuts
import SwiftUI

@main
struct DonekoApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        // L'icône et le panneau vivent dans MenuBarController (AppKit) ; SwiftUI exige une scène : elle reste invisible.
        MenuBarExtra("Doneko", isInserted: .constant(false)) { EmptyView() }
    }
}

/// Au lancement : store (sur ce Mac ou dans iCloud Drive), purge quotidienne, export Obsidian, rappels,
/// icône + panneau, raccourci ⌃⌥⌘D.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var dailyPurge: DailyPurge?
    private var obsidianExport: ObsidianExport?
    private var reminders: Reminders?
    private var iCloudSync: ICloudSync?
    private var menuBar: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Lancée pour héberger les tests : ne touche ni à la vraie liste, ni à Obsidian, ni à la barre de menu.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        UserDefaults.standard.register(defaults: [SettingsKey.showCounter: true, SettingsKey.reminderHour: 9])
        let store = TodoStore(persistence: ICloudSync.persistence())
        let menuBar = MenuBarController(store: store)
        dailyPurge = DailyPurge(store: store)
        obsidianExport = ObsidianExport(store: store)
        reminders = Reminders(store: store, onOpen: { menuBar.show() })
        iCloudSync = ICloudSync(store: store)
        self.menuBar = menuBar
        KeyboardShortcuts.onKeyUp(for: .openPanel) { menuBar.show() }
    }
}

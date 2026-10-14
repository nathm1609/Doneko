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

/// Au lancement : store, purge quotidienne, icône + panneau, raccourci ⌃⌥⌘D.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var dailyPurge: DailyPurge?
    private var obsidianExport: ObsidianExport?
    private var menuBar: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [SettingsKey.showCounter: true])
        let store = TodoStore(persistence: Persistence())
        let menuBar = MenuBarController(store: store)
        dailyPurge = DailyPurge(store: store)
        obsidianExport = ObsidianExport(store: store)
        self.menuBar = menuBar
        KeyboardShortcuts.onKeyUp(for: .openPanel) { menuBar.show() }
    }
}

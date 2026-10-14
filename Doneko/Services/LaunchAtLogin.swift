import Foundation
import ServiceManagement

/// Option « Lancer au démarrage ».
enum LaunchAtLogin {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func set(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Doneko : lancement au démarrage impossible (\(error))")
        }
    }
}

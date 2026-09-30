import Observation
import ServiceManagement

/// `SMAppService.mainApp` is the source of truth; nothing is stored in UserDefaults.
@MainActor
@Observable
final class LaunchAtLogin {
    private(set) var isEnabled = SMAppService.mainApp.status == .enabled
    private(set) var errorMessage: String?

    func set(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        // On failure this reverts the toggle.
        isEnabled = SMAppService.mainApp.status == .enabled
    }
}

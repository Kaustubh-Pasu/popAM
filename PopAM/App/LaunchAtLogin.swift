import Observation
import ServiceManagement

/// `SMAppService.mainApp` is the source of truth; nothing is stored in UserDefaults.
@MainActor
@Observable
final class LaunchAtLogin {
    private(set) var isEnabled = false
    /// Registered, but the user still has to allow it in System Settings → Login Items.
    private(set) var needsApproval = false
    private(set) var errorMessage: String?

    init() { refresh() }

    /// Re-reads the system state; the user can change Login Items in System Settings at any time.
    func refresh() {
        let status = SMAppService.mainApp.status
        isEnabled = status == .enabled
        needsApproval = status == .requiresApproval
    }

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
        refresh()
    }
}

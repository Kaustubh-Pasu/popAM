import AppKit
import PopAMCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = SettingsStore()
    private lazy var store = MetricsStore(settings: settings, readers: .live())
    private lazy var settingsWindow = SettingsWindowController(settings: settings,
                                                               batteryPresent: store.batteryPresent)
    private var statusItem: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = StatusItemController(store: store, settings: settings) { [weak self] in
            self?.settingsWindow.show()
        }
        store.start()
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.store.handleWake() }
        }
    }
}

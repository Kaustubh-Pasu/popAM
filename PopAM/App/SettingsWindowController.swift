import AppKit
import PopAMCore
import SwiftUI

@MainActor
final class SettingsWindowController {
    private let settings: SettingsStore
    private let batteryPresent: Bool
    private var window: NSWindow?

    init(settings: SettingsStore, batteryPresent: Bool) {
        self.settings = settings
        self.batteryPresent = batteryPresent
    }

    func show() {
        if window == nil {
            let view = SettingsView(settings: settings, batteryPresent: batteryPresent)
            let window = NSWindow(contentViewController: NSHostingController(rootView: view))
            window.title = "popAM Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}

import AppKit
import PopAMCore
import SwiftUI

@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let store: MetricsStore
    private let settings: SettingsStore
    private let openSettings: () -> Void
    /// The transient popover closes on mouse-down; our action fires on mouse-up. Remember when it
    /// closed so the click that closed it doesn't immediately reopen it.
    private var lastClose = Date.distantPast

    init(store: MetricsStore, settings: SettingsStore, openSettings: @escaping () -> Void) {
        self.store = store
        self.settings = settings
        self.openSettings = openSettings
        super.init()

        let content = PopoverView(store: store, settings: settings) { [weak self] in
            self?.popover.performClose(nil)
            openSettings()
        }
        let hosting = NSHostingController(rootView: content)
        hosting.sizingOptions = .preferredContentSize
        popover.contentViewController = hosting
        popover.behavior = .transient
        popover.delegate = self

        if let button = item.button {
            let image = NSImage(systemSymbolName: "gauge.with.dots.needle.33percent",
                                accessibilityDescription: "popAM")
            image?.isTemplate = true
            button.image = image
            button.imagePosition = .imageLeading
            // Monospaced digits keep the item from changing width as numbers change.
            button.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            button.target = self
            button.action = #selector(clicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        observeTitle()
    }

    // MARK: Title

    /// Re-renders the title whenever the settings or snapshots it reads change.
    private func observeTitle() {
        withObservationTracking {
            updateTitle()
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeTitle() }
        }
    }

    private func updateTitle() {
        let text = settings.menuBarMode == .iconAndText
            ? MenuBarText.make(settings.menuBarValues, from: store.snapshots)
            : ""
        item.button?.title = text.isEmpty ? "" : " " + text
    }

    // MARK: Clicks

    @objc private func clicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showMenu()
        } else {
            togglePopover(sender)
        }
    }

    private func togglePopover(_ button: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        guard Date().timeIntervalSince(lastClose) > 0.25 else { return }
        store.popoverVisible = true
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        // Without activation, a transient popover in an LSUIElement app won't close on outside clicks.
        NSApp.activate()
        popover.contentViewController?.view.window?.makeKey()
    }

    func popoverDidClose(_ notification: Notification) {
        store.popoverVisible = false
        lastClose = Date()
    }

    private func showMenu() {
        let menu = NSMenu()
        let settingsItem = menu.addItem(withTitle: "Settings…", action: #selector(settingsTapped),
                                        keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit popAM", action: #selector(NSApplication.terminate(_:)),
                     keyEquivalent: "q")
        // Attach temporarily so the left click keeps opening the popover.
        item.menu = menu
        item.button?.performClick(nil)
        item.menu = nil
    }

    @objc private func settingsTapped() {
        openSettings()
    }
}

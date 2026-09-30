import PopAMCore
import SwiftUI

struct MenuBarTab: View {
    @Bindable var settings: SettingsStore
    let batteryPresent: Bool

    private var choices: [MenuBarValue] {
        MenuBarValue.allCases.filter { $0 != .batteryPercent || batteryPresent }
    }

    var body: some View {
        Form {
            Picker("Show", selection: $settings.menuBarMode) {
                Text("Icon only").tag(MenuBarMode.iconOnly)
                Text("Icon + text").tag(MenuBarMode.iconAndText)
            }
            .pickerStyle(.radioGroup)
            if settings.menuBarMode == .iconAndText {
                Picker("First value", selection: first) {
                    ForEach(choices, id: \.self) { Text($0.label).tag($0) }
                }
                Picker("Second value", selection: second) {
                    Text("None").tag(MenuBarValue?.none)
                    ForEach(choices, id: \.self) { Text($0.label).tag(Optional($0)) }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var first: Binding<MenuBarValue> {
        Binding(
            get: { settings.menuBarValues.first ?? .cpuPercent },
            set: { value in
                let rest = settings.menuBarValues.dropFirst().filter { $0 != value }
                settings.setMenuBarValues([value] + rest)
            })
    }

    /// Choosing the same value as the first one clears the second.
    private var second: Binding<MenuBarValue?> {
        Binding(
            get: { settings.menuBarValues.dropFirst().first },
            set: { value in
                let first = settings.menuBarValues.first ?? .cpuPercent
                settings.setMenuBarValues([first] + (value.map { [$0] } ?? []))
            })
    }
}

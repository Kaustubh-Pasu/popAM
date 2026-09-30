import AppKit
import PopAMCore
import SwiftUI

struct GeneralTab: View {
    @Bindable var settings: SettingsStore
    @State private var launchAtLogin = LaunchAtLogin()

    var body: some View {
        Form {
            Toggle("Launch at login", isOn: Binding(
                get: { launchAtLogin.isEnabled },
                set: { launchAtLogin.set($0) }))
            if let error = launchAtLogin.errorMessage {
                Text(error).font(.caption).foregroundStyle(.red)
            }
            if launchAtLogin.needsApproval {
                Text("Allow popAM in System Settings → General → Login Items.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Picker("Refresh every", selection: $settings.refreshInterval) {
                ForEach(SettingsStore.allowedIntervals, id: \.self) { seconds in
                    Text("\(Int(seconds)) s").tag(seconds)
                }
            }
            .pickerStyle(.segmented)
        }
        .formStyle(.grouped)
        .onAppear { launchAtLogin.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            launchAtLogin.refresh()
        }
    }
}

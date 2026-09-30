import PopAMCore
import SwiftUI

struct SettingsView: View {
    let settings: SettingsStore
    let batteryPresent: Bool

    var body: some View {
        TabView {
            GeneralTab(settings: settings)
                .tabItem { Label("General", systemImage: "gearshape") }
            MenuBarTab(settings: settings, batteryPresent: batteryPresent)
                .tabItem { Label("Menu Bar", systemImage: "menubar.rectangle") }
            PopupTab(settings: settings, batteryPresent: batteryPresent)
                .tabItem { Label("Popup", systemImage: "rectangle.stack") }
        }
        .frame(width: 420, height: 320)
    }
}

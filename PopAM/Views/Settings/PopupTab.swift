import PopAMCore
import SwiftUI

struct PopupTab: View {
    let settings: SettingsStore
    let batteryPresent: Bool

    private var shown: [MetricKind] {
        settings.cardOrder.filter { $0 != .battery || batteryPresent }
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("Drag to reorder. Turn off cards you don't need.")
                .font(.caption)
                .foregroundStyle(.secondary)
            List {
                ForEach(shown, id: \.self) { kind in
                    Toggle(kind.title, isOn: Binding(
                        get: { settings.enabledCards.contains(kind) },
                        set: { settings.setCardEnabled(kind, $0) }))
                }
                .onMove { source, destination in
                    settings.moveCards(shown: shown, fromOffsets: source, toOffset: destination)
                }
            }
        }
        .padding()
    }
}

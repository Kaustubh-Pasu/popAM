import PopAMCore
import SwiftUI

struct PopoverView: View {
    let store: MetricsStore
    let settings: SettingsStore
    let openSettings: () -> Void

    private var cards: [MetricKind] {
        settings.visibleCards.filter { $0 != .battery || store.batteryPresent }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("popAM").font(.headline)
                Spacer()
                Button(action: openSettings) {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.borderless)
                .help("Settings")
            }
            .padding(12)
            Divider()
            if cards.isEmpty {
                Text("No metrics enabled — open Settings.")
                    .foregroundStyle(.secondary)
                    .padding(16)
            } else {
                ForEach(cards, id: \.self) { kind in
                    card(for: kind).padding(12)
                    if kind != cards.last { Divider() }
                }
            }
        }
        .frame(width: 320)
    }

    @ViewBuilder
    private func card(for kind: MetricKind) -> some View {
        switch kind {
        case .cpu: CPUCard(reading: store.snapshots.cpu, history: store.history.cpu)
        case .memory: MemoryCard(reading: store.snapshots.memory, history: store.history.memory)
        case .network: NetworkCard(reading: store.snapshots.network,
                                   down: store.history.netDown, up: store.history.netUp)
        case .disk: DiskCard(reading: store.snapshots.disk)
        case .battery: BatteryCard(reading: store.snapshots.battery)
        }
    }
}

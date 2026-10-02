import PopAMCore
import SwiftUI

/// Terminal-on-glass popover. No backgrounds: the NSPopover material shows through.
struct PopoverView: View {
    let store: MetricsStore
    let settings: SettingsStore
    let openSettings: () -> Void

    private var sections: [MetricKind] {
        settings.visibleCards.filter { $0 != .battery || store.batteryPresent }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HeaderSection(system: store.snapshots.system, openSettings: openSettings)
            Hairline()
            if sections.isEmpty {
                TermLine("no metrics enabled", "open settings")
            } else {
                ForEach(sections, id: \.self) { kind in
                    section(for: kind)
                    if kind != sections.last { Hairline() }
                }
            }
            Text(">_ \(StatusLine.make(store.snapshots))")
                .font(Term.mono(11)).foregroundStyle(Term.dim).padding(.top, 2)
        }
        .padding(16)
        .frame(width: 380, alignment: .leading)
    }

    @ViewBuilder
    private func section(for kind: MetricKind) -> some View {
        switch kind {
        case .cpu: CPUSection(reading: store.snapshots.cpu, history: store.history.cpu,
                              peak: store.history.cpuPeak)
        case .memory: MemorySection(reading: store.snapshots.memory)
        case .network: NetworkSection(reading: store.snapshots.network,
                                      down: store.history.netDown, up: store.history.netUp)
        case .disk: DiskSection(reading: store.snapshots.disk)
        case .battery: BatterySection(reading: store.snapshots.battery)
        case .power: PowerSection(reading: store.snapshots.power,
                                  unit: settings.temperatureUnit)
        }
    }
}

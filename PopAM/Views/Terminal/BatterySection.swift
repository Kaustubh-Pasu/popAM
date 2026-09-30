import PopAMCore
import SwiftUI

struct BatterySection: View {
    let reading: Reading<BatterySnapshot>

    var body: some View {
        let battery = reading.current
        VStack(alignment: .leading, spacing: 10) {
            GaugeRow(label: "BAT", fraction: battery.map { Double($0.percent) / 100 },
                     value: battery.map { "\($0.percent)%" + ($0.state == .charging ? " chg" : "") } ?? dash)
            if let battery {
                TermLine(key(battery.state), details(battery))
            } else {
                TermLine("status", dash)
            }
        }
    }

    private func key(_ state: PowerState) -> String {
        switch state {
        case .charging: "full in"
        case .discharging: "left"
        case .charged: "charged"
        case .acNotCharging: "not charging"
        }
    }

    /// `0:42  hp 94%  cyc 212`; the time only while charging or discharging.
    private func details(_ battery: BatterySnapshot) -> String {
        var parts: [String] = []
        if battery.state == .charging || battery.state == .discharging {
            parts.append(battery.minutesRemaining.map { Formatters.duration(minutes: $0) } ?? "calc")
        }
        parts.append("hp \(battery.healthPercent.map { "\($0)%" } ?? dash)")
        parts.append("cyc \(battery.cycleCount.map(String.init) ?? dash)")
        return parts.joined(separator: "  ")
    }
}

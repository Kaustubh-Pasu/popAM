import PopAMCore
import SwiftUI

struct BatteryCard: View {
    let reading: Reading<BatterySnapshot>

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CardHeader(title: "Battery", value: reading.current.map {
                "\($0.percent)% · \(stateLabel($0.state))"
            } ?? dash)
            if let battery = reading.current {
                DetailText([timeLabel(battery), battery.cycleCount.map { "\($0) cycles" }]
                    .compactMap { $0 }
                    .joined(separator: " · "))
            }
        }
    }

    private func stateLabel(_ state: PowerState) -> String {
        switch state {
        case .charging: "Charging"
        case .discharging: "On battery"
        case .charged: "Fully charged"
        case .acNotCharging: "Plugged in, not charging"
        }
    }

    private func timeLabel(_ battery: BatterySnapshot) -> String? {
        switch battery.state {
        case .charging:
            battery.minutesRemaining.map { "Full in \(Formatters.duration(minutes: $0))" } ?? "Calculating…"
        case .discharging:
            battery.minutesRemaining.map { "\(Formatters.duration(minutes: $0)) remaining" } ?? "Calculating…"
        case .charged, .acNotCharging:
            nil
        }
    }
}

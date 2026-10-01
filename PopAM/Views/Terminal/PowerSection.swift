import PopAMCore
import SwiftUI

struct PowerSection: View {
    let reading: Reading<PowerSnapshot>

    var body: some View {
        let power = reading.current
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("PWR").font(Term.mono(12, .bold))
                Spacer()
                Text(power.map(PowerFlowText.header) ?? dash).font(Term.mono(12, .semibold))
            }
            .foregroundStyle(Term.ink)
            if let power {
                // One Text per line keeps the box-drawing columns aligned in the monospaced font.
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(Array(PowerFlowText.lines(power).enumerated()), id: \.offset) { _, line in
                        Text(line).lineLimit(1).fixedSize()
                    }
                }
                .font(Term.mono(10.5))
                .foregroundStyle(Term.ink.opacity(0.85))
                let charger = PowerFlowText.charger(power)
                let temperature = PowerFlowText.temperature(power)
                if charger != nil || temperature != nil {
                    TermLine(charger ?? "", temperature ?? "")
                }
            } else {
                TermLine("status", dash)
            }
        }
    }
}

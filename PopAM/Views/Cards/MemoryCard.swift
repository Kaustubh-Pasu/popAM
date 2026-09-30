import PopAMCore
import SwiftUI

struct MemoryCard: View {
    let reading: Reading<MemorySnapshot>
    let history: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CardHeader(title: "Memory", value: reading.current.map {
                "\(Formatters.memory($0.usedBytes)) / \(Formatters.memory($0.totalBytes))"
            } ?? dash)
            Sparkline(series: [history], maxY: 1)
            if let memory = reading.current {
                HStack(spacing: 4) {
                    Circle().fill(color(memory.pressure)).frame(width: 7, height: 7)
                    DetailText("Pressure \(label(memory.pressure))")
                }
                DetailText("Swap \(Formatters.memory(memory.swapUsedBytes))")
            }
        }
    }

    private func label(_ pressure: MemoryPressure) -> String {
        switch pressure {
        case .normal: "Normal"
        case .warning: "Warning"
        case .critical: "Critical"
        }
    }

    private func color(_ pressure: MemoryPressure) -> Color {
        switch pressure {
        case .normal: .green
        case .warning: .yellow
        case .critical: .red
        }
    }
}

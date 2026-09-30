import PopAMCore
import SwiftUI

struct CPUCard: View {
    let reading: Reading<CPUSnapshot>
    let history: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CardHeader(title: "CPU", value: reading.current.map { Formatters.percent($0.total) } ?? dash)
            Sparkline(series: [history], maxY: 1)
            if let cpu = reading.current {
                CoreBars(cores: cpu.cores)
                DetailText("User \(Formatters.percent(cpu.user)) · System \(Formatters.percent(cpu.system))")
            }
        }
    }
}

private struct CoreBars: View {
    let cores: [CoreLoad]

    var body: some View {
        let performance = cores.filter { $0.kind == .performance }
        let efficiency = cores.filter { $0.kind == .efficiency }
        HStack(spacing: 10) {
            if performance.isEmpty && efficiency.isEmpty {
                group(label: nil, cores)
            } else {
                group(label: "P", performance)
                group(label: "E", efficiency)
            }
        }
    }

    private func group(label: String?, _ cores: [CoreLoad]) -> some View {
        HStack(alignment: .bottom, spacing: 2) {
            if let label { Text(label).font(.caption2).foregroundStyle(.secondary) }
            ForEach(cores, id: \.index) { core in
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 1).fill(.quaternary)
                    RoundedRectangle(cornerRadius: 1).fill(Color.accentColor)
                        .frame(height: 20 * core.load)
                }
                .frame(width: 5, height: 20)
                .help("Core \(core.index + 1): \(Formatters.percent(core.load))")
            }
        }
    }
}

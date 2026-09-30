import PopAMCore
import SwiftUI

struct CPUSection: View {
    let reading: Reading<CPUSnapshot>
    let history: [Double]
    let peak: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GaugeRow(label: "CPU", fraction: reading.current?.total,
                     value: reading.current.map { Formatters.percent($0.total) } ?? dash)
            StepGraph(series: [history], maxY: 1)
            HStack(spacing: 2) {
                CoreStrip(cores: reading.current?.cores ?? [])
                Spacer()
                Text("pk \(peak.map(Formatters.percent) ?? dash)").foregroundStyle(Term.ink)
            }
            .font(Term.mono(11))
            TermLine("usr/sys", reading.current.map {
                "\(Formatters.percent($0.user)) / \(Formatters.percent($0.system))"
            } ?? dash)
        }
    }
}

/// `E▁▁▂  P▅▃▆▂` — one level glyph per core, efficiency cores first.
private struct CoreStrip: View {
    let cores: [CoreLoad]

    var body: some View {
        let efficiency = cores.filter { $0.kind == .efficiency }.map(\.load)
        let performance = cores.filter { $0.kind == .performance }.map(\.load)
        if efficiency.isEmpty && performance.isEmpty {
            Text(TextGauge.levels(cores.map(\.load))).foregroundStyle(Term.ink)
        } else {
            if !efficiency.isEmpty {
                Text("E").foregroundStyle(Term.dim)
                Text(TextGauge.levels(efficiency)).foregroundStyle(Term.ink)
            }
            if !performance.isEmpty {
                Text(efficiency.isEmpty ? "P" : "  P").foregroundStyle(Term.dim)
                Text(TextGauge.levels(performance)).foregroundStyle(Term.ink)
            }
        }
    }
}

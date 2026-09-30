import PopAMCore
import SwiftUI

struct MemorySection: View {
    let reading: Reading<MemorySnapshot>

    var body: some View {
        let memory = reading.current
        VStack(alignment: .leading, spacing: 10) {
            GaugeRow(label: "MEM", fraction: memory?.usedFraction, value: memory.map {
                "\(Formatters.gigabytes($0.usedBytes))/\(Formatters.wholeGigabytes($0.totalBytes, base: 1024))G"
            } ?? dash)
            TermLine("app/wir/cmp", memory.map {
                [$0.appBytes, $0.wiredBytes, $0.compressedBytes].map(Formatters.gigabytes).joined(separator: " ") + " G"
            } ?? dash)
            TermLine("pressure", memory.map { label($0.pressure) } ?? dash)
            TermLine("swap", memory.map { "\(Formatters.gigabytes($0.swapUsedBytes)) G" } ?? dash)
        }
    }

    private func label(_ pressure: MemoryPressure) -> String {
        switch pressure {
        case .normal: "nominal"
        case .warning: "warning"
        case .critical: "critical"
        }
    }
}

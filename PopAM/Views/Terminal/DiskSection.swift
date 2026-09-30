import PopAMCore
import SwiftUI

struct DiskSection: View {
    let reading: Reading<DiskSnapshot>

    var body: some View {
        let disk = reading.current
        VStack(alignment: .leading, spacing: 10) {
            GaugeRow(label: "DSK", fraction: disk.map(usedFraction),
                     value: disk.map { "\(Formatters.wholeGigabytes($0.freeBytes, base: 1000))G free" } ?? dash)
            TermLine("r/w", disk.map {
                "\($0.readBytesPerSec.map(Formatters.rate) ?? dash) / \($0.writeBytesPerSec.map(Formatters.rate) ?? dash)"
            } ?? dash)
        }
    }

    private func usedFraction(_ disk: DiskSnapshot) -> Double {
        disk.totalBytes == 0 ? 0 : 1 - Double(disk.freeBytes) / Double(disk.totalBytes)
    }
}

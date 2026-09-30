import PopAMCore
import SwiftUI

struct DiskCard: View {
    let reading: Reading<DiskSnapshot>

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CardHeader(title: "Disk", value: reading.current.map {
                "\(Formatters.file($0.freeBytes)) free of \(Formatters.file($0.totalBytes))"
            } ?? dash)
            if let disk = reading.current {
                let read = disk.readBytesPerSec.map(Formatters.rate) ?? dash
                let write = disk.writeBytesPerSec.map(Formatters.rate) ?? dash
                DetailText("Read \(read) · Write \(write)")
            }
        }
    }
}

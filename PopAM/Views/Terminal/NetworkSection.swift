import PopAMCore
import SwiftUI

struct NetworkSection: View {
    let reading: Reading<NetworkSnapshot>
    let down: [Double]
    let up: [Double]

    var body: some View {
        let net = reading.current
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("NET").font(Term.mono(12, .bold)).foregroundStyle(Term.ink)
                Spacer()
                Text("↓ \(net.map { Formatters.rate($0.downBytesPerSec) } ?? dash)").foregroundStyle(Term.ink)
                Text("↑ \(net.map { Formatters.rate($0.upBytesPerSec) } ?? dash)").foregroundStyle(Term.dim)
            }
            .font(Term.mono(12))
            StepGraph(series: [down, up], maxY: nil)
            TermLine("since boot", net.map {
                "↓\(Formatters.file($0.totalReceivedBytes)) ↑\(Formatters.file($0.totalSentBytes))"
            } ?? dash)
        }
    }
}

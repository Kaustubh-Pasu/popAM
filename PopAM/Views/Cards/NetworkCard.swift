import PopAMCore
import SwiftUI

struct NetworkCard: View {
    let reading: Reading<NetworkSnapshot>
    let down: [Double]
    let up: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CardHeader(title: "Network", value: reading.current.map {
                "↓ \(Formatters.rate($0.downBytesPerSec))  ↑ \(Formatters.rate($0.upBytesPerSec))"
            } ?? dash)
            Sparkline(series: [down, up], maxY: nil)
        }
    }
}

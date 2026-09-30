import PopAMCore
import SwiftUI

/// `popAM▍  [up 3d 4h]`, the settings gear, and the load average.
struct HeaderSection: View {
    let system: Reading<SystemSnapshot>
    let openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("popAM").font(Term.mono(15, .bold)).foregroundStyle(Term.ink)
                Text("▍").font(Term.mono(12)).foregroundStyle(Term.dim)
                Spacer()
                Text("[up \(system.current?.uptimeSeconds.map { Formatters.uptime(seconds: $0) } ?? dash)]")
                    .font(Term.mono(10.5)).foregroundStyle(Term.dim)
                Button(action: openSettings) {
                    Image(systemName: "gearshape").font(.system(size: 11))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(Term.dim)
                .help("Settings")
            }
            TermLine("load avg", system.current?.loadAverage.map(Formatters.loadAverage) ?? dash)
        }
    }
}

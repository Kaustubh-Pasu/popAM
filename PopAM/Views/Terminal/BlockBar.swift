import PopAMCore
import SwiftUI

/// `████░░░░` bar, 18 cells.
struct BlockBar: View {
    let fraction: Double

    var body: some View {
        Text(TextGauge.bar(fraction)).font(Term.mono(12))
    }
}

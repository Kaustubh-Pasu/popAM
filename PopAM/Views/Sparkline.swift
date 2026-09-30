import Charts
import PopAMCore
import SwiftUI

/// Axis-free line graph of the last `History.capacity` samples, right-aligned so new values enter at the right.
struct Sparkline: View {
    /// One or two series; the second is drawn in orange.
    let series: [[Double]]
    /// Fixed top of the Y axis, or nil to auto-scale to the largest value.
    let maxY: Double?

    private var top: Double {
        maxY ?? max(1, series.flatMap { $0 }.max() ?? 1)
    }

    var body: some View {
        Chart {
            ForEach(series.indices, id: \.self) { s in
                let values = series[s]
                let offset = History.capacity - values.count
                ForEach(values.indices, id: \.self) { i in
                    LineMark(x: .value("Sample", i + offset), y: .value("Value", values[i]),
                             series: .value("Series", s))
                        .foregroundStyle(s == 0 ? Color.accentColor : Color.orange)
                        .interpolationMethod(.monotone)
                }
            }
        }
        .chartXScale(domain: 0...(History.capacity - 1))
        .chartYScale(domain: 0...top)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: 32)
    }
}

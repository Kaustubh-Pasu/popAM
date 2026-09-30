import Charts
import PopAMCore
import SwiftUI

/// Step-line graph of the last `History.capacity` samples over a dashed grid. New values enter at the right.
struct StepGraph: View {
    /// First series solid ink; a second one is dimmed and dashed.
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
                        .foregroundStyle(s == 0 ? Term.ink : Term.dim)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: s == 0 ? [] : [3, 2]))
                        .interpolationMethod(.stepCenter)
                }
            }
        }
        .chartXScale(domain: 0...(History.capacity - 1))
        .chartYScale(domain: 0...top)
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3])).foregroundStyle(Term.faint)
            }
        }
        .frame(height: 38)
    }
}

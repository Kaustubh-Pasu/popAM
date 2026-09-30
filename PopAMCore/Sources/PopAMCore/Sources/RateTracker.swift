/// Turns cumulative counters into per-second rates. Returns nil on the first sample,
/// when any counter decreased, or when time didn't advance — and re-baselines.
struct RateTracker {
    private var last: (time: Double, counters: [UInt64])?

    mutating func reset() { last = nil }

    mutating func rates(_ counters: [UInt64], at time: Double) -> [Double]? {
        defer { last = (time, counters) }
        guard let last, last.counters.count == counters.count, time > last.time,
              zip(counters, last.counters).allSatisfy({ $0 >= $1 }) else { return nil }
        let elapsed = time - last.time
        return zip(counters, last.counters).map { Double($0 - $1) / elapsed }
    }
}

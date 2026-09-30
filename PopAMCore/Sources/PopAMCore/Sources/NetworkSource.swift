public struct NetworkSource {
    private let reader: any NetworkReading
    private var tracker = RateTracker()

    public init(reader: any NetworkReading) { self.reader = reader }

    public mutating func reset() { tracker.reset() }

    /// `time` is seconds on any monotonic clock.
    public mutating func sample(at time: Double) -> Reading<NetworkSnapshot> {
        guard let totals = reader.totals(),
              let rates = tracker.rates([totals.receivedBytes, totals.sentBytes], at: time)
        else { return .unavailable }
        return .value(NetworkSnapshot(downBytesPerSec: rates[0], upBytesPerSec: rates[1]))
    }
}

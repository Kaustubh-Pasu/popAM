public struct NetworkSource {
    private let reader: any NetworkReading
    private var last: (time: Double, totals: [String: NetworkTotals])?

    public init(reader: any NetworkReading) { self.reader = reader }

    public mutating func reset() { last = nil }

    /// `time` is seconds on any monotonic clock.
    ///
    /// Rates are summed per interface over those present in both samples, so an interface
    /// (re)appearing never contributes its whole since-boot counter as a one-sample spike.
    public mutating func sample(at time: Double) -> Reading<NetworkSnapshot> {
        guard let totals = reader.interfaceTotals() else {
            last = nil
            return .unavailable
        }
        defer { last = (time, totals) }
        guard let last, time > last.time else { return .unavailable }
        var down: UInt64 = 0
        var up: UInt64 = 0
        var contributing = 0
        for (name, now) in totals {
            guard let before = last.totals[name],
                  now.receivedBytes >= before.receivedBytes, now.sentBytes >= before.sentBytes
            else { continue }
            down += now.receivedBytes - before.receivedBytes
            up += now.sentBytes - before.sentBytes
            contributing += 1
        }
        guard contributing > 0 else { return .unavailable }
        let elapsed = time - last.time
        return .value(NetworkSnapshot(downBytesPerSec: Double(down) / elapsed,
                                      upBytesPerSec: Double(up) / elapsed))
    }
}

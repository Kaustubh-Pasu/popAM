public struct DiskSource {
    private let space: any DiskSpaceReading
    private let io: any DiskIOReading
    private var tracker = RateTracker()

    public init(space: any DiskSpaceReading, io: any DiskIOReading) {
        self.space = space
        self.io = io
    }

    public mutating func reset() { tracker.reset() }

    public mutating func sample(at time: Double) -> Reading<DiskSnapshot> {
        let rates = io.totals().flatMap { tracker.rates([$0.readBytes, $0.writtenBytes], at: time) }
        guard let space = space.space() else { return .unavailable }
        return .value(DiskSnapshot(freeBytes: space.free, totalBytes: space.total,
                                   readBytesPerSec: rates?[0], writeBytesPerSec: rates?[1]))
    }
}

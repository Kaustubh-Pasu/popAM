import Testing
@testable import PopAMCore

struct FakeDiskSpaceReader: DiskSpaceReading {
    var value: DiskSpace? = DiskSpace(free: 200, total: 500)
    func space() -> DiskSpace? { value }
}

struct FakeDiskIOReader: DiskIOReading {
    let script: Script<DiskIOTotals?>
    init(_ values: [DiskIOTotals?]) { script = Script(values) }
    func totals() -> DiskIOTotals? { script.next() }
}

struct DiskSourceTests {
    private func io(_ r: UInt64, _ w: UInt64) -> DiskIOTotals { DiskIOTotals(readBytes: r, writtenBytes: w) }

    @Test func spaceAvailableOnFirstSampleRatesNot() throws {
        var source = DiskSource(space: FakeDiskSpaceReader(), io: FakeDiskIOReader([io(0, 0)]))
        let snap = try #require(source.sample(at: 0).current)
        #expect(snap.freeBytes == 200)
        #expect(snap.totalBytes == 500)
        #expect(snap.readBytesPerSec == nil)
        #expect(snap.writeBytesPerSec == nil)
    }

    @Test func computesIORates() throws {
        var source = DiskSource(space: FakeDiskSpaceReader(),
                                io: FakeDiskIOReader([io(0, 0), io(10_000, 4_000)]))
        _ = source.sample(at: 0)
        let snap = try #require(source.sample(at: 2).current)
        #expect(snap.readBytesPerSec == 5_000)
        #expect(snap.writeBytesPerSec == 2_000)
    }

    @Test func noIODriversStillShowsSpace() throws {
        var source = DiskSource(space: FakeDiskSpaceReader(), io: FakeDiskIOReader([nil]))
        _ = source.sample(at: 0)
        let snap = try #require(source.sample(at: 2).current)
        #expect(snap.readBytesPerSec == nil)
        #expect(snap.freeBytes == 200)
    }

    @Test func counterDecreaseResetsRates() {
        var source = DiskSource(space: FakeDiskSpaceReader(),
                                io: FakeDiskIOReader([io(100, 100), io(1, 1)]))
        _ = source.sample(at: 0)
        #expect(source.sample(at: 2).current?.readBytesPerSec == nil)
    }

    @Test func spaceFailureIsUnavailable() {
        var source = DiskSource(space: FakeDiskSpaceReader(value: nil), io: FakeDiskIOReader([io(0, 0)]))
        #expect(source.sample(at: 0) == .unavailable)
    }
}

/// Runs against the real OS: checks sane ranges, not exact numbers.
struct LiveDiskReaderTests {
    @Test func disk() throws {
        let space = try #require(LiveDiskSpaceReader().space())
        #expect(space.total > 0)
        #expect(space.free <= space.total)
        let io = try #require(LiveDiskIOReader().totals())
        #expect(io.readBytes > 0)
    }
}

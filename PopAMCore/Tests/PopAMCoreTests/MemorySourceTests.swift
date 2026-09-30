import Testing
@testable import PopAMCore

struct FakeMemoryReader: MemoryReading {
    var stats: VMStats? = VMStats(internalPages: 0, purgeablePages: 0, wiredPages: 0,
                                  compressedPages: 0, pageSize: 16384)
    var total: UInt64? = 16 * 1024 * 1024 * 1024
    var level: Int32? = 1
    var swapUsage: SwapUsage? = SwapUsage(used: 0, total: 0)
    func vmStats() -> VMStats? { stats }
    func totalBytes() -> UInt64? { total }
    func pressureLevel() -> Int32? { level }
    func swap() -> SwapUsage? { swapUsage }
}

struct MemorySourceTests {
    @Test func usedMatchesActivityMonitorFormula() throws {
        var reader = FakeMemoryReader()
        // app = 1000 - 200 = 800; + wired 300 + compressed 100 = 1200 pages
        reader.stats = VMStats(internalPages: 1000, purgeablePages: 200, wiredPages: 300,
                               compressedPages: 100, pageSize: 16384)
        reader.swapUsage = SwapUsage(used: 5, total: 10)
        let snap = try #require(MemorySource(reader: reader).sample().current)
        #expect(snap.usedBytes == 1200 * 16384)
        #expect(snap.totalBytes == 16 * 1024 * 1024 * 1024)
        #expect(snap.swapUsedBytes == 5)
        #expect(snap.swapTotalBytes == 10)
    }

    @Test func exposesAppWiredCompressedBreakdown() throws {
        var reader = FakeMemoryReader()
        reader.stats = VMStats(internalPages: 1000, purgeablePages: 200, wiredPages: 300,
                               compressedPages: 100, pageSize: 16384)
        let snap = try #require(MemorySource(reader: reader).sample().current)
        #expect(snap.appBytes == 800 * 16384)
        #expect(snap.wiredBytes == 300 * 16384)
        #expect(snap.compressedBytes == 100 * 16384)
    }

    @Test func purgeableLargerThanInternalDoesNotUnderflow() throws {
        var reader = FakeMemoryReader()
        reader.stats = VMStats(internalPages: 10, purgeablePages: 50, wiredPages: 1,
                               compressedPages: 0, pageSize: 4096)
        let snap = try #require(MemorySource(reader: reader).sample().current)
        #expect(snap.usedBytes == 4096)
    }

    @Test func usedNeverExceedsTotal() throws {
        var reader = FakeMemoryReader()
        reader.total = 1000
        reader.stats = VMStats(internalPages: 10, purgeablePages: 0, wiredPages: 0,
                               compressedPages: 0, pageSize: 4096)
        let snap = try #require(MemorySource(reader: reader).sample().current)
        #expect(snap.usedBytes == 1000)
        #expect(snap.usedFraction == 1)
    }

    @Test(arguments: [(Int32?(1), MemoryPressure.normal), (2, .warning), (4, .critical),
                      (3, .normal), (nil, .normal)])
    func pressureMapping(level: Int32?, expected: MemoryPressure) {
        #expect(MemorySource.pressure(level) == expected)
    }

    @Test func missingVMStatsIsUnavailable() {
        var reader = FakeMemoryReader()
        reader.stats = nil
        #expect(MemorySource(reader: reader).sample() == .unavailable)
    }

    @Test func missingSwapReportsZero() throws {
        var reader = FakeMemoryReader()
        reader.swapUsage = nil
        let snap = try #require(MemorySource(reader: reader).sample().current)
        #expect(snap.swapUsedBytes == 0)
    }
}

/// Runs against the real OS: checks sane ranges, not exact numbers.
struct LiveMemoryReaderTests {
    @Test func memory() throws {
        let snap = try #require(MemorySource(reader: LiveMemoryReader()).sample().current)
        #expect(snap.totalBytes > 1_000_000_000)
        #expect(snap.usedBytes > 0)
        #expect(snap.usedBytes <= snap.totalBytes)
    }
}

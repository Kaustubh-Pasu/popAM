import Testing
@testable import PopAMCore

struct FakeNetworkReader: NetworkReading {
    let script: Script<NetworkTotals?>
    init(_ values: [NetworkTotals?]) { script = Script(values) }
    func totals() -> NetworkTotals? { script.next() }
}

struct NetworkSourceTests {
    private func totals(_ rx: UInt64, _ tx: UInt64) -> NetworkTotals {
        NetworkTotals(receivedBytes: rx, sentBytes: tx)
    }

    @Test func computesBytesPerSecond() throws {
        var source = NetworkSource(reader: FakeNetworkReader([totals(1000, 100), totals(5000, 500)]))
        #expect(source.sample(at: 10) == .unavailable)
        let snap = try #require(source.sample(at: 12).current)
        #expect(snap.downBytesPerSec == 2000)
        #expect(snap.upBytesPerSec == 200)
    }

    @Test func counterDecreaseResets() throws {
        let reader = FakeNetworkReader([totals(5000, 5000), totals(10, 10), totals(30, 50)])
        var source = NetworkSource(reader: reader)
        _ = source.sample(at: 0)
        #expect(source.sample(at: 1) == .unavailable)
        let snap = try #require(source.sample(at: 2).current)
        #expect(snap.downBytesPerSec == 20)
        #expect(snap.upBytesPerSec == 40)
    }

    @Test func timeNotAdvancingIsUnavailable() {
        var source = NetworkSource(reader: FakeNetworkReader([totals(0, 0), totals(10, 10)]))
        _ = source.sample(at: 5)
        #expect(source.sample(at: 5) == .unavailable)
    }

    @Test func readerFailureIsUnavailable() {
        var source = NetworkSource(reader: FakeNetworkReader([nil]))
        #expect(source.sample(at: 0) == .unavailable)
        #expect(source.sample(at: 1) == .unavailable)
    }
}

/// Runs against the real OS: checks sane ranges, not exact numbers.
struct LiveNetworkReaderTests {
    @Test func network() throws {
        let totals = try #require(LiveNetworkReader().totals())
        #expect(totals.receivedBytes > 0)
    }
}

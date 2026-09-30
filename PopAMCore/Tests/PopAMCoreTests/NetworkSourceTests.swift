import Testing
@testable import PopAMCore

struct FakeNetworkReader: NetworkReading {
    let script: Script<[String: NetworkTotals]?>
    init(_ values: [[String: NetworkTotals]?]) { script = Script(values) }
    func interfaceTotals() -> [String: NetworkTotals]? { script.next() }
}

struct NetworkSourceTests {
    private func totals(_ rx: UInt64, _ tx: UInt64) -> NetworkTotals {
        NetworkTotals(receivedBytes: rx, sentBytes: tx)
    }

    private func en0(_ rx: UInt64, _ tx: UInt64) -> [String: NetworkTotals] { ["en0": totals(rx, tx)] }

    @Test func computesBytesPerSecond() throws {
        var source = NetworkSource(reader: FakeNetworkReader([en0(1000, 100), en0(5000, 500)]))
        #expect(source.sample(at: 10) == .unavailable)
        let snap = try #require(source.sample(at: 12).current)
        #expect(snap.downBytesPerSec == 2000)
        #expect(snap.upBytesPerSec == 200)
    }

    @Test func sinceBootTotalsSumEveryInterface() throws {
        let reader = FakeNetworkReader([
            en0(0, 0),
            ["en0": totals(1000, 100), "en1": totals(5000, 700)],
        ])
        var source = NetworkSource(reader: reader)
        _ = source.sample(at: 0)
        let snap = try #require(source.sample(at: 1).current)
        #expect(snap.totalReceivedBytes == 6000)
        #expect(snap.totalSentBytes == 800)
    }

    @Test func counterDecreaseResets() throws {
        let reader = FakeNetworkReader([en0(5000, 5000), en0(10, 10), en0(30, 50)])
        var source = NetworkSource(reader: reader)
        _ = source.sample(at: 0)
        #expect(source.sample(at: 1) == .unavailable)
        let snap = try #require(source.sample(at: 2).current)
        #expect(snap.downBytesPerSec == 20)
        #expect(snap.upBytesPerSec == 40)
    }

    @Test func timeNotAdvancingIsUnavailable() {
        var source = NetworkSource(reader: FakeNetworkReader([en0(0, 0), en0(10, 10)]))
        _ = source.sample(at: 5)
        #expect(source.sample(at: 5) == .unavailable)
    }

    @Test func readerFailureIsUnavailable() {
        var source = NetworkSource(reader: FakeNetworkReader([nil]))
        #expect(source.sample(at: 0) == .unavailable)
        #expect(source.sample(at: 1) == .unavailable)
    }

    @Test func readerFailureDropsBaseline() {
        var source = NetworkSource(reader: FakeNetworkReader([en0(0, 0), nil, en0(100, 100)]))
        _ = source.sample(at: 0)
        #expect(source.sample(at: 1) == .unavailable)
        #expect(source.sample(at: 2) == .unavailable)
    }

    @Test func resetDropsBaseline() {
        var source = NetworkSource(reader: FakeNetworkReader([en0(0, 0), en0(100, 100)]))
        _ = source.sample(at: 0)
        source.reset()
        #expect(source.sample(at: 1) == .unavailable)
    }

    @Test func appearingInterfaceContributesNothing() throws {
        let huge: UInt64 = 50_000_000_000
        let reader = FakeNetworkReader([
            en0(1000, 100),
            ["en0": totals(3000, 300), "en1": totals(huge, huge)],
            ["en0": totals(5000, 500), "en1": totals(huge + 400, huge + 40)],
        ])
        var source = NetworkSource(reader: reader)
        _ = source.sample(at: 0)
        let first = try #require(source.sample(at: 2).current)
        #expect(first.downBytesPerSec == 1000)
        #expect(first.upBytesPerSec == 100)
        let second = try #require(source.sample(at: 4).current)
        #expect(second.downBytesPerSec == 1200)
        #expect(second.upBytesPerSec == 120)
    }

    @Test func disappearingInterfaceKeepsReadingAvailable() throws {
        let reader = FakeNetworkReader([
            ["en0": totals(1000, 100), "en1": totals(1000, 100)],
            en0(3000, 300),
        ])
        var source = NetworkSource(reader: reader)
        _ = source.sample(at: 0)
        let snap = try #require(source.sample(at: 2).current)
        #expect(snap.downBytesPerSec == 1000)
        #expect(snap.upBytesPerSec == 100)
    }

    @Test func oneInterfaceResettingDoesNotZeroOthers() throws {
        let reader = FakeNetworkReader([
            ["en0": totals(1000, 100), "utun0": totals(9000, 9000)],
            ["en0": totals(3000, 300), "utun0": totals(5, 5)],
        ])
        var source = NetworkSource(reader: reader)
        _ = source.sample(at: 0)
        let snap = try #require(source.sample(at: 2).current)
        #expect(snap.downBytesPerSec == 1000)
        #expect(snap.upBytesPerSec == 100)
    }
}

/// Runs against the real OS: checks sane ranges, not exact numbers.
struct LiveNetworkReaderTests {
    @Test func network() throws {
        let interfaces = try #require(LiveNetworkReader().interfaceTotals())
        #expect(!interfaces.isEmpty)
        #expect(interfaces.values.contains { $0.receivedBytes > 0 })
        #expect(interfaces.keys.allSatisfy { !$0.isEmpty })
    }
}

import Foundation
import Testing
@testable import PopAMCore

struct FakeSystemReader: SystemReading {
    var boot: Date? = Date(timeIntervalSince1970: 1000)
    var load: LoadAverage? = LoadAverage(one: 2.14, five: 1.87, fifteen: 1.62)
    func bootTime() -> Date? { boot }
    func loadAverage() -> LoadAverage? { load }
}

struct SystemSourceTests {
    @Test func uptimeIsNowMinusBoot() throws {
        let source = SystemSource(reader: FakeSystemReader())
        let snap = try #require(source.sample(now: Date(timeIntervalSince1970: 4600)).current)
        #expect(snap.uptimeSeconds == 3600)
        #expect(snap.loadAverage == LoadAverage(one: 2.14, five: 1.87, fifteen: 1.62))
    }

    @Test func eachPartIsOptional() throws {
        let noBoot = SystemSource(reader: FakeSystemReader(boot: nil))
        #expect(try #require(noBoot.sample(now: Date()).current).uptimeSeconds == nil)
        let noLoad = SystemSource(reader: FakeSystemReader(load: nil))
        #expect(try #require(noLoad.sample(now: Date()).current).loadAverage == nil)
    }

    @Test func nothingReadableIsUnavailable() {
        let source = SystemSource(reader: FakeSystemReader(boot: nil, load: nil))
        #expect(source.sample(now: Date()) == .unavailable)
    }
}

struct HistoryPeakTests {
    @Test func peaksAreWindowMaxima() {
        var history = History()
        #expect(history.cpuPeak == nil)
        #expect(history.netDownPeak == nil)
        for v in [0.2, 0.71, 0.3] { history.push(v, to: .cpu) }
        for v in [10.0, 8900.0, 5.0] { history.push(v, to: .netDown) }
        #expect(history.cpuPeak == 0.71)
        #expect(history.netDownPeak == 8900)
    }
}

/// Runs against the real OS: checks sane ranges, not exact numbers.
struct LiveSystemReaderTests {
    @Test func system() throws {
        let snap = try #require(SystemSource(reader: LiveSystemReader()).sample(now: Date()).current)
        #expect(try #require(snap.uptimeSeconds) > 0)
        #expect(try #require(snap.loadAverage).one >= 0)
    }
}

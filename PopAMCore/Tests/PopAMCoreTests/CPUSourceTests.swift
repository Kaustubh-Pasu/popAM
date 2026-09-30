import Testing
@testable import PopAMCore

struct FakeCPUReader: CPUReading {
    let script: Script<[CoreTicks]?>
    init(_ values: [[CoreTicks]?]) { script = Script(values) }
    func coreTicks() -> [CoreTicks]? { script.next() }
}

func ticks(_ user: UInt64, _ system: UInt64, _ idle: UInt64, nice: UInt64 = 0) -> CoreTicks {
    CoreTicks(user: user, system: system, idle: idle, nice: nice)
}

struct CPUSourceTests {
    @Test func firstSampleIsUnavailable() {
        var source = CPUSource(reader: FakeCPUReader([[ticks(0, 0, 0)]]), topology: nil)
        #expect(source.sample() == .unavailable)
    }

    @Test func computesPerCoreAndTotal() throws {
        let reader = FakeCPUReader([
            [ticks(0, 0, 0), ticks(0, 0, 0)],
            // core 0: 30 user + 10 nice + 20 system of 100 → 60%; core 1: all idle → 0%
            [ticks(30, 20, 40, nice: 10), ticks(0, 0, 100)],
        ])
        var source = CPUSource(reader: reader, topology: nil)
        _ = source.sample()
        let snap = try #require(source.sample().current)
        #expect(snap.cores.map(\.load) == [0.6, 0])
        #expect(snap.user == 0.2)      // (30+10) / 200
        #expect(snap.system == 0.1)    // 20 / 200
        #expect(abs(snap.total - 0.3) < 1e-9)
        #expect(snap.cores.allSatisfy { $0.kind == .unknown })
    }

    @Test func counterDecreaseResetsBaseline() throws {
        let reader = FakeCPUReader([
            [ticks(100, 0, 100)],
            [ticks(5, 0, 5)],        // wrapped / reset
            [ticks(15, 0, 15)],
        ])
        var source = CPUSource(reader: reader, topology: nil)
        _ = source.sample()
        #expect(source.sample() == .unavailable)
        let snap = try #require(source.sample().current)
        #expect(snap.total == 0.5)
    }

    @Test func coreCountChangeResetsBaseline() {
        let reader = FakeCPUReader([[ticks(0, 0, 0)], [ticks(1, 0, 1), ticks(1, 0, 1)]])
        var source = CPUSource(reader: reader, topology: nil)
        _ = source.sample()
        #expect(source.sample() == .unavailable)
    }

    @Test func readerFailureIsUnavailable() {
        var source = CPUSource(reader: FakeCPUReader([nil]), topology: nil)
        #expect(source.sample() == .unavailable)
    }

    @Test func noTicksElapsedGivesZeroNotNaN() throws {
        let reader = FakeCPUReader([[ticks(5, 5, 5)]])
        var source = CPUSource(reader: reader, topology: nil)
        _ = source.sample()
        let snap = try #require(source.sample().current)
        #expect(snap.total == 0)
        #expect(snap.cores[0].load == 0)
    }

    @Test func labelsEfficiencyCoresFirst() throws {
        let four = [ticks(0, 0, 0), ticks(0, 0, 0), ticks(0, 0, 0), ticks(0, 0, 0)]
        let reader = FakeCPUReader([four, four.map { _ in ticks(1, 0, 1) }])
        var source = CPUSource(reader: reader, topology: CoreTopology(performance: 2, efficiency: 2))
        _ = source.sample()
        let snap = try #require(source.sample().current)
        #expect(snap.cores.map(\.kind) == [.efficiency, .efficiency, .performance, .performance])
    }

    @Test func mismatchedTopologyFallsBackToUnknown() throws {
        let reader = FakeCPUReader([[ticks(0, 0, 0)], [ticks(1, 0, 1)]])
        var source = CPUSource(reader: reader, topology: CoreTopology(performance: 4, efficiency: 4))
        _ = source.sample()
        let snap = try #require(source.sample().current)
        #expect(snap.cores[0].kind == .unknown)
    }

    @Test func resetMakesNextSampleUnavailable() {
        let reader = FakeCPUReader([[ticks(0, 0, 0)], [ticks(1, 0, 1)], [ticks(2, 0, 2)]])
        var source = CPUSource(reader: reader, topology: nil)
        _ = source.sample()
        _ = source.sample()
        source.reset()
        #expect(source.sample() == .unavailable)
    }
}

/// Runs against the real OS: checks sane ranges, not exact numbers.
struct LiveCPUReaderTests {
    @Test func cpu() throws {
        let ticks = try #require(LiveCPUReader().coreTicks())
        #expect(!ticks.isEmpty)
        if let topology = LiveCPUReader.topology() {
            #expect(topology.performance + topology.efficiency == ticks.count)
        }
    }
}

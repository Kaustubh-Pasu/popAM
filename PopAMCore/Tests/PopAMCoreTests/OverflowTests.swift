import Testing
@testable import PopAMCore

/// Extreme input must degrade to a clamped value, never trap (a trap here kills the app).
struct OverflowTests {
    @Test func percentOfNonFiniteOrHugeFractions() {
        #expect(Formatters.percent(.nan) == "0%")
        #expect(Formatters.percent(.infinity) == "\(Int.max)%")
        #expect(Formatters.percent(-.infinity) == "\(Int.min)%")
        #expect(Formatters.percent(1e300) == "\(Int.max)%")
    }

    @Test func compactBytesOfNonFiniteOrHugeValues() {
        #expect(Formatters.compactBytes(.nan, base: 1000) == "0K")
        #expect(Formatters.compactBytes(.infinity, base: 1000) == "\(Int.max)T")
        #expect(Formatters.compactBytes(1e300, base: 1024) == "\(Int.max)T")
    }

    @Test func uptimeOfNonFiniteOrHugeSeconds() {
        #expect(Formatters.uptime(seconds: .nan) == "0m")
        #expect(Formatters.uptime(seconds: .infinity) == Formatters.uptime(seconds: Double(Int.max)))
        #expect(Formatters.uptime(seconds: 1e300) == Formatters.uptime(seconds: Double(Int.max)))
    }

    @Test func rateOfNonFiniteValues() {
        #expect(Formatters.rate(.nan) == Formatters.rate(0))
        #expect(Formatters.rate(-.infinity) == Formatters.rate(0))
        #expect(Formatters.rate(.infinity).hasSuffix("/s"))
    }

    @Test func durationOfExtremeMinutes() {
        #expect(Formatters.duration(minutes: .max).hasPrefix("\(Int.max / 60):"))
        #expect(!Formatters.duration(minutes: .min).isEmpty)
    }

    @Test func gaugeWithNegativeOrZeroWidth() {
        #expect(TextGauge.bar(0.5, width: -3) == "")
        #expect(TextGauge.bar(1, width: 0) == "")
        #expect(TextGauge.bar(.infinity, width: 4) == "████")
        #expect(TextGauge.levels([.infinity, -.infinity, .nan]) == "█▁▁")
    }

    @Test func batteryWithExtremeCapacities() throws {
        let raw = BatteryRaw(currentCapacity: .max, maxCapacity: 1, isCharging: false, isCharged: false,
                             onAC: false, timeToEmpty: .max, timeToFull: -1, cycleCount: .max,
                             rawMaxCapacity: .max, designCapacity: 1)
        let snap = try #require(BatterySource(reader: FakeBatteryReader(raw: raw)).sample().current)
        #expect(snap.percent == 100)
        #expect(snap.healthPercent == 100)
        let negative = BatteryRaw(currentCapacity: .min, maxCapacity: 1, isCharging: false, isCharged: false,
                                  onAC: false, timeToEmpty: 0, timeToFull: 0, cycleCount: nil,
                                  rawMaxCapacity: .min, designCapacity: 1)
        let low = try #require(BatterySource(reader: FakeBatteryReader(raw: negative)).sample().current)
        #expect(low.percent == 0)
        #expect(low.healthPercent == 0)
    }

    @Test func networkDeltasSumWithoutTrapping() throws {
        let before = ["a": NetworkTotals(receivedBytes: 0, sentBytes: 0),
                      "b": NetworkTotals(receivedBytes: 0, sentBytes: 0)]
        let after = ["a": NetworkTotals(receivedBytes: .max, sentBytes: .max),
                     "b": NetworkTotals(receivedBytes: .max, sentBytes: .max)]
        var source = NetworkSource(reader: FakeNetworkReader([before, after]))
        _ = source.sample(at: 0)
        let snap = try #require(source.sample(at: 1).current)
        #expect(snap.downBytesPerSec == Double(UInt64.max))
        #expect(snap.upBytesPerSec == Double(UInt64.max))
    }
}

struct SaturatingTests {
    @Test func addsAndClampsAtMax() {
        #expect(UInt64(2).saturatingAdd(3) == 5)
        #expect(UInt64.max.saturatingAdd(1) == .max)
    }

    @Test func clampingRoundedIntFromDouble() {
        #expect(Int(clampingRounded: 2.5) == 3)
        #expect(Int(clampingRounded: .nan) == 0)
        #expect(Int(clampingRounded: .infinity) == .max)
        #expect(Int(clampingRounded: -.infinity) == .min)
        #expect(Int(clampingRounded: 9.3e18) == .max)
    }
}

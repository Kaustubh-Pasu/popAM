import Testing
@testable import PopAMCore

final class FakePowerReader: PowerReading {
    var raw: PowerRaw
    private(set) var resets = 0
    init(_ raw: PowerRaw = power()) { self.raw = raw }
    func read() -> PowerRaw { raw }
    func reset() { resets += 1 }
}

/// Defaults: charging on a 96 W charger — 34.2 W in, 18.1 W system, 12.5 V × 1.168 A = +14.6 W battery.
func power(adapter: Double? = 34.2, system: Double? = 18.1, mV: Int? = 12_500, mA: Int? = 1_168,
           temp: Double? = 31, rating: Int? = 96, onAC: Bool = true) -> PowerRaw {
    PowerRaw(adapterW: adapter, systemW: system, batteryVoltageMV: mV, batteryAmperageMA: mA,
             batteryTempC: temp, chargerRatingW: rating, onAC: onAC)
}

private func isClose(_ value: Double?, _ expected: Double) -> Bool {
    value.map { abs($0 - expected) < 1e-9 } ?? false
}

struct PowerSourceTests {
    private func sample(_ raw: PowerRaw) -> Reading<PowerSnapshot> {
        PowerSource(reader: FakePowerReader(raw)).sample()
    }

    @Test func chargingSplitsAdapterPower() throws {
        let snap = try #require(sample(power()).current)
        #expect(snap.adapterW == 34.2)
        #expect(snap.systemW == 18.1)
        #expect(isClose(snap.batteryW, 14.6))
        #expect(isClose(snap.lossW, 1.5))
        #expect(snap.batteryTempC == 31)
        #expect(snap.chargerRatingW == 96)
        #expect(snap.onAC)
    }

    @Test func onBatteryZeroesAdapterAndHidesCharger() throws {
        // AdapterDetails keeps the last charger's values after unplugging.
        let snap = try #require(sample(power(adapter: 0.3, system: 12.3, mA: -984, rating: 96, onAC: false)).current)
        #expect(snap.adapterW == 0)
        #expect(snap.systemW == 12.3)
        #expect(isClose(snap.batteryW, -12.3))
        #expect(snap.lossW == nil)
        #expect(snap.chargerRatingW == nil)
        #expect(!snap.onAC)
    }

    @Test func onBatteryWithoutSMCDerivesSystemFromBattery() throws {
        let snap = try #require(sample(power(adapter: nil, system: nil, mA: -984, temp: nil, onAC: false)).current)
        #expect(isClose(snap.systemW, 12.3))
        #expect(snap.batteryTempC == nil)
    }

    @Test func batteryAssistOnACCountsDischargeAsInput() throws {
        // 30 W in + 10 W from the battery feeds 38 W of system load → 2 W lost.
        let snap = try #require(sample(power(adapter: 30, system: 38, mA: -800)).current)
        #expect(isClose(snap.batteryW, -10))
        #expect(isClose(snap.lossW, 2))
    }

    @Test func desktopHasNoBatteryEdge() throws {
        let snap = try #require(sample(power(adapter: 40, system: 36.5, mV: nil, mA: nil, temp: nil, rating: nil)).current)
        #expect(snap.batteryW == nil)
        #expect(isClose(snap.lossW, 3.5))
        #expect(snap.batteryTempC == nil)
        #expect(snap.chargerRatingW == nil)
    }

    @Test func smcMissingOnACKeepsBatteryEdge() throws {
        let snap = try #require(sample(power(adapter: nil, system: nil, temp: nil)).current)
        #expect(snap.adapterW == nil)
        #expect(snap.systemW == nil)
        #expect(isClose(snap.batteryW, 14.6))
        #expect(snap.lossW == nil)
    }

    @Test func nothingReadableIsUnavailable() {
        #expect(sample(power(adapter: nil, system: nil, mV: nil, mA: nil)) == .unavailable)
        #expect(sample(power(adapter: nil, system: nil, mV: nil, mA: nil, onAC: false)) == .unavailable)
    }

    @Test func rejectsGarbage() throws {
        let snap = try #require(sample(power(adapter: .nan, system: 18.1, mA: 100_000, temp: 300)).current)
        #expect(snap.adapterW == nil)
        #expect(snap.batteryW == nil)   // 12.5 V × 100 A = 1250 W
        #expect(snap.batteryTempC == nil)
        #expect(snap.lossW == nil)
    }

    @Test func negativeRailIsNil() throws {
        let snap = try #require(sample(power(adapter: 34.2, system: -3)).current)
        #expect(snap.systemW == nil)
        #expect(snap.lossW == nil)
    }

    @Test func lossNeverNegative() throws {
        let snap = try #require(sample(power(adapter: 20, system: 25, mA: 0)).current)
        #expect(snap.batteryW == 0)
        #expect(snap.lossW == 0)
    }

    @Test func tinyValuesSnapToZero() throws {
        let snap = try #require(sample(power(adapter: 0.05, system: 0.04, mA: 4)).current)
        #expect(snap.adapterW == 0)
        #expect(snap.systemW == 0)
        #expect(snap.batteryW == 0)   // 12.5 V × 4 mA = 0.05 W
    }

    @Test func resetForwardsToReader() {
        let reader = FakePowerReader()
        PowerSource(reader: reader).reset()
        #expect(reader.resets == 1)
    }
}

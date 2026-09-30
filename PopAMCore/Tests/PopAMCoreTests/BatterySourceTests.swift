import Testing
@testable import PopAMCore

struct FakeBatteryReader: BatteryReading {
    var isPresent = true
    var raw: BatteryRaw? = battery()
    func read() -> BatteryRaw? { raw }
}

func battery(current: Int = 78, max: Int = 100, charging: Bool = false, charged: Bool = false,
             onAC: Bool = false, toEmpty: Int = -1, toFull: Int = -1, cycles: Int? = 212) -> BatteryRaw {
    BatteryRaw(currentCapacity: current, maxCapacity: max, isCharging: charging, isCharged: charged,
               onAC: onAC, timeToEmpty: toEmpty, timeToFull: toFull, cycleCount: cycles)
}

struct BatterySourceTests {
    private func sample(_ raw: BatteryRaw?) -> Reading<BatterySnapshot> {
        BatterySource(reader: FakeBatteryReader(raw: raw)).sample()
    }

    @Test func charging() throws {
        let snap = try #require(sample(battery(current: 78, charging: true, onAC: true, toFull: 42)).current)
        #expect(snap.percent == 78)
        #expect(snap.state == .charging)
        #expect(snap.minutesRemaining == 42)
        #expect(snap.cycleCount == 212)
    }

    @Test func discharging() throws {
        let snap = try #require(sample(battery(toEmpty: 185, toFull: 10)).current)
        #expect(snap.state == .discharging)
        #expect(snap.minutesRemaining == 185)
    }

    @Test func charged() throws {
        let snap = try #require(sample(battery(current: 100, charged: true, onAC: true)).current)
        #expect(snap.state == .charged)
        #expect(snap.minutesRemaining == nil)
    }

    @Test func pluggedInNotCharging() throws {
        let snap = try #require(sample(battery(current: 80, onAC: true, toFull: 30)).current)
        #expect(snap.state == .acNotCharging)
        #expect(snap.minutesRemaining == nil)
    }

    @Test func stillEstimatingIsNil() throws {
        let snap = try #require(sample(battery(toEmpty: -1)).current)
        #expect(snap.minutesRemaining == nil)
    }

    @Test func percentUsesMaxCapacity() throws {
        let snap = try #require(sample(battery(current: 3000, max: 4000)).current)
        #expect(snap.percent == 75)
    }

    @Test func zeroMaxCapacityDoesNotCrash() throws {
        let snap = try #require(sample(battery(current: 50, max: 0)).current)
        #expect(snap.percent == 0)
    }

    @Test func noBattery() {
        #expect(sample(nil) == .unavailable)
        #expect(BatterySource(reader: FakeBatteryReader(isPresent: false, raw: nil)).isPresent == false)
    }
}

/// Runs against the real OS: checks sane ranges, not exact numbers.
struct LiveBatteryReaderTests {
    @Test(.enabled(if: LiveBatteryReader().isPresent, "No internal battery"))
    func battery() throws {
        let snap = try #require(BatterySource(reader: LiveBatteryReader()).sample().current)
        #expect((0...100).contains(snap.percent))
    }
}

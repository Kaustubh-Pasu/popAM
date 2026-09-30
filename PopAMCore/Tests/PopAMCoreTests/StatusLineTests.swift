import Testing
@testable import PopAMCore

struct StatusLineTests {
    private func memory(_ pressure: MemoryPressure) -> Reading<MemorySnapshot> {
        .value(MemorySnapshot(usedBytes: 1, totalBytes: 2, pressure: pressure, swapUsedBytes: 0,
                              swapTotalBytes: 0, appBytes: 0, wiredBytes: 0, compressedBytes: 0))
    }

    private func battery(_ percent: Int, _ state: PowerState) -> Reading<BatterySnapshot> {
        .value(BatterySnapshot(percent: percent, state: state, minutesRemaining: nil, cycleCount: nil))
    }

    @Test func nominalWhenNothingIsWrong() {
        var s = Snapshots()
        #expect(StatusLine.make(s) == "all systems nominal")
        s.memory = memory(.normal)
        s.battery = battery(80, .discharging)
        #expect(StatusLine.make(s) == "all systems nominal")
    }

    @Test func memoryPressure() {
        var s = Snapshots()
        s.memory = memory(.warning)
        #expect(StatusLine.make(s) == "memory pressure warning")
        s.memory = memory(.critical)
        #expect(StatusLine.make(s) == "memory pressure critical")
    }

    @Test func batteryLowOnlyWhileDischarging() {
        var s = Snapshots()
        s.battery = battery(19, .discharging)
        #expect(StatusLine.make(s) == "battery low")
        s.battery = battery(19, .charging)
        #expect(StatusLine.make(s) == "all systems nominal")
        s.battery = battery(20, .discharging)
        #expect(StatusLine.make(s) == "all systems nominal")
    }

    @Test func joinsSeveralWarnings() {
        var s = Snapshots()
        s.memory = memory(.warning)
        s.battery = battery(5, .discharging)
        #expect(StatusLine.make(s) == "memory pressure warning · battery low")
    }
}

import Foundation
import Testing
@testable import PopAMCore

private final class FakeSMC: SMCReading {
    var values: [String: Double] = [:]
    private(set) var reopens = 0
    func read(_ key: String) -> Double? { values[key] }
    func reopen() { reopens += 1 }
}

struct LivePowerReaderTests {
    @Test func int64BitCastsWrappedUnsigned() {
        // The registry reports a negative InstantAmperage as its UInt64 bit pattern.
        #expect(LivePowerReader.int64(NSNumber(value: UInt64(bitPattern: -1000))) == -1000)
        #expect(LivePowerReader.int64(NSNumber(value: 12_479)) == 12_479)
        #expect(LivePowerReader.int64("12") == nil)
        #expect(LivePowerReader.int64(nil) == nil)
    }

    @Test func readsSMCKeys() {
        let smc = FakeSMC()
        smc.values = ["PDTR": 19.6, "PSTR": 17.9, "TB0T": 29.3]
        let raw = LivePowerReader(smc: smc).read()
        #expect(raw.adapterW == 19.6)
        #expect(raw.systemW == 17.9)
        #expect(raw.batteryTempC == 29.3)
    }

    @Test func resetReopensSMC() {
        let smc = FakeSMC()
        LivePowerReader(smc: smc).reset()
        #expect(smc.reopens == 1)
    }
}

struct LivePowerReaderBatteryTests {
    @Test func readsSMCBatteryPower() {
        let smc = FakeSMCForBattery(["B0AP": -5_140])
        #expect(LivePowerReader(smc: smc).read().smcBatteryW == -5.14)
    }

    @Test func fallsBackToSMCVoltageTimesCurrent() throws {
        let smc = FakeSMCForBattery(["B0AV": 12_478, "B0AC": -412])
        let watts = try #require(LivePowerReader(smc: smc).read().smcBatteryW)
        #expect(abs(watts - -5.140_936) < 1e-6)
    }

    @Test func maxInputFromPowerDistribution() {
        #expect(LivePowerReader.maxInput(["IPDInputPower": NSNumber(value: 89_200)]) == 89.2)
        #expect(LivePowerReader.maxInput(["IPDInputPower": NSNumber(value: 0)]) == nil)
        #expect(LivePowerReader.maxInput(nil) == nil)
    }

    @Test func maxInputRemembersLastValueWhileUnplugged() {
        #expect(LivePowerReader.remember(89.2, last: nil) == 89.2)
        #expect(LivePowerReader.remember(nil, last: 89.2) == 89.2)
        #expect(LivePowerReader.remember(60, last: 89.2) == 60)
    }
}

private final class FakeSMCForBattery: SMCReading {
    let values: [String: Double]
    init(_ values: [String: Double]) { self.values = values }
    func read(_ key: String) -> Double? { values[key] }
    func reopen() {}
}

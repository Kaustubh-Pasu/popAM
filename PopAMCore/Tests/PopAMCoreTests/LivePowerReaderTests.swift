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

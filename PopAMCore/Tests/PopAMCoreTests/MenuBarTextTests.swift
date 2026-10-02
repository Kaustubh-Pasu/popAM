import Testing
@testable import PopAMCore

struct MenuBarTextTests {
    @Test func joinsTwoValues() {
        var s = Snapshots()
        s.cpu = .value(CPUSnapshot(total: 0.23, user: 0.15, system: 0.08, cores: []))
        s.memory = .value(MemorySnapshot(usedBytes: UInt64(8.1 * 1024 * 1024 * 1024),
                                         totalBytes: 16 * 1024 * 1024 * 1024, pressure: .normal,
                                         swapUsedBytes: 0, swapTotalBytes: 0,
                                         appBytes: 0, wiredBytes: 0, compressedBytes: 0))
        #expect(MenuBarText.make([.cpuPercent, .ramUsed], from: s) == "23% · 8.1G")
    }

    @Test func unavailableIsDash() {
        #expect(MenuBarText.make([.cpuPercent, .netDown], from: Snapshots()) == "— · —")
    }

    @Test func networkAndDiskAndBattery() {
        var s = Snapshots()
        s.network = .value(NetworkSnapshot(downBytesPerSec: 2_400_000, upBytesPerSec: 120_000,
                                           totalReceivedBytes: 0, totalSentBytes: 0))
        s.disk = .value(DiskSnapshot(freeBytes: 212_000_000_000, totalBytes: 494_000_000_000,
                                     readBytesPerSec: nil, writeBytesPerSec: nil))
        s.battery = .value(BatterySnapshot(percent: 78, state: .charging, minutesRemaining: nil, cycleCount: nil))
        #expect(MenuBarText.make([.netDown, .netUp], from: s) == "2.4M↓ · 120K↑")
        #expect(MenuBarText.make([.diskFree, .batteryPercent], from: s) == "212G · 78%")
    }

    @Test func emptyListIsEmptyString() {
        #expect(MenuBarText.make([], from: Snapshots()) == "")
    }
    @Test func systemWatts() {
        var s = Snapshots()
        #expect(MenuBarText.make([.systemWatts], from: s) == "—")
        s.power = .value(PowerSnapshot(adapterW: 34.2, systemW: 18.4, batteryW: 14.6, lossW: 1.2,
                                       batteryTempC: nil, chargerRatingW: nil, onAC: true))
        #expect(MenuBarText.make([.systemWatts], from: s) == "18W")
    }
}

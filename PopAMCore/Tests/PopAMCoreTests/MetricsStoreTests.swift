import Foundation
import Testing
@testable import PopAMCore

@MainActor
final class MetricsStoreTests {
    /// An absolute-path suite keeps the plist in the temp directory rather than ~/Library/Preferences.
    private let suite = NSTemporaryDirectory() + "PopAMStoreTests-\(UUID().uuidString)"
    private let settings: SettingsStore
    private var time = TimeBox()

    deinit {
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
        CFPreferencesAppSynchronize(suite as CFString)
        try? FileManager.default.removeItem(atPath: suite + ".plist")
    }

    final class TimeBox { var value = 0.0 }

    init() {
        let defaults = UserDefaults(suiteName: suite)!
        settings = SettingsStore(defaults: defaults)
    }

    /// CPU ticks rise by 50 busy / 50 idle every sample → 50%.
    private func makeStore(batteryPresent: Bool = true) -> MetricsStore {
        let cpuScript = (0..<100).map { i in [ticks(UInt64(i) * 50, 0, UInt64(i) * 50)] }
        let netScript = (0..<100).map { i in
            Optional(["en0": NetworkTotals(receivedBytes: UInt64(i) * 2000, sentBytes: UInt64(i) * 200)])
        }
        let readers = MetricReaders(
            cpu: FakeCPUReader(cpuScript), topology: nil,
            memory: FakeMemoryReader(), network: FakeNetworkReader(netScript),
            diskSpace: FakeDiskSpaceReader(), diskIO: FakeDiskIOReader([nil]),
            battery: FakeBatteryReader(isPresent: batteryPresent, raw: batteryPresent ? battery() : nil),
            system: FakeSystemReader())
        let box = time
        return MetricsStore(settings: settings, readers: readers, now: { box.value })
    }

    private func advance(_ store: MetricsStore, times: Int) {
        for _ in 0..<times {
            time.value += 2
            store.tick()
        }
    }

    @Test func iconOnlyAndClosedSamplesNothingAndStopsLoop() {
        let store = makeStore()
        store.start()
        #expect(store.activeMetrics.isEmpty)
        #expect(!store.isLoopRunning)
        #expect(store.snapshots == Snapshots())
    }

    @Test func closedWithTextSamplesOnlyMenuBarMetrics() {
        let store = makeStore()
        settings.menuBarMode = .iconAndText
        settings.setMenuBarValues([.cpuPercent, .netDown])
        #expect(store.activeMetrics == [.cpu, .network])
        advance(store, times: 2)
        #expect(store.snapshots.cpu.current != nil)
        #expect(store.snapshots.memory == .unavailable)
    }

    @Test func openSamplesEnabledCardsImmediately() {
        let store = makeStore()
        settings.setCardEnabled(.disk, false)
        store.popoverVisible = true
        #expect(store.activeMetrics == [.cpu, .memory, .network, .battery])
        #expect(store.isLoopRunning)
        #expect(store.snapshots.memory.current != nil)   // no waiting a full interval
        #expect(store.snapshots.disk == .unavailable)
        store.popoverVisible = false
        #expect(!store.isLoopRunning)
    }

    @Test func systemInfoSampledOnlyWhilePopoverOpen() {
        let store = makeStore()
        settings.menuBarMode = .iconAndText
        advance(store, times: 1)
        #expect(store.snapshots.system == .unavailable)
        store.popoverVisible = true
        #expect(store.snapshots.system.current?.loadAverage?.one == 2.14)
    }

    @Test func computesValuesThroughSources() throws {
        let store = makeStore()
        store.popoverVisible = true
        advance(store, times: 1)
        #expect(try #require(store.snapshots.cpu.current).total == 0.5)
        #expect(try #require(store.snapshots.network.current).downBytesPerSec == 1000)
    }

    @Test func historyCappedAtThirty() {
        let store = makeStore()
        store.popoverVisible = true
        advance(store, times: 45)
        #expect(store.history.cpu.count == History.capacity)
        #expect(store.history.memory.count == History.capacity)
        #expect(store.history.netDown.count == History.capacity)
    }

    @Test func wakeClearsHistoryAndDeltaBaselines() {
        let store = makeStore()
        store.popoverVisible = true
        advance(store, times: 5)
        store.handleWake()
        #expect(store.history.cpu.isEmpty)
        #expect(store.snapshots.cpu == .unavailable)       // first post-wake sample
        #expect(store.snapshots.memory.current != nil)     // non-delta metrics still show
    }

    @Test func noBatteryNeverSamplesBattery() {
        let store = makeStore(batteryPresent: false)
        store.popoverVisible = true
        #expect(!store.activeMetrics.contains(.battery))
        #expect(!store.batteryPresent)
    }

    @Test func closingPopoverDropsDeltaBaselines() throws {
        let store = makeStore()                      // defaults: icon only
        store.popoverVisible = true
        advance(store, times: 3)
        store.popoverVisible = false
        #expect(store.history.cpu.isEmpty)
        #expect(store.snapshots.cpu == .unavailable)
        time.value += 600                            // closed for 10 minutes
        store.popoverVisible = true
        #expect(store.snapshots.cpu == .unavailable) // not a 10-minute average
        #expect(store.snapshots.memory.current != nil)
        advance(store, times: 1)
        #expect(try #require(store.snapshots.cpu.current).total == 0.5)
    }

    @Test func settingsChangeReplansLoop() async {
        let store = makeStore()
        store.start()
        #expect(!store.isLoopRunning)
        settings.menuBarMode = .iconAndText
        for _ in 0..<100 where !store.isLoopRunning { await Task.yield() }
        #expect(store.isLoopRunning)
        settings.menuBarMode = .iconOnly
        for _ in 0..<100 where store.isLoopRunning { await Task.yield() }
        #expect(!store.isLoopRunning)
    }
}

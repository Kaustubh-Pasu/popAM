import Foundation
import Testing
@testable import PopAMCore

@MainActor
final class SettingsStoreTests {
    /// An absolute-path suite keeps the plist in the temp directory rather than ~/Library/Preferences.
    private let suite = NSTemporaryDirectory() + "PopAMTests-\(UUID().uuidString)"
    private let defaults: UserDefaults

    init() {
        defaults = UserDefaults(suiteName: suite)!
    }

    deinit {
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
        CFPreferencesAppSynchronize(suite as CFString)
        try? FileManager.default.removeItem(atPath: suite + ".plist")
    }

    @Test func defaultsOnFirstLaunch() {
        let settings = SettingsStore(defaults: defaults)
        #expect(settings.refreshInterval == 2)
        #expect(settings.menuBarMode == .iconOnly)
        #expect(settings.menuBarValues == [.cpuPercent, .ramUsed])
        #expect(settings.cardOrder == [.cpu, .memory, .network, .disk, .battery])
        #expect(settings.enabledCards == Set(MetricKind.allCases))
    }

    @Test func persistsAcrossInstances() {
        let first = SettingsStore(defaults: defaults)
        first.refreshInterval = 5
        first.menuBarMode = .iconAndText
        first.setMenuBarValues([.netDown])
        first.setCardEnabled(.disk, false)
        first.moveCards(fromOffsets: IndexSet(integer: 4), toOffset: 0)

        let second = SettingsStore(defaults: defaults)
        #expect(second.refreshInterval == 5)
        #expect(second.menuBarMode == .iconAndText)
        #expect(second.menuBarValues == [.netDown])
        #expect(second.enabledCards == [.cpu, .memory, .network, .battery])
        #expect(second.cardOrder == [.battery, .cpu, .memory, .network, .disk])
    }

    @Test func menuBarValuesCappedAtTwoAndDeduplicated() {
        let settings = SettingsStore(defaults: defaults)
        settings.setMenuBarValues([.cpuPercent, .cpuPercent, .netUp, .diskFree])
        #expect(settings.menuBarValues == [.cpuPercent, .netUp])
    }

    @Test func corruptDataFallsBackToDefaults() {
        defaults.set(Data("garbage".utf8), forKey: "menuBarMode")
        defaults.set(Data("[\"cpu\", \"nope\"]".utf8), forKey: "cardOrder")
        defaults.set(7.0, forKey: "refreshInterval")
        let settings = SettingsStore(defaults: defaults)
        #expect(settings.menuBarMode == .iconOnly)
        #expect(settings.cardOrder == [.cpu, .memory, .network, .disk, .battery])
        #expect(settings.refreshInterval == 2)
    }

    @Test func storedOrderMissingKindsGetsThemAppended() {
        #expect(SettingsStore.normalizedOrder([.disk, .cpu, .disk])
                == [.disk, .cpu, .memory, .network, .battery])
    }

    @Test func visibleCardsFollowOrderAndEnabled() {
        let settings = SettingsStore(defaults: defaults)
        settings.setCardEnabled(.memory, false)
        settings.moveCards(fromOffsets: IndexSet(integer: 3), toOffset: 0)
        #expect(settings.visibleCards == [.disk, .cpu, .network, .battery])
    }

    @Test func moveDownMatchesSwiftUISemantics() {
        let settings = SettingsStore(defaults: defaults)
        settings.moveCards(fromOffsets: IndexSet(integer: 0), toOffset: 3)
        #expect(settings.cardOrder == [.memory, .network, .cpu, .disk, .battery])
    }

    @Test func moveWithHiddenBatteryMapsIndices() {
        let settings = SettingsStore(defaults: defaults)
        settings.moveCards(fromOffsets: IndexSet(integer: 4), toOffset: 1)   // battery → 2nd
        #expect(settings.cardOrder == [.cpu, .battery, .memory, .network, .disk])
        let shown: [MetricKind] = [.cpu, .memory, .network, .disk]          // UI hides battery
        settings.moveCards(shown: shown, fromOffsets: IndexSet(integer: 3), toOffset: 1) // disk → before memory
        #expect(settings.cardOrder == [.cpu, .battery, .disk, .memory, .network])
    }
}

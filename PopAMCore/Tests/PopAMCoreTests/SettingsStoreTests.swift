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
        #expect(settings.cardOrder == [.cpu, .memory, .network, .disk, .battery, .power])
        #expect(settings.enabledCards == [])
    }

    @Test func persistsAcrossInstances() {
        let first = SettingsStore(defaults: defaults)
        first.refreshInterval = 5
        first.menuBarMode = .iconAndText
        first.setMenuBarValues([.netDown])
        first.setCardEnabled(.cpu, true)
        first.setCardEnabled(.disk, true)
        first.setCardEnabled(.disk, false)
        first.setCardEnabled(.network, true)
        first.moveCards(fromOffsets: IndexSet(integer: 4), toOffset: 0)

        let second = SettingsStore(defaults: defaults)
        #expect(second.refreshInterval == 5)
        #expect(second.menuBarMode == .iconAndText)
        #expect(second.menuBarValues == [.netDown])
        #expect(second.enabledCards == [.cpu, .network])
        #expect(second.cardOrder == [.battery, .cpu, .memory, .network, .disk, .power])
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
        #expect(settings.cardOrder == [.cpu, .memory, .network, .disk, .battery, .power])
        #expect(settings.refreshInterval == 2)
    }

    @Test(arguments: [Double.nan, .infinity, -.infinity, 0, -1, 1e308, 2.0000001])
    func hostileIntervalFallsBackToDefault(_ interval: Double) {
        defaults.set(interval, forKey: "refreshInterval")
        #expect(SettingsStore(defaults: defaults).refreshInterval == 2)
    }

    @Test func wrongTypesForEveryKeyFallBackToDefaults() {
        defaults.set("fast", forKey: "refreshInterval")
        defaults.set("iconAndText", forKey: "menuBarMode") // a string, not JSON data
        defaults.set(["cpuPercent"], forKey: "menuBarValues") // a plist array, not JSON data
        defaults.set(42, forKey: "cardOrder")
        defaults.set(Date(), forKey: "enabledCards")
        let settings = SettingsStore(defaults: defaults)
        #expect(settings.refreshInterval == 2)
        #expect(settings.menuBarMode == .iconOnly)
        #expect(settings.menuBarValues == [.cpuPercent, .ramUsed])
        #expect(settings.cardOrder == [.cpu, .memory, .network, .disk, .battery, .power])
        #expect(settings.enabledCards == [])
    }

    @Test func wellFormedJSONOfTheWrongShapeFallsBackToDefaults() {
        defaults.set(Data("{\"a\":1}".utf8), forKey: "menuBarValues")
        defaults.set(Data("[[[[[[[[[[\"cpu\"]]]]]]]]]]".utf8), forKey: "cardOrder")
        defaults.set(Data("[\"cpu\",\"gpu\"]".utf8), forKey: "enabledCards")
        defaults.set(Data(), forKey: "menuBarMode")
        let settings = SettingsStore(defaults: defaults)
        #expect(settings.menuBarValues == [.cpuPercent, .ramUsed])
        #expect(settings.cardOrder == [.cpu, .memory, .network, .disk, .battery, .power])
        #expect(settings.enabledCards == [])
        #expect(settings.menuBarMode == .iconOnly)
    }

    @Test func oversizedStoredListsAreNormalized() throws {
        let values = Array(repeating: "netUp", count: 100_000) + ["cpuPercent", "diskFree"]
        defaults.set(try JSONEncoder().encode(values), forKey: "menuBarValues")
        let order = Array(repeating: "disk", count: 100_000)
        defaults.set(try JSONEncoder().encode(order), forKey: "cardOrder")
        let settings = SettingsStore(defaults: defaults)
        #expect(settings.menuBarValues == [.netUp, .cpuPercent])
        #expect(settings.cardOrder == [.disk, .cpu, .memory, .network, .battery, .power])
    }

    @Test func emptyStoredListsAreKept() throws {
        defaults.set(try JSONEncoder().encode([String]()), forKey: "menuBarValues")
        defaults.set(try JSONEncoder().encode([String]()), forKey: "enabledCards")
        let settings = SettingsStore(defaults: defaults)
        #expect(settings.menuBarValues == [])
        #expect(settings.enabledCards == [])
        #expect(settings.visibleCards == [])
    }

    @Test func storedOrderMissingKindsGetsThemAppended() {
        #expect(SettingsStore.normalizedOrder([.disk, .cpu, .disk])
                == [.disk, .cpu, .memory, .network, .battery, .power])
    }

    @Test func visibleCardsFollowOrderAndEnabled() {
        let settings = SettingsStore(defaults: defaults)
        for kind in MetricKind.allCases where kind != .memory { settings.setCardEnabled(kind, true) }
        settings.moveCards(fromOffsets: IndexSet(integer: 3), toOffset: 0)
        #expect(settings.visibleCards == [.disk, .cpu, .network, .battery, .power])
    }

    @Test func moveDownMatchesSwiftUISemantics() {
        let settings = SettingsStore(defaults: defaults)
        settings.moveCards(fromOffsets: IndexSet(integer: 0), toOffset: 3)
        #expect(settings.cardOrder == [.memory, .network, .cpu, .disk, .battery, .power])
    }

    @Test func moveWithHiddenBatteryMapsIndices() {
        let settings = SettingsStore(defaults: defaults)
        settings.moveCards(fromOffsets: IndexSet(integer: 4), toOffset: 1)   // battery → 2nd
        #expect(settings.cardOrder == [.cpu, .battery, .memory, .network, .disk, .power])
        let shown: [MetricKind] = [.cpu, .memory, .network, .disk]          // UI hides battery
        settings.moveCards(shown: shown, fromOffsets: IndexSet(integer: 3), toOffset: 1) // disk → before memory
        #expect(settings.cardOrder == [.cpu, .battery, .disk, .memory, .network, .power])
    }
    @Test func upgradeAppendsPowerDisabled() throws {
        let legacy: [MetricKind] = [.battery, .cpu, .memory, .network, .disk]
        defaults.set(try JSONEncoder().encode(legacy), forKey: "cardOrder")
        defaults.set(try JSONEncoder().encode(Set<MetricKind>([.cpu])), forKey: "enabledCards")
        let settings = SettingsStore(defaults: defaults)
        #expect(settings.cardOrder == legacy + [.power])
        #expect(!settings.enabledCards.contains(.power))
    }
}

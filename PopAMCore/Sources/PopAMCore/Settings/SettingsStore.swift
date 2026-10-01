import Foundation
import Observation

public enum MenuBarMode: String, Codable, CaseIterable, Sendable {
    case iconOnly, iconAndText
}

public enum MenuBarValue: String, Codable, CaseIterable, Sendable {
    case cpuPercent, ramUsed, ramPercent, netDown, netUp, diskFree, batteryPercent

    public var metric: MetricKind {
        switch self {
        case .cpuPercent: .cpu
        case .ramUsed, .ramPercent: .memory
        case .netDown, .netUp: .network
        case .diskFree: .disk
        case .batteryPercent: .battery
        }
    }

    public var label: String {
        switch self {
        case .cpuPercent: "CPU %"
        case .ramUsed: "RAM used"
        case .ramPercent: "RAM %"
        case .netDown: "Net ↓"
        case .netUp: "Net ↑"
        case .diskFree: "Disk free"
        case .batteryPercent: "Battery %"
        }
    }
}

@MainActor
@Observable
public final class SettingsStore {
    public static let allowedIntervals: [Double] = [1, 2, 5]
    public static let maxMenuBarValues = 2

    public var refreshInterval: Double {
        didSet { save(refreshInterval, Key.refreshInterval) }
    }
    public var menuBarMode: MenuBarMode {
        didSet { save(menuBarMode, Key.menuBarMode) }
    }
    /// At most `maxMenuBarValues`, no duplicates. Set via `setMenuBarValues(_:)`.
    public private(set) var menuBarValues: [MenuBarValue]
    /// Always contains every `MetricKind` exactly once.
    public private(set) var cardOrder: [MetricKind]
    public private(set) var enabledCards: Set<MetricKind>

    @ObservationIgnored private let defaults: UserDefaults

    private enum Key {
        static let refreshInterval = "refreshInterval"
        static let menuBarMode = "menuBarMode"
        static let menuBarValues = "menuBarValues"
        static let cardOrder = "cardOrder"
        static let enabledCards = "enabledCards"
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let interval = defaults.object(forKey: Key.refreshInterval) as? Double ?? 2
        refreshInterval = Self.allowedIntervals.contains(interval) ? interval : 2
        menuBarMode = Self.load(MenuBarMode.self, Key.menuBarMode, from: defaults) ?? .iconOnly
        menuBarValues = Self.normalizedValues(
            Self.load([MenuBarValue].self, Key.menuBarValues, from: defaults) ?? [.cpuPercent, .ramUsed])
        cardOrder = Self.normalizedOrder(Self.load([MetricKind].self, Key.cardOrder, from: defaults) ?? [])
        enabledCards = Self.load(Set<MetricKind>.self, Key.enabledCards, from: defaults)
            ?? []
    }

    // MARK: Mutations

    public func setMenuBarValues(_ values: [MenuBarValue]) {
        menuBarValues = Self.normalizedValues(values)
        save(menuBarValues, Key.menuBarValues)
    }

    public func setCardEnabled(_ kind: MetricKind, _ enabled: Bool) {
        if enabled { enabledCards.insert(kind) } else { enabledCards.remove(kind) }
        save(enabledCards, Key.enabledCards)
    }

    public func moveCards(fromOffsets source: IndexSet, toOffset destination: Int) {
        // Same semantics as SwiftUI's Array.move(fromOffsets:toOffset:), which Foundation lacks.
        let moving = source.map { cardOrder[$0] }
        let insertAt = destination - source.count(in: 0..<destination)
        for index in source.reversed() { cardOrder.remove(at: index) }
        cardOrder.insert(contentsOf: moving, at: insertAt)
        save(cardOrder, Key.cardOrder)
    }

    /// Reorder when the UI lists only `shown`, a subsequence of `cardOrder`
    /// (Battery is hidden on Macs without one).
    public func moveCards(shown: [MetricKind], fromOffsets source: IndexSet, toOffset destination: Int) {
        let mapped = IndexSet(source.compactMap { cardOrder.firstIndex(of: shown[$0]) })
        let target = destination < shown.count
            ? cardOrder.firstIndex(of: shown[destination]) ?? cardOrder.count
            : cardOrder.count
        moveCards(fromOffsets: mapped, toOffset: target)
    }

    /// Enabled cards in display order.
    public var visibleCards: [MetricKind] { cardOrder.filter(enabledCards.contains) }

    // MARK: Persistence

    private func save<T: Encodable>(_ value: T, _ key: String) {
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) }
    }

    private func save(_ value: Double, _ key: String) { defaults.set(value, forKey: key) }

    private static func load<T: Decodable>(_ type: T.Type, _ key: String, from defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    static func normalizedValues(_ values: [MenuBarValue]) -> [MenuBarValue] {
        var seen = Set<MenuBarValue>()
        return Array(values.filter { seen.insert($0).inserted }.prefix(maxMenuBarValues))
    }

    /// Drops duplicates, appends kinds missing from storage (e.g. metrics added in a later version).
    static func normalizedOrder(_ stored: [MetricKind]) -> [MetricKind] {
        var seen = Set<MetricKind>()
        let kept = stored.filter { seen.insert($0).inserted }
        return kept + MetricKind.allCases.filter { !seen.contains($0) }
    }
}

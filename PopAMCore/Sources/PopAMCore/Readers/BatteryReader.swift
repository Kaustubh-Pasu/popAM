import Foundation
import IOKit
import IOKit.ps

public struct BatteryRaw: Sendable, Equatable {
    public let currentCapacity: Int
    public let maxCapacity: Int
    public let isCharging: Bool
    public let isCharged: Bool
    public let onAC: Bool
    /// Minutes; -1 while macOS is still estimating.
    public let timeToEmpty: Int
    public let timeToFull: Int
    public let cycleCount: Int?
    /// mAh, from AppleSmartBattery; nil when the registry lacks them.
    public let rawMaxCapacity: Int?
    public let designCapacity: Int?

    public init(currentCapacity: Int, maxCapacity: Int, isCharging: Bool, isCharged: Bool, onAC: Bool,
                timeToEmpty: Int, timeToFull: Int, cycleCount: Int?,
                rawMaxCapacity: Int?, designCapacity: Int?) {
        self.currentCapacity = currentCapacity
        self.maxCapacity = maxCapacity
        self.isCharging = isCharging
        self.isCharged = isCharged
        self.onAC = onAC
        self.timeToEmpty = timeToEmpty
        self.timeToFull = timeToFull
        self.cycleCount = cycleCount
        self.rawMaxCapacity = rawMaxCapacity
        self.designCapacity = designCapacity
    }
}

public protocol BatteryReading {
    /// Whether this Mac has an internal battery. Checked once; drives hiding the Battery UI.
    var isPresent: Bool { get }
    func read() -> BatteryRaw?
}

public struct LiveBatteryReader: BatteryReading {
    public let isPresent: Bool

    public init() {
        isPresent = Self.internalBattery() != nil
    }

    public func read() -> BatteryRaw? {
        guard let desc = Self.internalBattery() else { return nil }
        return BatteryRaw(
            currentCapacity: desc[kIOPSCurrentCapacityKey] as? Int ?? 0,
            maxCapacity: desc[kIOPSMaxCapacityKey] as? Int ?? 100,
            isCharging: desc[kIOPSIsChargingKey] as? Bool ?? false,
            isCharged: desc[kIOPSIsChargedKey] as? Bool ?? false,
            onAC: (desc[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue,
            timeToEmpty: desc[kIOPSTimeToEmptyKey] as? Int ?? -1,
            timeToFull: desc[kIOPSTimeToFullChargeKey] as? Int ?? -1,
            cycleCount: Self.smartBattery("CycleCount"),
            rawMaxCapacity: Self.smartBattery("AppleRawMaxCapacity", nested: "NominalChargeCapacity"),
            designCapacity: Self.smartBattery("DesignCapacity", nested: "DesignCapacity"))
    }

    private static func internalBattery() -> [String: Any]? {
        // Both calls can return NULL, which takeRetainedValue() on the implicit unwrap would trap on.
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }
        for source in list {
            guard let desc = IOPSGetPowerSourceDescription(info, source)?
                .takeUnretainedValue() as? [String: Any] else { continue }
            if desc[kIOPSTypeKey] as? String == kIOPSInternalBatteryType { return desc }
        }
        return nil
    }

    /// A top-level AppleSmartBattery property, falling back to `nested` inside its `BatteryData`
    /// dictionary (newer macOS only reports capacities there).
    private static func smartBattery(_ key: String, nested: String? = nil) -> Int? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        func property(_ name: String) -> Any? {
            IORegistryEntryCreateCFProperty(service, name as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
        }
        if let value = property(key) as? Int { return value }
        guard let nested, let data = property("BatteryData") as? [String: Any] else { return nil }
        return data[nested] as? Int
    }
}

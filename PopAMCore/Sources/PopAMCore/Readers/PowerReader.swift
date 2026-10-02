import Foundation
import IOKit
import IOKit.ps

/// One power sample as read. Every sensor is optional: SMC keys differ by chip and need an
/// entitlement, and desktops have no battery.
public struct PowerRaw: Sendable, Equatable {
    /// SMC `PDTR`: power drawn from the adapter.
    public let adapterW: Double?
    /// SMC `PSTR`: whole-system power.
    public let systemW: Double?
    /// AppleSmartBattery `Voltage`.
    public let batteryVoltageMV: Int?
    /// AppleSmartBattery `InstantAmperage`: positive charging, negative discharging.
    public let batteryAmperageMA: Int?
    /// SMC `TB0T`.
    public let batteryTempC: Double?
    /// AppleSmartBattery `AdapterDetails.Watts`; stale after unplugging.
    public let chargerRatingW: Int?
    public let onAC: Bool
    /// SMC battery power (`B0AP`, or `B0AV` × `B0AC`): + charging, − discharging. Stays live
    /// unplugged, when the registry's `InstantAmperage` can freeze at 0.
    public let smcBatteryW: Double?
    /// The most this Mac accepts from a charger (`PowerDistribution.IPDInputPower`); last value seen on AC.
    public let maxInputW: Double?

    public init(adapterW: Double?, systemW: Double?, batteryVoltageMV: Int?, batteryAmperageMA: Int?,
                batteryTempC: Double?, chargerRatingW: Int?, onAC: Bool,
                smcBatteryW: Double? = nil, maxInputW: Double? = nil) {
        self.adapterW = adapterW
        self.systemW = systemW
        self.batteryVoltageMV = batteryVoltageMV
        self.batteryAmperageMA = batteryAmperageMA
        self.batteryTempC = batteryTempC
        self.chargerRatingW = chargerRatingW
        self.onAC = onAC
        self.smcBatteryW = smcBatteryW
        self.maxInputW = maxInputW
    }
}

public protocol PowerReading {
    func read() -> PowerRaw
    /// Re-establish hardware connections (called after wake).
    func reset()
}

/// SMC rails and battery temperature plus AppleSmartBattery voltage, current and charger rating.
public final class LivePowerReader: PowerReading {
    private let smc: any SMCReading
    private var lastMaxInputW: Double?

    public convenience init() { self.init(smc: LiveSMCReader()) }

    init(smc: any SMCReading) { self.smc = smc }

    public func read() -> PowerRaw {
        let battery = Self.smartBattery(["Voltage", "InstantAmperage", "AdapterDetails", "PowerDistribution"])
        let adapter = battery["AdapterDetails"] as? [String: Any]
        lastMaxInputW = Self.remember(Self.maxInput(battery["PowerDistribution"] as? [String: Any]),
                                      last: lastMaxInputW)
        return PowerRaw(
            adapterW: smc.read("PDTR"),
            systemW: smc.read("PSTR"),
            batteryVoltageMV: Self.int64(battery["Voltage"]).map { Int($0) },
            batteryAmperageMA: Self.int64(battery["InstantAmperage"]).map { Int($0) },
            batteryTempC: smc.read("TB0T"),
            chargerRatingW: Self.int64(adapter?["Watts"]).map { Int($0) },
            onAC: Self.onAC(),
            smcBatteryW: smcBatteryWatts(),
            maxInputW: lastMaxInputW)
    }

    private func smcBatteryWatts() -> Double? {
        if let milliwatts = smc.read("B0AP") { return milliwatts / 1000 }
        guard let millivolts = smc.read("B0AV"), let milliamps = smc.read("B0AC") else { return nil }
        return millivolts * milliamps / 1_000_000
    }

    /// Watts from `PowerDistribution.IPDInputPower` (mW); 0 while unplugged, so nil then.
    static func maxInput(_ distribution: [String: Any]?) -> Double? {
        guard let milliwatts = int64(distribution?["IPDInputPower"]), milliwatts > 0 else { return nil }
        return Double(milliwatts) / 1000
    }

    /// Keeps the last known max input across unplugged samples.
    static func remember(_ value: Double?, last: Double?) -> Double? { value ?? last }

    public func reset() { smc.reopen() }

    /// Registry numbers can hold a negative value as its UInt64 bit pattern, which `as? Int` rejects.
    static func int64(_ value: Any?) -> Int64? {
        (value as? NSNumber)?.int64Value
    }

    /// The named AppleSmartBattery properties; empty on Macs without a battery.
    private static func smartBattery(_ keys: [String]) -> [String: Any] {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return [:] }
        defer { IOObjectRelease(service) }
        var result: [String: Any] = [:]
        for key in keys {
            result[key] = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue()
        }
        return result
    }

    /// True on desktops too: they always draw from AC.
    private static func onAC() -> Bool {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let type = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue()
        else { return true }
        return (type as String) == kIOPSACPowerValue
    }
}

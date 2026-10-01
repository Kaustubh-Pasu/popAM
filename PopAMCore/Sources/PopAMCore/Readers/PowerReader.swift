import Foundation

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

    public init(adapterW: Double?, systemW: Double?, batteryVoltageMV: Int?, batteryAmperageMA: Int?,
                batteryTempC: Double?, chargerRatingW: Int?, onAC: Bool) {
        self.adapterW = adapterW
        self.systemW = systemW
        self.batteryVoltageMV = batteryVoltageMV
        self.batteryAmperageMA = batteryAmperageMA
        self.batteryTempC = batteryTempC
        self.chargerRatingW = chargerRatingW
        self.onAC = onAC
    }
}

public protocol PowerReading {
    func read() -> PowerRaw
    /// Re-establish hardware connections (called after wake).
    func reset()
}

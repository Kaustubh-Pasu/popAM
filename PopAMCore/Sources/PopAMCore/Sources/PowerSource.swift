public struct PowerSource {
    static let maxWatts = 500.0
    /// USB Power Delivery tops out at 240 W; anything above is a corrupt rating.
    static let maxChargerW = 240
    private let reader: any PowerReading

    public init(reader: any PowerReading) { self.reader = reader }

    public func reset() { reader.reset() }

    public func sample() -> Reading<PowerSnapshot> {
        let raw = reader.read()
        let maxInput = raw.maxInputW.flatMap { $0.isFinite && $0 > 0 && $0 <= Self.maxWatts ? $0 : nil }
        // A Mac never draws much more than its input limit; 10% margin for sensor error.
        var adapter = raw.adapterW.flatMap { Self.rail($0, limit: maxInput.map { $0 * 1.1 } ?? Self.maxWatts) }
        var system = raw.systemW.flatMap { Self.rail($0) }
        var battery = Self.batteryWatts(raw)
        if !raw.onAC {
            adapter = 0
            // Unplugged, whatever the system draws comes from the battery, so each stands in for the other.
            if system == nil, let battery { system = max(0, -battery) }
            if battery == nil, let system { battery = -system }
        }
        guard system != nil || battery != nil || (raw.onAC && adapter != nil) else { return .unavailable }
        var loss: Double?
        if raw.onAC, let adapter, let system {
            // Signed battery: a discharging battery is a second input, a charging one an output.
            loss = Self.deadband(max(0, adapter - system - (battery ?? 0)))
        }
        return .value(PowerSnapshot(
            adapterW: adapter, systemW: system, batteryW: battery, lossW: loss,
            batteryTempC: raw.batteryTempC.flatMap { $0.isFinite && (-20...120).contains($0) ? $0 : nil },
            chargerRatingW: raw.onAC ? raw.chargerRatingW.flatMap { (1...Self.maxChargerW).contains($0) ? $0 : nil } : nil,
            onAC: raw.onAC, maxInputW: maxInput))
    }

    /// SMC battery power first: the registry's `InstantAmperage` can sit at 0 while unplugged.
    static func batteryWatts(_ raw: PowerRaw) -> Double? {
        if let watts = raw.smcBatteryW, watts.isFinite, abs(watts) <= maxWatts { return deadband(watts) }
        guard let mV = raw.batteryVoltageMV, let mA = raw.batteryAmperageMA, mV > 0 else { return nil }
        let watts = Double(mV) * Double(mA) / 1_000_000
        return abs(watts) <= maxWatts ? deadband(watts) : nil
    }

    /// An SMC power rail; negative, non-finite or absurd readings are dropped.
    static func rail(_ watts: Double, limit: Double = maxWatts) -> Double? {
        watts.isFinite && watts >= 0 && watts <= limit ? deadband(watts) : nil
    }

    /// Sensor noise around zero would make the diagram flicker.
    static func deadband(_ watts: Double) -> Double { abs(watts) < 0.1 ? 0 : watts }
}

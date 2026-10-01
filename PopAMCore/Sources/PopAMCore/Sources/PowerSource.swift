public struct PowerSource {
    static let maxWatts = 500.0
    private let reader: any PowerReading

    public init(reader: any PowerReading) { self.reader = reader }

    public func reset() { reader.reset() }

    public func sample() -> Reading<PowerSnapshot> {
        let raw = reader.read()
        let battery = Self.batteryWatts(raw)
        var adapter = raw.adapterW.flatMap(Self.rail)
        var system = raw.systemW.flatMap(Self.rail)
        if !raw.onAC {
            adapter = 0
            // Without SMC, the battery's discharge is the best estimate of system load.
            if system == nil, let battery { system = max(0, -battery) }
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
            chargerRatingW: raw.onAC ? raw.chargerRatingW.flatMap { $0 > 0 ? $0 : nil } : nil,
            onAC: raw.onAC))
    }

    static func batteryWatts(_ raw: PowerRaw) -> Double? {
        guard let mV = raw.batteryVoltageMV, let mA = raw.batteryAmperageMA, mV > 0 else { return nil }
        let watts = Double(mV) * Double(mA) / 1_000_000
        return abs(watts) <= maxWatts ? deadband(watts) : nil
    }

    /// An SMC power rail; negative, non-finite or absurd readings are dropped.
    static func rail(_ watts: Double) -> Double? {
        watts.isFinite && watts >= 0 && watts <= maxWatts ? deadband(watts) : nil
    }

    /// Sensor noise around zero would make the diagram flicker.
    static func deadband(_ watts: Double) -> Double { abs(watts) < 0.1 ? 0 : watts }
}

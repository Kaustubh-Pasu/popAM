import Foundation

/// Text for the PWR popover section: a branching box-drawing diagram in monospaced columns.
public enum PowerFlowText {
    static let dash = "—"

    /// "18.1W"; `signed` adds "+" to positive values. nil → "—".
    public static func watts(_ value: Double?, signed: Bool = false) -> String {
        guard let value else { return dash }
        let body = String(format: "%.1fW", abs(value))
        if value < 0 { return "-" + body }
        return signed && value > 0 ? "+" + body : body
    }

    /// Adapter input on AC (or without a battery), battery output on battery.
    public static func header(_ s: PowerSnapshot) -> String {
        if isOnBattery(s) { return "\(watts(s.batteryW.map(abs))) out" }
        return "\(watts(s.adapterW)) in"
    }

    /// e.g. `adapter 34.2W ━━┳━━ system    18.1W`, then `┣━━` / `┗━━` branches aligned under `┳`.
    public static func lines(_ s: PowerSnapshot) -> [String] {
        let onBattery = isOnBattery(s)
        let source = onBattery ? "battery \(watts(s.batteryW.map(abs)))" : "adapter \(watts(s.adapterW))"
        var targets: [(label: String, watts: Double?, signed: Bool)] = [("system", s.systemW, false)]
        if !onBattery {
            if let battery = s.batteryW, battery != 0 { targets.append(("battery", battery, true)) }
            if let loss = s.lossW { targets.append(("loss", loss, false)) }
        }
        let indent = String(repeating: " ", count: source.count + 3)
        return targets.enumerated().map { index, target in
            let isLast = index == targets.count - 1
            let lead = index == 0 ? source + " ━━" : indent
            let junction = index == 0 ? (isLast ? "━" : "┳") : (isLast ? "┗" : "┣")
            let segment = abs(target.watts ?? 0) >= 1 ? "━━" : "──"
            let value = watts(target.watts, signed: target.signed)
            let label = target.label.padding(toLength: 8, withPad: " ", startingAt: 0)
            let padded = String(repeating: " ", count: max(0, 7 - value.count)) + value
            return lead + junction + segment + " " + label + padded
        }
    }

    /// "charger 100W · max 89W" (the Mac's own input limit, when known); nil while on battery.
    public static func charger(_ s: PowerSnapshot) -> String? {
        guard let rating = s.chargerRatingW else { return nil }
        guard let max = s.maxInputW else { return "charger \(rating)W" }
        return "charger \(rating)W · max \(Int(max.rounded()))W"
    }

    /// "bat 31°C" or "bat 88°F".
    public static func temperature(_ s: PowerSnapshot, unit: TemperatureUnit) -> String? {
        s.batteryTempC.map { "bat \(Int(unit.convert(celsius: $0).rounded()))\(unit.symbol)" }
    }

    private static func isOnBattery(_ s: PowerSnapshot) -> Bool { !s.onAC }
}

public struct BatterySource {
    private let reader: any BatteryReading

    public init(reader: any BatteryReading) { self.reader = reader }

    public var isPresent: Bool { reader.isPresent }

    public func sample() -> Reading<BatterySnapshot> {
        guard let raw = reader.read() else { return .unavailable }
        let percent = raw.maxCapacity > 0
            ? Int(clampingRounded: Double(raw.currentCapacity) / Double(raw.maxCapacity) * 100)
            : 0
        let state: PowerState =
            if raw.isCharging { .charging }
            else if raw.onAC && raw.isCharged { .charged }
            else if raw.onAC { .acNotCharging }
            else { .discharging }
        let minutes: Int? = switch state {
        case .charging: raw.timeToFull
        case .discharging: raw.timeToEmpty
        case .charged, .acNotCharging: nil
        }
        return .value(BatterySnapshot(percent: min(100, max(0, percent)), state: state,
                                      minutesRemaining: minutes.flatMap { $0 >= 0 ? $0 : nil },
                                      cycleCount: raw.cycleCount, healthPercent: Self.health(raw)))
    }

    static func health(_ raw: BatteryRaw) -> Int? {
        guard let full = raw.rawMaxCapacity, let design = raw.designCapacity, design > 0 else { return nil }
        // A new battery can exceed its design capacity; System Settings shows that as 100%.
        return min(100, max(0, Int(clampingRounded: Double(full) / Double(design) * 100)))
    }
}

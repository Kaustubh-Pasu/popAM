extension Int {
    /// Rounds, mapping NaN to 0 and anything out of range to `.min`/`.max`, where `Int(_:)` would trap.
    init(clampingRounded value: Double) {
        if value.isNaN {
            self = 0
        } else if value >= 0x1p63 {
            self = .max
        } else if value < -0x1p63 {
            self = .min
        } else {
            self = Int(value.rounded())
        }
    }
}

extension UInt64 {
    func saturatingAdd(_ other: UInt64) -> UInt64 {
        let (sum, overflow) = addingReportingOverflow(other)
        return overflow ? .max : sum
    }
}

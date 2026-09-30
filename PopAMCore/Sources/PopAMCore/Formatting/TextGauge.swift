/// Text-glyph gauges for the terminal-style popover.
public enum TextGauge {
    private static let levelGlyphs = Array("▁▂▃▄▅▆▇█")

    /// 0.5, width 4 -> "██░░". Out-of-range and NaN input is clamped to 0...1.
    public static func bar(_ fraction: Double, width: Int = 18) -> String {
        let width = max(0, width)
        let filled = Int((clamp(fraction) * Double(width)).rounded())
        return String(repeating: "█", count: filled) + String(repeating: "░", count: width - filled)
    }

    /// One block glyph per 0...1 value, lowest "▁" to highest "█".
    public static func levels(_ values: [Double]) -> String {
        String(values.map { levelGlyphs[min(levelGlyphs.count - 1, Int(clamp($0) * Double(levelGlyphs.count)))] })
    }

    private static func clamp(_ value: Double) -> Double {
        value.isNaN ? 0 : min(max(value, 0), 1)
    }
}

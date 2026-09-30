import Foundation

public enum Formatters {
    /// 0.234 -> "23%"
    public static func percent(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded()))%"
    }

    /// RAM sizes (base 1024), e.g. "8 GB".
    public static func memory(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(clamping: bytes), countStyle: .memory)
    }

    /// Disk sizes (base 1000), e.g. "212 GB".
    public static func file(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(clamping: bytes), countStyle: .file)
    }

    /// Transfer rates (base 1000), e.g. "2.4 MB/s".
    public static func rate(_ bytesPerSec: Double) -> String {
        file(UInt64(max(0, bytesPerSec))) + "/s"
    }

    /// Short menu bar form: "8.1G", "120K", "0K". Values below 10 get one decimal.
    public static func compactBytes(_ bytes: Double, base: Double) -> String {
        let units = ["K", "M", "G", "T"]
        var value = max(0, bytes) / base
        var unit = 0
        while value >= base, unit < units.count - 1 {
            value /= base
            unit += 1
        }
        if value == 0 { return "0" + units[unit] }
        if value < 10 { return String(format: "%.1f", value) + units[unit] }
        return "\(Int(value.rounded()))" + units[unit]
    }

    /// 42 -> "0:42", 185 -> "3:05"
    public static func duration(minutes: Int) -> String {
        String(format: "%d:%02d", minutes / 60, minutes % 60)
    }
}

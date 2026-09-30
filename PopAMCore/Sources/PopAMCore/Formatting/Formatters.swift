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
        // Per-call instance: ByteCountFormatter isn't Sendable, so no static under Swift 6.
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.allowsNonnumericFormatting = false
        return formatter.string(fromByteCount: Int64(max(0, min(bytesPerSec, 9e18)))) + "/s"
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

    /// 12m, 4h 12m, 3d 4h
    public static func uptime(seconds: Double) -> String {
        let minutes = Int(max(0, seconds)) / 60
        let (days, hours, mins) = (minutes / 1440, minutes / 60 % 24, minutes % 60)
        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(mins)m" }
        return "\(mins)m"
    }

    /// "2.14 · 1.87 · 1.62"
    public static func loadAverage(_ load: LoadAverage) -> String {
        [load.one, load.five, load.fifteen].map { String(format: "%.2f", $0) }.joined(separator: " · ")
    }

    /// RAM in GiB with one decimal and no unit, e.g. "8.1".
    public static func gigabytes(_ bytes: UInt64) -> String {
        String(format: "%.1f", Double(bytes) / 1_073_741_824)
    }

    /// Whole gigabytes, no unit: base 1024 for RAM ("16"), 1000 for disks ("212").
    public static func wholeGigabytes(_ bytes: UInt64, base: Double) -> String {
        "\(Int((Double(bytes) / (base * base * base)).rounded()))"
    }
}

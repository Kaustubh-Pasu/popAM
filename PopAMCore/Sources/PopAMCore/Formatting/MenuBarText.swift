public enum MenuBarText {
    /// e.g. "23% · 8.1G". Unavailable values render as "—".
    public static func make(_ values: [MenuBarValue], from s: Snapshots) -> String {
        values.map { text(for: $0, s) }.joined(separator: " · ")
    }

    static func text(for value: MenuBarValue, _ s: Snapshots) -> String {
        let dash = "—"
        switch value {
        case .cpuPercent:
            return s.cpu.current.map { Formatters.percent($0.total) } ?? dash
        case .ramUsed:
            return s.memory.current.map { Formatters.compactBytes(Double($0.usedBytes), base: 1024) } ?? dash
        case .ramPercent:
            return s.memory.current.map { Formatters.percent($0.usedFraction) } ?? dash
        case .netDown:
            return s.network.current.map { Formatters.compactBytes($0.downBytesPerSec, base: 1000) + "↓" } ?? dash
        case .netUp:
            return s.network.current.map { Formatters.compactBytes($0.upBytesPerSec, base: 1000) + "↑" } ?? dash
        case .diskFree:
            return s.disk.current.map { Formatters.compactBytes(Double($0.freeBytes), base: 1000) } ?? dash
        case .batteryPercent:
            return s.battery.current.map { "\($0.percent)%" } ?? dash
        }
    }
}

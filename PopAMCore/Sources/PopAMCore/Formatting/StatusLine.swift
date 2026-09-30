/// The popover footer: "all systems nominal" unless something needs attention.
public enum StatusLine {
    public static func make(_ s: Snapshots) -> String {
        var warnings: [String] = []
        switch s.memory.current?.pressure {
        case .warning: warnings.append("memory pressure warning")
        case .critical: warnings.append("memory pressure critical")
        case .normal, nil: break
        }
        if let battery = s.battery.current, battery.state == .discharging, battery.percent < 20 {
            warnings.append("battery low")
        }
        return warnings.isEmpty ? "all systems nominal" : warnings.joined(separator: " · ")
    }
}

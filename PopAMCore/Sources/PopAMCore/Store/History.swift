/// Last `capacity` values per graphed series, oldest first.
public struct History: Sendable, Equatable {
    public static let capacity = 30

    public enum Series { case cpu, memory, netDown, netUp }

    public private(set) var cpu: [Double] = []
    /// Fraction of RAM used, 0...1.
    public private(set) var memory: [Double] = []
    public private(set) var netDown: [Double] = []
    public private(set) var netUp: [Double] = []

    public init() {}

    /// Highest value in the current window, nil when empty.
    public var cpuPeak: Double? { cpu.max() }
    public var netDownPeak: Double? { netDown.max() }

    mutating func push(_ value: Double, to series: Series) {
        switch series {
        case .cpu: Self.append(value, to: &cpu)
        case .memory: Self.append(value, to: &memory)
        case .netDown: Self.append(value, to: &netDown)
        case .netUp: Self.append(value, to: &netUp)
        }
    }

    mutating func clear(_ series: Series) {
        switch series {
        case .cpu: cpu = []
        case .memory: memory = []
        case .netDown: netDown = []
        case .netUp: netUp = []
        }
    }

    private static func append(_ value: Double, to values: inout [Double]) {
        values.append(value)
        if values.count > capacity { values.removeFirst(values.count - capacity) }
    }
}

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

    mutating func push(_ value: Double, to series: Series) {
        switch series {
        case .cpu: Self.append(value, to: &cpu)
        case .memory: Self.append(value, to: &memory)
        case .netDown: Self.append(value, to: &netDown)
        case .netUp: Self.append(value, to: &netUp)
        }
    }

    private static func append(_ value: Double, to values: inout [Double]) {
        values.append(value)
        if values.count > capacity { values.removeFirst(values.count - capacity) }
    }
}

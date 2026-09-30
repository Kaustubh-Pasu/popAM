public struct CPUSource {
    private let reader: any CPUReading
    private let topology: CoreTopology?
    private var previous: [CoreTicks]?

    public init(reader: any CPUReading, topology: CoreTopology?) {
        self.reader = reader
        self.topology = topology
    }

    public mutating func reset() { previous = nil }

    public mutating func sample() -> Reading<CPUSnapshot> {
        guard let current = reader.coreTicks() else { return .unavailable }
        defer { previous = current }
        guard let previous, previous.count == current.count,
              zip(current, previous).allSatisfy({ c, p in
                  c.user >= p.user && c.system >= p.system && c.idle >= p.idle && c.nice >= p.nice
              }) else { return .unavailable }

        var sumUser = 0.0, sumSystem = 0.0, sumTotal = 0.0
        var cores: [CoreLoad] = []
        for (index, (c, p)) in zip(current, previous).enumerated() {
            let user = Double(c.user - p.user + c.nice - p.nice)
            let system = Double(c.system - p.system)
            let total = user + system + Double(c.idle - p.idle)
            sumUser += user
            sumSystem += system
            sumTotal += total
            let load = total == 0 ? 0 : (user + system) / total
            cores.append(CoreLoad(index: index, kind: kind(of: index, coreCount: current.count), load: load))
        }
        guard sumTotal > 0 else {
            return .value(CPUSnapshot(total: 0, user: 0, system: 0, cores: cores))
        }
        let user = sumUser / sumTotal
        let system = sumSystem / sumTotal
        return .value(CPUSnapshot(total: user + system, user: user, system: system, cores: cores))
    }

    /// Assumes efficiency cores are the lowest-numbered logical CPUs (Apple Silicon).
    private func kind(of index: Int, coreCount: Int) -> CoreKind {
        guard let topology, topology.performance + topology.efficiency == coreCount else { return .unknown }
        return index < topology.efficiency ? .efficiency : .performance
    }
}

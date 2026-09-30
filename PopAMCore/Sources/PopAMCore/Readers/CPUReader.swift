import Darwin

public struct CoreTicks: Sendable, Equatable {
    public let user: UInt64
    public let system: UInt64
    public let idle: UInt64
    public let nice: UInt64

    public init(user: UInt64, system: UInt64, idle: UInt64, nice: UInt64) {
        self.user = user
        self.system = system
        self.idle = idle
        self.nice = nice
    }
}

public protocol CPUReading {
    /// Cumulative ticks per logical core, or nil on failure.
    func coreTicks() -> [CoreTicks]?
}

public struct CoreTopology: Sendable, Equatable {
    public let performance: Int
    public let efficiency: Int

    public init(performance: Int, efficiency: Int) {
        self.performance = performance
        self.efficiency = efficiency
    }
}

public struct LiveCPUReader: CPUReading {
    private let log = ReaderLog(category: "cpu")

    public init() {}

    public func coreTicks() -> [CoreTicks]? {
        var cpuCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        let kr = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO,
                                     &cpuCount, &info, &infoCount)
        guard kr == KERN_SUCCESS, let info else {
            log.failure("host_processor_info failed: \(kr)")
            return nil
        }
        defer {
            let size = vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), size)
        }
        return (0..<Int(cpuCount)).map { core in
            let base = core * Int(CPU_STATE_MAX)
            func ticks(_ state: Int32) -> UInt64 {
                UInt64(UInt32(bitPattern: info[base + Int(state)]))
            }
            return CoreTicks(user: ticks(CPU_STATE_USER), system: ticks(CPU_STATE_SYSTEM),
                             idle: ticks(CPU_STATE_IDLE), nice: ticks(CPU_STATE_NICE))
        }
    }

    /// P/E core counts, or nil on Intel / single-perflevel machines.
    public static func topology() -> CoreTopology? {
        guard let levels = Sysctl.int32("hw.nperflevels"), levels >= 2,
              let p = Sysctl.int32("hw.perflevel0.logicalcpu"),
              let e = Sysctl.int32("hw.perflevel1.logicalcpu") else { return nil }
        return CoreTopology(performance: Int(p), efficiency: Int(e))
    }
}

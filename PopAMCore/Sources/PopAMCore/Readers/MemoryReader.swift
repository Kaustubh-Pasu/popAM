import Darwin

public struct VMStats: Sendable, Equatable {
    public let internalPages: UInt64
    public let purgeablePages: UInt64
    public let wiredPages: UInt64
    public let compressedPages: UInt64
    public let pageSize: UInt64

    public init(internalPages: UInt64, purgeablePages: UInt64, wiredPages: UInt64,
                compressedPages: UInt64, pageSize: UInt64) {
        self.internalPages = internalPages
        self.purgeablePages = purgeablePages
        self.wiredPages = wiredPages
        self.compressedPages = compressedPages
        self.pageSize = pageSize
    }
}

public struct SwapUsage: Sendable, Equatable {
    public let used: UInt64
    public let total: UInt64

    public init(used: UInt64, total: UInt64) {
        self.used = used
        self.total = total
    }
}

public protocol MemoryReading {
    func vmStats() -> VMStats?
    func totalBytes() -> UInt64?
    /// Raw `kern.memorystatus_vm_pressure_level` (1 normal, 2 warning, 4 critical).
    func pressureLevel() -> Int32?
    func swap() -> SwapUsage?
}

public struct LiveMemoryReader: MemoryReading {
    private let log = ReaderLog(category: "memory")

    public init() {}

    public func vmStats() -> VMStats? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let kr = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else {
            log.failure("host_statistics64 failed: \(kr)")
            return nil
        }
        return VMStats(internalPages: UInt64(stats.internal_page_count),
                       purgeablePages: UInt64(stats.purgeable_count),
                       wiredPages: UInt64(stats.wire_count),
                       compressedPages: UInt64(stats.compressor_page_count),
                       pageSize: UInt64(getpagesize()))
    }

    public func totalBytes() -> UInt64? { Sysctl.uint64("hw.memsize") }

    public func pressureLevel() -> Int32? { Sysctl.int32("kern.memorystatus_vm_pressure_level") }

    public func swap() -> SwapUsage? {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        guard sysctlbyname("vm.swapusage", &usage, &size, nil, 0) == 0 else { return nil }
        return SwapUsage(used: usage.xsu_used, total: usage.xsu_total)
    }
}

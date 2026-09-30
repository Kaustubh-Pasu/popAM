public struct MemorySource {
    private let reader: any MemoryReading

    public init(reader: any MemoryReading) { self.reader = reader }

    public func sample() -> Reading<MemorySnapshot> {
        guard let vm = reader.vmStats(), let total = reader.totalBytes() else { return .unavailable }
        // Activity Monitor's "Memory Used" = app memory + wired + compressed.
        let appPages = vm.internalPages > vm.purgeablePages ? vm.internalPages - vm.purgeablePages : 0
        let used = (appPages + vm.wiredPages + vm.compressedPages) * vm.pageSize
        let swap = reader.swap() ?? SwapUsage(used: 0, total: 0)
        return .value(MemorySnapshot(usedBytes: min(used, total), totalBytes: total,
                                     pressure: Self.pressure(reader.pressureLevel()),
                                     swapUsedBytes: swap.used, swapTotalBytes: swap.total))
    }

    static func pressure(_ level: Int32?) -> MemoryPressure {
        switch level {
        case 2: .warning
        case 4: .critical
        default: .normal
        }
    }
}

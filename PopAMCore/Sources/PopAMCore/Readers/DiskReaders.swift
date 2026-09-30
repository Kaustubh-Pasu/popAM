import Foundation
import IOKit

public struct DiskSpace: Sendable, Equatable {
    public let free: UInt64
    public let total: UInt64

    public init(free: UInt64, total: UInt64) {
        self.free = free
        self.total = total
    }
}

public struct DiskIOTotals: Sendable, Equatable {
    public let readBytes: UInt64
    public let writtenBytes: UInt64

    public init(readBytes: UInt64, writtenBytes: UInt64) {
        self.readBytes = readBytes
        self.writtenBytes = writtenBytes
    }
}

public protocol DiskSpaceReading {
    func space() -> DiskSpace?
}

public protocol DiskIOReading {
    /// Cumulative bytes over all block storage drivers, or nil if none found.
    func totals() -> DiskIOTotals?
}

public struct LiveDiskSpaceReader: DiskSpaceReading {
    private let log = ReaderLog(category: "disk")

    public init() {}

    public func space() -> DiskSpace? {
        let keys: Set<URLResourceKey> = [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey]
        guard let values = try? URL(fileURLWithPath: "/").resourceValues(forKeys: keys),
              let free = values.volumeAvailableCapacityForImportantUsage,
              let total = values.volumeTotalCapacity else {
            log.failure("volume capacity unavailable for /")
            return nil
        }
        return DiskSpace(free: UInt64(max(0, free)), total: UInt64(max(0, total)))
    }
}

public struct LiveDiskIOReader: DiskIOReading {
    private let log = ReaderLog(category: "disk-io")

    public init() {}

    public func totals() -> DiskIOTotals? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOBlockStorageDriver"),
                                           &iterator) == KERN_SUCCESS else {
            log.failure("IOBlockStorageDriver matching failed")
            return nil
        }
        defer { IOObjectRelease(iterator) }
        var read: UInt64 = 0
        var written: UInt64 = 0
        var found = false
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            guard let stats = IORegistryEntryCreateCFProperty(service, "Statistics" as CFString,
                                                              kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? [String: Any] else { continue }
            read = read.saturatingAdd((stats["Bytes (Read)"] as? NSNumber)?.uint64Value ?? 0)
            written = written.saturatingAdd((stats["Bytes (Write)"] as? NSNumber)?.uint64Value ?? 0)
            found = true
        }
        return found ? DiskIOTotals(readBytes: read, writtenBytes: written) : nil
    }
}

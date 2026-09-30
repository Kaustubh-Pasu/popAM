import Darwin
import Foundation

public protocol SystemReading {
    func bootTime() -> Date?
    func loadAverage() -> LoadAverage?
}

public struct LiveSystemReader: SystemReading {
    private let log = ReaderLog(category: "system")

    public init() {}

    public func bootTime() -> Date? {
        var boot = timeval()
        var size = MemoryLayout<timeval>.size
        guard sysctlbyname("kern.boottime", &boot, &size, nil, 0) == 0, boot.tv_sec > 0 else {
            log.failure("sysctl kern.boottime failed")
            return nil
        }
        return Date(timeIntervalSince1970: Double(boot.tv_sec) + Double(boot.tv_usec) / 1_000_000)
    }

    public func loadAverage() -> LoadAverage? {
        var loads = [Double](repeating: 0, count: 3)
        guard getloadavg(&loads, 3) == 3 else {
            log.failure("getloadavg failed")
            return nil
        }
        return LoadAverage(one: loads[0], five: loads[1], fifteen: loads[2])
    }
}

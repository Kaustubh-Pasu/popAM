import Darwin

public struct NetworkTotals: Sendable, Equatable {
    public let receivedBytes: UInt64
    public let sentBytes: UInt64

    public init(receivedBytes: UInt64, sentBytes: UInt64) {
        self.receivedBytes = receivedBytes
        self.sentBytes = sentBytes
    }
}

public protocol NetworkReading {
    /// Cumulative bytes over all up, non-loopback interfaces, or nil on failure.
    func totals() -> NetworkTotals?
}

public struct LiveNetworkReader: NetworkReading {
    private let log = ReaderLog(category: "network")

    public init() {}

    public func totals() -> NetworkTotals? {
        // NET_RT_IFLIST2 gives 64-bit counters; getifaddrs' if_data is 32-bit and wraps at 4 GB.
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var length = 0
        guard sysctl(&mib, 6, nil, &length, nil, 0) == 0 else {
            log.failure("sysctl NET_RT_IFLIST2 size failed")
            return nil
        }
        var buffer = [UInt8](repeating: 0, count: length)
        guard sysctl(&mib, 6, &buffer, &length, nil, 0) == 0 else {
            log.failure("sysctl NET_RT_IFLIST2 failed")
            return nil
        }
        var received: UInt64 = 0
        var sent: UInt64 = 0
        buffer.withUnsafeBytes { raw in
            var offset = 0
            while offset + MemoryLayout<if_msghdr>.size <= length {
                let header = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr.self)
                guard header.ifm_msglen > 0 else { break }
                if Int32(header.ifm_type) == RTM_IFINFO2,
                   offset + MemoryLayout<if_msghdr2>.size <= length {
                    let info = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr2.self)
                    if info.ifm_flags & IFF_UP != 0, info.ifm_flags & IFF_LOOPBACK == 0 {
                        received += info.ifm_data.ifi_ibytes
                        sent += info.ifm_data.ifi_obytes
                    }
                }
                offset += Int(header.ifm_msglen)
            }
        }
        return NetworkTotals(receivedBytes: received, sentBytes: sent)
    }
}

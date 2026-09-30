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
    /// Cumulative bytes per up, non-loopback interface (keyed by name), or nil on failure.
    func interfaceTotals() -> [String: NetworkTotals]?
}

public struct LiveNetworkReader: NetworkReading {
    private let log = ReaderLog(category: "network")

    public init() {}

    public func interfaceTotals() -> [String: NetworkTotals]? {
        // NET_RT_IFLIST2 gives 64-bit counters; getifaddrs' if_data is 32-bit and wraps at 4 GB.
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        // The list can grow between the size call and the data call (an interface appears);
        // the kernel then fails with ENOMEM rather than overrun, so size again and retry.
        for _ in 0..<3 {
            var length = 0
            guard sysctl(&mib, 6, nil, &length, nil, 0) == 0 else {
                log.failure("sysctl NET_RT_IFLIST2 size failed")
                return nil
            }
            length += length / 8
            var buffer = [UInt8](repeating: 0, count: length)
            guard sysctl(&mib, 6, &buffer, &length, nil, 0) == 0 else {
                if errno == ENOMEM { continue }
                log.failure("sysctl NET_RT_IFLIST2 failed")
                return nil
            }
            let counters = buffer.withUnsafeBytes {
                Self.parseInterfaceList(UnsafeRawBufferPointer(rebasing: $0.prefix(length)))
            }
            var result: [String: NetworkTotals] = [:]
            for interface in counters {
                var name = [CChar](repeating: 0, count: Int(IF_NAMESIZE))
                guard if_indextoname(UInt32(interface.index), &name) != nil else { continue }
                result[String(decoding: name.prefix { $0 != 0 }.map(UInt8.init(bitPattern:)), as: UTF8.self)] =
                    NetworkTotals(receivedBytes: interface.receivedBytes, sentBytes: interface.sentBytes)
            }
            return result
        }
        log.failure("sysctl NET_RT_IFLIST2 kept growing")
        return nil
    }

    /// Up, non-loopback interfaces from a NET_RT_IFLIST2 buffer. Every message starts with
    /// `u_short msglen; u_char version; u_char type`; a length that is shorter than that prefix
    /// or runs past the buffer ends the walk, and an IFINFO2 too short for `if_msghdr2` is skipped.
    static func parseInterfaceList(_ raw: UnsafeRawBufferPointer) -> [InterfaceCounters] {
        let prefix = 4
        let infoSize = MemoryLayout<if_msghdr2>.size
        var result: [InterfaceCounters] = []
        var offset = 0
        while raw.count - offset >= prefix {
            let length = Int(raw.loadUnaligned(fromByteOffset: offset, as: UInt16.self))
            guard length >= prefix, length <= raw.count - offset else { break }
            if Int32(raw[offset + 3]) == RTM_IFINFO2, length >= infoSize {
                let info = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr2.self)
                if info.ifm_flags & IFF_UP != 0, info.ifm_flags & IFF_LOOPBACK == 0 {
                    result.append(InterfaceCounters(index: info.ifm_index,
                                                    receivedBytes: info.ifm_data.ifi_ibytes,
                                                    sentBytes: info.ifm_data.ifi_obytes))
                }
            }
            offset += length
        }
        return result
    }
}

struct InterfaceCounters: Equatable {
    let index: UInt16
    let receivedBytes: UInt64
    let sentBytes: UInt64
}

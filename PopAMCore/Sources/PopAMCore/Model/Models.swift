import Foundation

public enum MetricKind: String, CaseIterable, Codable, Sendable {
    case cpu, memory, network, disk, battery

    public var title: String {
        switch self {
        case .cpu: "CPU"
        case .memory: "Memory"
        case .network: "Network"
        case .disk: "Disk"
        case .battery: "Battery"
        }
    }
}

/// A sampled value, or `.unavailable` (first delta sample, reset, or read failure).
public enum Reading<T: Sendable & Equatable>: Sendable, Equatable {
    case unavailable
    case value(T)

    public var current: T? {
        if case .value(let v) = self { return v }
        return nil
    }
}

public enum CoreKind: Sendable, Equatable {
    case performance, efficiency, unknown
}

public struct CoreLoad: Sendable, Equatable {
    public let index: Int
    public let kind: CoreKind
    /// 0...1
    public let load: Double

    public init(index: Int, kind: CoreKind, load: Double) {
        self.index = index
        self.kind = kind
        self.load = load
    }
}

public struct CPUSnapshot: Sendable, Equatable {
    /// All fractions are 0...1.
    public let total: Double
    public let user: Double
    public let system: Double
    public let cores: [CoreLoad]

    public init(total: Double, user: Double, system: Double, cores: [CoreLoad]) {
        self.total = total
        self.user = user
        self.system = system
        self.cores = cores
    }
}

public enum MemoryPressure: Sendable, Equatable {
    case normal, warning, critical
}

public struct MemorySnapshot: Sendable, Equatable {
    public let usedBytes: UInt64
    public let totalBytes: UInt64
    public let pressure: MemoryPressure
    public let swapUsedBytes: UInt64
    public let swapTotalBytes: UInt64

    public init(usedBytes: UInt64, totalBytes: UInt64, pressure: MemoryPressure,
                swapUsedBytes: UInt64, swapTotalBytes: UInt64) {
        self.usedBytes = usedBytes
        self.totalBytes = totalBytes
        self.pressure = pressure
        self.swapUsedBytes = swapUsedBytes
        self.swapTotalBytes = swapTotalBytes
    }

    public var usedFraction: Double {
        totalBytes == 0 ? 0 : Double(usedBytes) / Double(totalBytes)
    }
}

public struct NetworkSnapshot: Sendable, Equatable {
    public let downBytesPerSec: Double
    public let upBytesPerSec: Double

    public init(downBytesPerSec: Double, upBytesPerSec: Double) {
        self.downBytesPerSec = downBytesPerSec
        self.upBytesPerSec = upBytesPerSec
    }
}

public struct DiskSnapshot: Sendable, Equatable {
    public let freeBytes: UInt64
    public let totalBytes: UInt64
    /// nil when I/O counters are unavailable or on the first sample.
    public let readBytesPerSec: Double?
    public let writeBytesPerSec: Double?

    public init(freeBytes: UInt64, totalBytes: UInt64,
                readBytesPerSec: Double?, writeBytesPerSec: Double?) {
        self.freeBytes = freeBytes
        self.totalBytes = totalBytes
        self.readBytesPerSec = readBytesPerSec
        self.writeBytesPerSec = writeBytesPerSec
    }
}

public enum PowerState: Sendable, Equatable {
    case charging, discharging, charged, acNotCharging
}

public struct BatterySnapshot: Sendable, Equatable {
    public let percent: Int
    public let state: PowerState
    /// nil = "Calculating…" or not applicable.
    public let minutesRemaining: Int?
    public let cycleCount: Int?

    public init(percent: Int, state: PowerState, minutesRemaining: Int?, cycleCount: Int?) {
        self.percent = percent
        self.state = state
        self.minutesRemaining = minutesRemaining
        self.cycleCount = cycleCount
    }
}

/// Latest reading of every metric.
public struct Snapshots: Sendable, Equatable {
    public var cpu: Reading<CPUSnapshot> = .unavailable
    public var memory: Reading<MemorySnapshot> = .unavailable
    public var network: Reading<NetworkSnapshot> = .unavailable
    public var disk: Reading<DiskSnapshot> = .unavailable
    public var battery: Reading<BatterySnapshot> = .unavailable

    public init() {}
}

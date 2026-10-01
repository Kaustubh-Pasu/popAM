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
    /// The three parts of `usedBytes` (before it is capped at `totalBytes`).
    public let appBytes: UInt64
    public let wiredBytes: UInt64
    public let compressedBytes: UInt64

    public init(usedBytes: UInt64, totalBytes: UInt64, pressure: MemoryPressure,
                swapUsedBytes: UInt64, swapTotalBytes: UInt64,
                appBytes: UInt64, wiredBytes: UInt64, compressedBytes: UInt64) {
        self.usedBytes = usedBytes
        self.totalBytes = totalBytes
        self.pressure = pressure
        self.swapUsedBytes = swapUsedBytes
        self.swapTotalBytes = swapTotalBytes
        self.appBytes = appBytes
        self.wiredBytes = wiredBytes
        self.compressedBytes = compressedBytes
    }

    public var usedFraction: Double {
        totalBytes == 0 ? 0 : Double(usedBytes) / Double(totalBytes)
    }
}

public struct NetworkSnapshot: Sendable, Equatable {
    public let downBytesPerSec: Double
    public let upBytesPerSec: Double
    /// Cumulative since boot, summed over the interfaces currently up.
    public let totalReceivedBytes: UInt64
    public let totalSentBytes: UInt64

    public init(downBytesPerSec: Double, upBytesPerSec: Double,
                totalReceivedBytes: UInt64, totalSentBytes: UInt64) {
        self.downBytesPerSec = downBytesPerSec
        self.upBytesPerSec = upBytesPerSec
        self.totalReceivedBytes = totalReceivedBytes
        self.totalSentBytes = totalSentBytes
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
    /// Full-charge capacity as a percent of design capacity; nil when unknown.
    public let healthPercent: Int?

    public init(percent: Int, state: PowerState, minutesRemaining: Int?, cycleCount: Int?,
                healthPercent: Int? = nil) {
        self.percent = percent
        self.state = state
        self.minutesRemaining = minutesRemaining
        self.cycleCount = cycleCount
        self.healthPercent = healthPercent
    }
}

/// Where power is going right now, in watts.
public struct PowerSnapshot: Sendable, Equatable {
    /// 0 while on battery.
    public let adapterW: Double?
    public let systemW: Double?
    /// + charging, − discharging; nil when there is no battery.
    public let batteryW: Double?
    /// Adapter power not reaching the system or battery; nil on battery or when unknown.
    public let lossW: Double?
    public let batteryTempC: Double?
    /// Charger rating; nil while on battery.
    public let chargerRatingW: Int?
    public let onAC: Bool

    public init(adapterW: Double?, systemW: Double?, batteryW: Double?, lossW: Double?,
                batteryTempC: Double?, chargerRatingW: Int?, onAC: Bool) {
        self.adapterW = adapterW
        self.systemW = systemW
        self.batteryW = batteryW
        self.lossW = lossW
        self.batteryTempC = batteryTempC
        self.chargerRatingW = chargerRatingW
        self.onAC = onAC
    }
}

public struct LoadAverage: Sendable, Equatable {
    public let one: Double
    public let five: Double
    public let fifteen: Double

    public init(one: Double, five: Double, fifteen: Double) {
        self.one = one
        self.five = five
        self.fifteen = fifteen
    }
}

/// Machine-wide info shown in the popover header.
public struct SystemSnapshot: Sendable, Equatable {
    public let uptimeSeconds: Double?
    public let loadAverage: LoadAverage?

    public init(uptimeSeconds: Double?, loadAverage: LoadAverage?) {
        self.uptimeSeconds = uptimeSeconds
        self.loadAverage = loadAverage
    }
}

/// Latest reading of every metric.
public struct Snapshots: Sendable, Equatable {
    public var cpu: Reading<CPUSnapshot> = .unavailable
    public var memory: Reading<MemorySnapshot> = .unavailable
    public var network: Reading<NetworkSnapshot> = .unavailable
    public var disk: Reading<DiskSnapshot> = .unavailable
    public var battery: Reading<BatterySnapshot> = .unavailable
    public var system: Reading<SystemSnapshot> = .unavailable

    public init() {}
}

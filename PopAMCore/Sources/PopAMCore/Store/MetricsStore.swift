import Foundation
import Observation

@MainActor
@Observable
public final class MetricsStore {
    public private(set) var snapshots = Snapshots()
    public private(set) var history = History()

    /// Set by the app when the popover opens/closes. Opening samples immediately.
    public var popoverVisible = false {
        didSet {
            guard popoverVisible != oldValue else { return }
            if popoverVisible { tick() }
            updateLoop()
        }
    }

    public var batteryPresent: Bool { battery.isPresent }
    public var isLoopRunning: Bool { loop != nil }

    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private let now: () -> Double
    @ObservationIgnored private var cpu: CPUSource
    @ObservationIgnored private let memory: MemorySource
    @ObservationIgnored private var network: NetworkSource
    @ObservationIgnored private var disk: DiskSource
    @ObservationIgnored private let battery: BatterySource
    @ObservationIgnored private let system: SystemSource
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var plannedMetrics: Set<MetricKind> = []

    /// - Parameter now: monotonic seconds; injectable for tests.
    public init(settings: SettingsStore, readers: MetricReaders,
                now: @escaping () -> Double = { ProcessInfo.processInfo.systemUptime }) {
        self.settings = settings
        self.now = now
        cpu = CPUSource(reader: readers.cpu, topology: readers.topology)
        memory = MemorySource(reader: readers.memory)
        network = NetworkSource(reader: readers.network)
        disk = DiskSource(space: readers.diskSpace, io: readers.diskIO)
        battery = BatterySource(reader: readers.battery)
        system = SystemSource(reader: readers.system)
    }

    /// Metrics that need sampling right now.
    public var activeMetrics: Set<MetricKind> {
        var kinds: Set<MetricKind>
        if popoverVisible {
            kinds = settings.enabledCards
        } else if settings.menuBarMode == .iconAndText {
            kinds = Set(settings.menuBarValues.map(\.metric))
        } else {
            kinds = []
        }
        if !batteryPresent { kinds.remove(.battery) }
        return kinds
    }

    /// Call once after launch. Re-plans the loop whenever relevant settings change.
    public func start() {
        observeSettings()
        tick()
        updateLoop()
    }

    /// Samples every active metric once.
    public func tick() {
        let time = now()
        // Uptime and load average only appear in the popover header.
        if popoverVisible { snapshots.system = system.sample(now: Date()) }
        for kind in activeMetrics {
            switch kind {
            case .cpu:
                snapshots.cpu = cpu.sample()
                if let v = snapshots.cpu.current { history.push(v.total, to: .cpu) }
            case .memory:
                snapshots.memory = memory.sample()
                if let v = snapshots.memory.current { history.push(v.usedFraction, to: .memory) }
            case .network:
                snapshots.network = network.sample(at: time)
                if let v = snapshots.network.current {
                    history.push(v.downBytesPerSec, to: .netDown)
                    history.push(v.upBytesPerSec, to: .netUp)
                }
            case .disk:
                snapshots.disk = disk.sample(at: time)
            case .battery:
                snapshots.battery = battery.sample()
            }
        }
    }

    /// After sleep: counters jumped and the graphs would show a spike, so start fresh.
    public func handleWake() {
        cpu.reset()
        network.reset()
        disk.reset()
        history = History()
        snapshots = Snapshots()
        tick()
    }

    private func updateLoop() {
        let active = activeMetrics
        // Metrics that stopped being sampled lose their baselines and graphs, so a later
        // reactivation never reports an average over the idle gap.
        for kind in plannedMetrics.subtracting(active) { forget(kind) }
        let newlyActive = !active.subtracting(plannedMetrics).isEmpty
        plannedMetrics = active
        loop?.cancel()
        loop = nil
        guard !active.isEmpty else { return }
        loop = Task { [weak self] in
            // A newly activated delta metric has no baseline yet; get its first real value quickly.
            var firstSleep = newlyActive
            while !Task.isCancelled {
                guard let interval = self?.settings.refreshInterval else { return }
                try? await Task.sleep(for: .seconds(firstSleep ? min(interval, 0.5) : interval))
                firstSleep = false
                guard !Task.isCancelled else { return }
                self?.tick()
            }
        }
    }

    private func observeSettings() {
        withObservationTracking {
            _ = settings.refreshInterval
            _ = settings.menuBarMode
            _ = settings.menuBarValues
            _ = settings.enabledCards
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.tick()
                self?.updateLoop()
                self?.observeSettings()
            }
        }
    }

    private func forget(_ kind: MetricKind) {
        switch kind {
        case .cpu:
            cpu.reset()
            history.clear(.cpu)
            snapshots.cpu = .unavailable
        case .memory:
            history.clear(.memory)
            snapshots.memory = .unavailable
        case .network:
            network.reset()
            history.clear(.netDown)
            history.clear(.netUp)
            snapshots.network = .unavailable
        case .disk:
            disk.reset()
            snapshots.disk = .unavailable
        case .battery:
            snapshots.battery = .unavailable
        }
    }
}

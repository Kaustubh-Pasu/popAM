import Foundation

public struct SystemSource {
    private let reader: any SystemReading

    public init(reader: any SystemReading) { self.reader = reader }

    /// `now` is wall-clock time, since boot time is a wall-clock date.
    public func sample(now: Date) -> Reading<SystemSnapshot> {
        let uptime = reader.bootTime().map { max(0, now.timeIntervalSince($0)) }
        let load = reader.loadAverage()
        guard uptime != nil || load != nil else { return .unavailable }
        return .value(SystemSnapshot(uptimeSeconds: uptime, loadAverage: load))
    }
}

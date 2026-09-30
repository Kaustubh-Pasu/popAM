/// Everything the store reads from. `live()` for the app, fakes for tests.
public struct MetricReaders {
    public var cpu: any CPUReading
    public var topology: CoreTopology?
    public var memory: any MemoryReading
    public var network: any NetworkReading
    public var diskSpace: any DiskSpaceReading
    public var diskIO: any DiskIOReading
    public var battery: any BatteryReading
    public var system: any SystemReading

    public init(cpu: any CPUReading, topology: CoreTopology?, memory: any MemoryReading,
                network: any NetworkReading, diskSpace: any DiskSpaceReading,
                diskIO: any DiskIOReading, battery: any BatteryReading, system: any SystemReading) {
        self.cpu = cpu
        self.topology = topology
        self.memory = memory
        self.network = network
        self.diskSpace = diskSpace
        self.diskIO = diskIO
        self.battery = battery
        self.system = system
    }

    public static func live() -> MetricReaders {
        MetricReaders(cpu: LiveCPUReader(), topology: LiveCPUReader.topology(),
                      memory: LiveMemoryReader(), network: LiveNetworkReader(),
                      diskSpace: LiveDiskSpaceReader(), diskIO: LiveDiskIOReader(),
                      battery: LiveBatteryReader(), system: LiveSystemReader())
    }
}

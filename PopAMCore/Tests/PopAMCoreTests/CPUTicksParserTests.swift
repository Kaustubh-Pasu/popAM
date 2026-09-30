import Darwin
import Testing
@testable import PopAMCore

/// host_processor_info returns a flat integer_t array; the core count must never index past it.
struct CPUTicksParserTests {
    private let states = Int(CPU_STATE_MAX)

    @Test func readsTicksPerCore() {
        var raw = [integer_t](repeating: 0, count: 2 * states)
        raw[Int(CPU_STATE_USER)] = 10
        raw[Int(CPU_STATE_SYSTEM)] = 20
        raw[Int(CPU_STATE_IDLE)] = 30
        raw[Int(CPU_STATE_NICE)] = 40
        raw[states + Int(CPU_STATE_IDLE)] = -1 // wraps past Int32.max; read as unsigned
        let ticks = raw.withUnsafeBufferPointer { LiveCPUReader.coreTicks(from: $0, cpuCount: 2) }
        #expect(ticks == [
            CoreTicks(user: 10, system: 20, idle: 30, nice: 40),
            CoreTicks(user: 0, system: 0, idle: UInt64(UInt32.max), nice: 0),
        ])
    }

    @Test func coreCountLargerThanBufferIsRejected() {
        let raw = [integer_t](repeating: 1, count: 2 * states - 1)
        #expect(raw.withUnsafeBufferPointer { LiveCPUReader.coreTicks(from: $0, cpuCount: 2) } == nil)
    }

    @Test func zeroCoresIsRejected() {
        let raw = [integer_t](repeating: 1, count: states)
        #expect(raw.withUnsafeBufferPointer { LiveCPUReader.coreTicks(from: $0, cpuCount: 0) } == nil)
    }
}

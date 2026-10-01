import Foundation
import IOKit

/// Reads AppleSMC keys. Read-only: only get-key-info and read-key commands are ever sent.
protocol SMCReading: AnyObject {
    func read(_ key: String) -> Double?
    /// Drops the connection so the next read reconnects (after wake).
    func reopen()
}

/// Mirrors the kernel's 80-byte `SMCKeyData_t`. Swift places a field right after the previous
/// field's size (not its C stride), so `padding` stands in for the bytes C adds after `keyInfo`.
struct SMCKeyData {
    struct Version {
        var major: UInt8 = 0, minor: UInt8 = 0, build: UInt8 = 0, reserved: UInt8 = 0
        var release: UInt16 = 0
    }
    struct PowerLimits {
        var version: UInt16 = 0, length: UInt16 = 0
        var cpu: UInt32 = 0, gpu: UInt32 = 0, memory: UInt32 = 0
    }
    struct KeyInfo {
        var dataSize: UInt32 = 0, dataType: UInt32 = 0
        var dataAttributes: UInt8 = 0
    }
    typealias Bytes = (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                       UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                       UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                       UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)

    var key: UInt32 = 0
    var version = Version()
    var powerLimits = PowerLimits()
    var keyInfo = KeyInfo()
    var padding: UInt16 = 0
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: Bytes = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
}

/// Pure SMC value decoding, separate from IOKit so it can be tested.
enum SMCDecode {
    static func fourCC(_ key: String) -> UInt32 {
        key.utf8.reduce(0) { $0 << 8 | UInt32($1) }
    }

    static func typeName(_ code: UInt32) -> String {
        String(decoding: [24, 16, 8, 0].map { UInt8(truncatingIfNeeded: code >> $0) }, as: UTF8.self)
    }

    /// `flt ` is little-endian on Apple silicon; the integer and fixed-point types are big-endian.
    static func value(type: String, bytes: [UInt8]) -> Double? {
        switch type {
        case "flt " where bytes.count >= 4:
            let bits = UInt32(bytes[0]) | UInt32(bytes[1]) << 8 | UInt32(bytes[2]) << 16 | UInt32(bytes[3]) << 24
            return Double(Float(bitPattern: bits))
        case "sp78" where bytes.count >= 2:
            return Double(Int16(bitPattern: UInt16(bytes[0]) << 8 | UInt16(bytes[1]))) / 256
        case "ui8 " where bytes.count >= 1:
            return Double(bytes[0])
        case "ui16" where bytes.count >= 2:
            return Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1]))
        case "ui32" where bytes.count >= 4:
            return Double(bytes.prefix(4).reduce(UInt32(0)) { $0 << 8 | UInt32($1) })
        default:
            return nil
        }
    }
}

/// Holds one AppleSMC connection. Opening needs the `AppleSMCClient` IOKit exception
/// entitlement under the App Sandbox; without it every read returns nil.
final class LiveSMCReader: SMCReading {
    private static let log = ReaderLog(category: "smc")
    private static let selector: UInt32 = 2       // kSMCHandleYPCEvent
    private static let readKeyCommand: UInt8 = 5  // kSMCReadKey
    private static let keyInfoCommand: UInt8 = 9  // kSMCGetKeyInfo

    private var connection: io_connect_t = 0
    private var attempted = false

    init() {}

    deinit { close() }

    func read(_ key: String) -> Double? {
        guard let connection = connect() else { return nil }
        var request = SMCKeyData()
        request.key = SMCDecode.fourCC(key)
        request.data8 = Self.keyInfoCommand
        // A key this Mac lacks fails here; that's normal, so it isn't logged.
        guard let info = call(connection, &request) else { return nil }
        request.data8 = Self.readKeyCommand
        request.keyInfo.dataSize = info.keyInfo.dataSize
        guard let output = call(connection, &request) else { return nil }
        let size = min(Int(info.keyInfo.dataSize), 32)
        let bytes = withUnsafeBytes(of: output.bytes) { Array($0.prefix(size)) }
        return SMCDecode.value(type: SMCDecode.typeName(info.keyInfo.dataType), bytes: bytes)
    }

    func reopen() {
        close()
        attempted = false
    }

    /// Opens once; a failed open stays failed until `reopen()`.
    private func connect() -> io_connect_t? {
        if attempted { return connection == 0 ? nil : connection }
        attempted = true
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else {
            Self.log.failure("AppleSMC service not found")
            return nil
        }
        defer { IOObjectRelease(service) }
        let result = IOServiceOpen(service, mach_task_self_, 0, &connection)
        guard result == kIOReturnSuccess else {
            connection = 0
            Self.log.failure("IOServiceOpen(AppleSMC) failed: \(result); AppleSMCClient entitlement missing?")
            return nil
        }
        return connection
    }

    private func call(_ connection: io_connect_t, _ input: inout SMCKeyData) -> SMCKeyData? {
        var output = SMCKeyData()
        var outputSize = MemoryLayout<SMCKeyData>.stride
        let result = IOConnectCallStructMethod(connection, Self.selector, &input,
                                               MemoryLayout<SMCKeyData>.stride, &output, &outputSize)
        return result == kIOReturnSuccess && output.result == 0 ? output : nil
    }

    private func close() {
        if connection != 0 { IOServiceClose(connection) }
        connection = 0
    }
}

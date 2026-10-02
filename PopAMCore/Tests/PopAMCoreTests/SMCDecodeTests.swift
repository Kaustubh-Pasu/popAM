import Testing
@testable import PopAMCore

struct SMCDecodeTests {
    @Test func structMatchesKernelLayout() {
        #expect(MemoryLayout<SMCKeyData>.size == 80)
        #expect(MemoryLayout<SMCKeyData>.offset(of: \.keyInfo) == 28)
        #expect(MemoryLayout<SMCKeyData>.offset(of: \.result) == 40)
        #expect(MemoryLayout<SMCKeyData>.offset(of: \.data8) == 42)
        #expect(MemoryLayout<SMCKeyData>.offset(of: \.data32) == 44)
        #expect(MemoryLayout<SMCKeyData>.offset(of: \.bytes) == 48)
    }

    @Test func fourCCRoundTrips() {
        #expect(SMCDecode.fourCC("PDTR") == 0x5044_5452)
        #expect(SMCDecode.typeName(0x666C_7420) == "flt ")
    }

    /// Bytes captured from PDTR on an M5 (19.63 W).
    @Test func decodesLittleEndianFloat() throws {
        let value = try #require(SMCDecode.value(type: "flt ", bytes: [47, 2, 157, 65]))
        #expect(abs(value - 19.626) < 0.001)
    }

    /// Apple silicon stores SMC integers little-endian. Bytes captured on an M5 running on battery.
    @Test func decodesLittleEndianIntegers() {
        #expect(SMCDecode.value(type: "ui8 ", bytes: [7]) == 7)
        #expect(SMCDecode.value(type: "ui16", bytes: [0xBE, 0x30]) == 12_478)   // B0AV, mV
        #expect(SMCDecode.value(type: "ui32", bytes: [0x00, 0x01, 0, 0]) == 256)
    }

    @Test func decodesSignedIntegers() {
        #expect(SMCDecode.value(type: "si16", bytes: [0x64, 0xFE]) == -412)       // B0AC, mA
        #expect(SMCDecode.value(type: "si32", bytes: [0xEC, 0xEB, 0xFF, 0xFF]) == -5_140)  // B0AP, mW
    }

    @Test func unknownTypeOrShortBufferIsNil() {
        #expect(SMCDecode.value(type: "ch8*", bytes: [1, 2, 3, 4]) == nil)
        #expect(SMCDecode.value(type: "sp78", bytes: [0x1D, 0x80]) == nil)
        #expect(SMCDecode.value(type: "flt ", bytes: [1, 2]) == nil)
    }
}

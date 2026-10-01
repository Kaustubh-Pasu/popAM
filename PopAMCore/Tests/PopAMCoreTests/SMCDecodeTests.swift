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

    @Test func decodesSignedFixedPoint() {
        #expect(SMCDecode.value(type: "sp78", bytes: [0x1D, 0x80]) == 29.5)
        #expect(SMCDecode.value(type: "sp78", bytes: [0xFF, 0x00]) == -1)
    }

    @Test func decodesBigEndianUnsigned() {
        #expect(SMCDecode.value(type: "ui8 ", bytes: [7]) == 7)
        #expect(SMCDecode.value(type: "ui16", bytes: [0x01, 0x02]) == 258)
        #expect(SMCDecode.value(type: "ui32", bytes: [0, 0, 0x01, 0x00]) == 256)
    }

    @Test func unknownTypeOrShortBufferIsNil() {
        #expect(SMCDecode.value(type: "ch8*", bytes: [1, 2, 3, 4]) == nil)
        #expect(SMCDecode.value(type: "flt ", bytes: [1, 2]) == nil)
    }
}

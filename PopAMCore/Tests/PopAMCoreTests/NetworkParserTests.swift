import Darwin
import Testing
@testable import PopAMCore

/// Crafted NET_RT_IFLIST2 buffers: the parser must never read outside the buffer or trust a
/// message length that doesn't fit.
struct NetworkParserTests {
    private static let infoSize = MemoryLayout<if_msghdr2>.size

    private func info(index: UInt16, flags: Int32 = IFF_UP, rx: UInt64 = 0, tx: UInt64 = 0,
                      msglen: Int? = nil) -> [UInt8] {
        var header = if_msghdr2()
        header.ifm_msglen = UInt16(msglen ?? Self.infoSize)
        header.ifm_type = UInt8(RTM_IFINFO2)
        header.ifm_index = index
        header.ifm_flags = flags
        header.ifm_data.ifi_ibytes = rx
        header.ifm_data.ifi_obytes = tx
        return withUnsafeBytes(of: header) { Array($0) }
    }

    /// A short non-IFINFO2 message, like the RTM_NEWADDR entries interleaved in the real list.
    private func address(length: Int = 20) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: length)
        bytes[0] = UInt8(length & 0xff)
        bytes[1] = UInt8(length >> 8)
        bytes[3] = UInt8(RTM_NEWADDR)
        return bytes
    }

    private func parse(_ bytes: [UInt8]) -> [InterfaceCounters] {
        bytes.withUnsafeBytes { LiveNetworkReader.parseInterfaceList($0) }
    }

    @Test func parsesInterfacesAcrossShortAddressMessages() {
        let buffer = info(index: 4, rx: 1000, tx: 200) + address() + address(length: 28)
            + info(index: 7, rx: 5, tx: 6)
        #expect(parse(buffer) == [
            InterfaceCounters(index: 4, receivedBytes: 1000, sentBytes: 200),
            InterfaceCounters(index: 7, receivedBytes: 5, sentBytes: 6),
        ])
    }

    @Test func skipsDownAndLoopbackInterfaces() {
        let buffer = info(index: 1, flags: IFF_UP | IFF_LOOPBACK) + info(index: 2, flags: 0)
            + info(index: 3)
        #expect(parse(buffer).map(\.index) == [3])
    }

    @Test func emptyAndTinyBuffersYieldNothing() {
        #expect(parse([]) == [])
        #expect(parse([0x10]) == [])
        #expect(parse([0x10, 0, 5]) == [])
    }

    @Test func zeroLengthMessageStopsTheWalk() {
        #expect(parse(info(index: 1, msglen: 0) + info(index: 2)) == [])
    }

    @Test func lengthShorterThanCommonHeaderStopsTheWalk() {
        #expect(parse(info(index: 1, msglen: 3) + info(index: 2)) == [])
    }

    @Test func lengthPastEndOfBufferIsRejected() {
        // Claims more bytes than the buffer holds.
        #expect(parse(info(index: 1, msglen: Self.infoSize + 1)) == [])
        // Truncated mid-message: the header is present but the body isn't.
        #expect(parse(Array(info(index: 1).prefix(Self.infoSize - 1))) == [])
    }

    @Test func infoMessageTooShortForItsStructIsSkippedNotReadPastItsEnd() {
        // A 20-byte IFINFO2 followed by a real one: the short one must not borrow the next
        // message's bytes as its counters, and the walk must continue to the next message.
        let short = Array(info(index: 1, rx: 99, tx: 99, msglen: 20).prefix(20))
        #expect(parse(short + info(index: 2, rx: 7, tx: 8)) == [
            InterfaceCounters(index: 2, receivedBytes: 7, sentBytes: 8),
        ])
    }

    @Test func unalignedMessagesParse() {
        // A 21-byte message leaves the next header at an odd offset.
        #expect(parse(address(length: 21) + info(index: 9, rx: 1, tx: 2)) == [
            InterfaceCounters(index: 9, receivedBytes: 1, sentBytes: 2),
        ])
    }

    @Test func maximumCountersSurvive() {
        #expect(parse(info(index: 1, rx: .max, tx: .max)) == [
            InterfaceCounters(index: 1, receivedBytes: .max, sentBytes: .max),
        ])
    }
}

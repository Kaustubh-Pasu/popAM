import Testing
@testable import PopAMCore

struct FormattersTests {
    @Test func percentRounds() {
        #expect(Formatters.percent(0.234) == "23%")
        #expect(Formatters.percent(0.236) == "24%")
        #expect(Formatters.percent(0) == "0%")
        #expect(Formatters.percent(1) == "100%")
    }

    @Test func compactBytes() {
        #expect(Formatters.compactBytes(8.1 * 1024 * 1024 * 1024, base: 1024) == "8.1G")
        #expect(Formatters.compactBytes(2_400_000, base: 1000) == "2.4M")
        #expect(Formatters.compactBytes(120_000, base: 1000) == "120K")
        #expect(Formatters.compactBytes(212_000_000_000, base: 1000) == "212G")
        #expect(Formatters.compactBytes(500, base: 1000) == "0.5K")
        #expect(Formatters.compactBytes(0, base: 1000) == "0K")
        #expect(Formatters.compactBytes(-5, base: 1000) == "0K")
    }

    @Test func duration() {
        #expect(Formatters.duration(minutes: 42) == "0:42")
        #expect(Formatters.duration(minutes: 185) == "3:05")
    }

    @Test func rateNeverNegative() {
        #expect(Formatters.rate(-100).hasSuffix("/s"))
        #expect(!Formatters.rate(-100).contains("-"))
    }

    @Test func rateIdleAndUnits() {
        #expect(Formatters.rate(0) == "0 KB/s")
        #expect(Formatters.rate(999).hasSuffix("KB/s"))
        #expect(Formatters.rate(2_400_000) == "2.4 MB/s")
    }

    @Test func uptime() {
        #expect(Formatters.uptime(seconds: 30) == "0m")
        #expect(Formatters.uptime(seconds: 12 * 60 + 59) == "12m")
        #expect(Formatters.uptime(seconds: 4 * 3600 + 12 * 60) == "4h 12m")
        #expect(Formatters.uptime(seconds: 3 * 86400 + 4 * 3600 + 59 * 60) == "3d 4h")
        #expect(Formatters.uptime(seconds: -5) == "0m")
    }

    @Test func loadAverage() {
        #expect(Formatters.loadAverage(LoadAverage(one: 2.144, five: 1.87, fifteen: 1.6)) == "2.14 · 1.87 · 1.60")
    }

    @Test func gigabytes() {
        let gib = 1024.0 * 1024 * 1024
        #expect(Formatters.gigabytes(UInt64(8.1 * gib)) == "8.1")
        #expect(Formatters.gigabytes(0) == "0.0")
        #expect(Formatters.wholeGigabytes(UInt64(16 * gib), base: 1024) == "16")
        #expect(Formatters.wholeGigabytes(212_400_000_000, base: 1000) == "212")
    }
}

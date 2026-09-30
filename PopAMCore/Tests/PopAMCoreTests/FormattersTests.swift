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
}

import Testing
@testable import PopAMCore

struct TextGaugeTests {
    @Test func barFillsProportionally() {
        #expect(TextGauge.bar(0.5, width: 4) == "██░░")
        #expect(TextGauge.bar(0, width: 3) == "░░░")
        #expect(TextGauge.bar(1, width: 3) == "███")
        #expect(TextGauge.bar(0.23).count == 18)
    }

    @Test func barClampsBadInput() {
        #expect(TextGauge.bar(1.7, width: 3) == "███")
        #expect(TextGauge.bar(-1, width: 3) == "░░░")
        #expect(TextGauge.bar(.nan, width: 3) == "░░░")
    }

    @Test func levelsPickOneGlyphPerValue() {
        #expect(TextGauge.levels([0, 0.12, 0.5, 0.99, 1, 2, -1]) == "▁▁▅███▁")
    }
}

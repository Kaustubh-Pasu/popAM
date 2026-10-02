import Testing
@testable import PopAMCore

private func snap(adapter: Double? = 34.2, system: Double? = 18.1, battery: Double? = 14.6,
                  loss: Double? = 1.5, temp: Double? = 31.4, rating: Int? = 96,
                  onAC: Bool = true, maxInput: Double? = nil) -> PowerSnapshot {
    PowerSnapshot(adapterW: adapter, systemW: system, batteryW: battery, lossW: loss,
                  batteryTempC: temp, chargerRatingW: rating, onAC: onAC, maxInputW: maxInput)
}

struct PowerFlowTextTests {
    @Test func wattsFormatting() {
        #expect(PowerFlowText.watts(18.14) == "18.1W")
        #expect(PowerFlowText.watts(14.6, signed: true) == "+14.6W")
        #expect(PowerFlowText.watts(-12.3, signed: true) == "-12.3W")
        #expect(PowerFlowText.watts(0, signed: true) == "0.0W")
        #expect(PowerFlowText.watts(nil) == "—")
    }

    @Test func chargingDiagram() {
        #expect(PowerFlowText.header(snap()) == "34.2W in")
        #expect(PowerFlowText.lines(snap()) == [
            "adapter 34.2W ━━┳━━ system    18.1W",
            "                ┣━━ battery  +14.6W",
            "                ┗━━ loss       1.5W",
        ])
    }

    @Test func idleBatteryEdgeHiddenAndSmallLossThin() {
        #expect(PowerFlowText.lines(snap(adapter: 19.6, system: 18.9, battery: 0, loss: 0.7)) == [
            "adapter 19.6W ━━┳━━ system    18.9W",
            "                ┗── loss       0.7W",
        ])
    }

    @Test func onBatteryDiagram() {
        let s = snap(adapter: 0, system: 12.3, battery: -12.3, loss: nil, rating: nil, onAC: false)
        #expect(PowerFlowText.header(s) == "12.3W out")
        #expect(PowerFlowText.lines(s) == ["battery 12.3W ━━━━━ system    12.3W"])
    }

    @Test func batteryAssistShownAsNegativeBranch() {
        #expect(PowerFlowText.lines(snap(adapter: 30, system: 38, battery: -10, loss: 2)) == [
            "adapter 30.0W ━━┳━━ system    38.0W",
            "                ┣━━ battery  -10.0W",
            "                ┗━━ loss       2.0W",
        ])
    }

    @Test func desktopShowsSystemAndLoss() {
        let s = snap(adapter: 40, system: 36.5, battery: nil, loss: 3.5, temp: nil, rating: nil)
        #expect(PowerFlowText.header(s) == "40.0W in")
        #expect(PowerFlowText.lines(s) == [
            "adapter 40.0W ━━┳━━ system    36.5W",
            "                ┗━━ loss       3.5W",
        ])
    }

    @Test func missingSMCShowsDashes() {
        let s = snap(adapter: nil, system: nil, loss: nil, temp: nil)
        #expect(PowerFlowText.header(s) == "— in")
        #expect(PowerFlowText.lines(s) == [
            "adapter — ━━┳── system        —",
            "            ┗━━ battery  +14.6W",
        ])
    }

    @Test func footerParts() {
        #expect(PowerFlowText.charger(snap()) == "charger 96W")
        #expect(PowerFlowText.temperature(snap(), unit: .celsius) == "bat 31°C")
        #expect(PowerFlowText.charger(snap(rating: nil)) == nil)
        #expect(PowerFlowText.temperature(snap(temp: nil), unit: .celsius) == nil)
    }

    @Test func chargerShowsMacMaxInput() {
        #expect(PowerFlowText.charger(snap(rating: 100, maxInput: 89.2)) == "charger 100W · max 89W")
    }

    @Test func unpluggedWithoutBatteryReadingStillReadsAsBattery() {
        let s = snap(adapter: 0, system: 12.3, battery: nil, loss: nil, rating: nil, onAC: false)
        #expect(PowerFlowText.header(s) == "— out")
        #expect(PowerFlowText.lines(s) == ["battery — ━━━━━ system    12.3W"])
    }

    @Test func temperatureInFahrenheit() {
        #expect(PowerFlowText.temperature(snap(temp: 29), unit: .fahrenheit) == "bat 84°F")
        #expect(PowerFlowText.temperature(snap(temp: -20), unit: .fahrenheit) == "bat -4°F")
    }
}

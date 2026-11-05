import XCTest
@testable import SpeedTrack

final class SpeedReadingTests: XCTestCase {
    private let now = Date(timeIntervalSinceReferenceDate: 1_000)

    private func label(_ speed: Double, _ unit: SpeedUnit) -> String {
        SpeedReading(rawSpeed: speed, measuredAt: now).label(in: unit, at: now)
    }

    func testNegativeSpeedIsUnknownInEveryUnit() {
        for unit in SpeedUnit.allCases {
            XCTAssertEqual(label(-1, unit), "--", unit.title)
        }
    }

    func testNonFiniteSpeedIsUnknown() {
        XCTAssertEqual(label(.nan, .kilometersPerHour), "--")
        XCTAssertEqual(label(.infinity, .kilometersPerHour), "--")
    }

    func testTheNamedUnknownReadingShowsNothing() {
        XCTAssertEqual(SpeedReading.unknown.label(in: .kilometersPerHour, at: now), "--")
    }

    func testAReadingIsCurrentForFiveSeconds() {
        let reading = SpeedReading(rawSpeed: 10, measuredAt: now)
        XCTAssertEqual(reading.label(in: .kilometersPerHour, at: now.addingTimeInterval(5)), "36")
    }

    func testAnOlderReadingIsNoLongerShown() {
        let reading = SpeedReading(rawSpeed: 10, measuredAt: now)
        XCTAssertEqual(reading.label(in: .kilometersPerHour, at: now.addingTimeInterval(5.1)), "--")
    }

    func testZeroIsAValidSpeed() {
        XCTAssertEqual(label(0, .kilometersPerHour), "0")
        XCTAssertEqual(label(0, .metersPerSecond), "0.0")
        XCTAssertEqual(label(0, .milesPerHour), "0")
    }

    func testStandingStillHasNoPace() {
        XCTAssertEqual(label(0, .minutesPerKilometer), "--")
        XCTAssertEqual(label(0, .minutesPerMile), "--")
    }

    func testKilometersPerHour() {
        XCTAssertEqual(label(10, .kilometersPerHour), "36")
    }

    func testMetersPerSecondKeepOneDecimal() {
        XCTAssertEqual(label(2.5, .metersPerSecond), "2.5")
    }

    func testMilesPerHour() {
        XCTAssertEqual(label(26.8224, .milesPerHour), "60")
    }

    func testMinutesPerKilometer() {
        XCTAssertEqual(label(2.5, .minutesPerKilometer), "6:40")
    }

    func testMinutesPerMile() {
        XCTAssertEqual(label(1_609.344 / 400, .minutesPerMile), "6:40")
    }

    func testPaceRoundsIntoTheNextMinute() {
        XCTAssertEqual(label(1_000 / 359.7, .minutesPerKilometer), "6:00")
    }

    func testVerySlowPaceIsNotShown() {
        XCTAssertEqual(label(0.2, .minutesPerKilometer), "83:20")
        XCTAssertEqual(label(0.1, .minutesPerKilometer), "--")
        XCTAssertEqual(label(0.1, .minutesPerMile), "--")
    }

    func testLowSpeedOnAStillDeviceIsZero() {
        let reading = SpeedReading(rawSpeed: 0.6, measuredAt: now, deviceIsStill: true)
        XCTAssertEqual(reading.label(in: .metersPerSecond, at: now), "0.0")
    }

    func testLowSpeedOnAMovingDeviceIsKept() {
        XCTAssertEqual(label(0.6, .metersPerSecond), "0.6")
    }

    func testRealSpeedOnAStillDeviceIsKept() {
        let reading = SpeedReading(rawSpeed: 30, measuredAt: now, deviceIsStill: true)
        XCTAssertEqual(reading.label(in: .kilometersPerHour, at: now), "108")
    }

    func testStillnessNeverInventsASpeed() {
        let reading = SpeedReading(rawSpeed: -1, measuredAt: now, deviceIsStill: true)
        XCTAssertEqual(reading.label(in: .kilometersPerHour, at: now), "--")
    }

    func testEveryUnitHasItsOwnTitle() {
        let titles = Set(SpeedUnit.allCases.map(\.title))
        XCTAssertEqual(titles, ["km/h", "m/s", "mph", "min/km", "min/mi"])
    }
}

import XCTest
@testable import SpeedTrack

final class SpeedometerTests: XCTestCase {
    private let now = Date(timeIntervalSinceReferenceDate: 1_000)

    private func reading(_ speed: Double, after seconds: TimeInterval = 0) -> SpeedReading {
        SpeedReading(rawSpeed: speed, measuredAt: now.addingTimeInterval(seconds))
    }

    private func assertShown(
        _ speedometer: Speedometer,
        after seconds: TimeInterval = 0,
        in unit: SpeedUnit = .kilometersPerHour,
        _ label: String,
        isCurrent: Bool,
        line: UInt = #line
    ) {
        let shown = speedometer.shown(in: unit, at: now.addingTimeInterval(seconds))
        XCTAssertEqual(shown.label, label, line: line)
        XCTAssertEqual(shown.isCurrent, isCurrent, line: line)
    }

    func testNothingMeasuredShowsNothing() {
        assertShown(Speedometer(), "--", isCurrent: false)
    }

    func testAFreshSpeedIsCurrent() {
        var speedometer = Speedometer()
        speedometer.record(reading(10))
        assertShown(speedometer, after: SpeedReading.maximumAge, "36", isCurrent: true)
    }

    func testAnOldSpeedStaysButIsNotCurrent() {
        var speedometer = Speedometer()
        speedometer.record(reading(10))
        assertShown(speedometer, after: SpeedReading.maximumAge + 0.1, "36", isCurrent: false)
        assertShown(speedometer, after: 3_600, "36", isCurrent: false)
    }

    func testAFixWithoutASpeedKeepsTheLastSpeed() {
        var speedometer = Speedometer()
        speedometer.record(reading(10))
        speedometer.record(reading(-1, after: 1))
        assertShown(speedometer, after: 1, "36", isCurrent: false)
        // The status line reads the newest fix, so it says that no speed comes in.
        XCTAssertEqual(speedometer.latest, reading(-1, after: 1))
    }

    func testANewSpeedReplacesTheLastOne() {
        var speedometer = Speedometer()
        speedometer.record(reading(10))
        speedometer.record(reading(5, after: 1))
        assertShown(speedometer, after: 1, "18", isCurrent: true)
    }

    func testAStandstillIsALastSpeedToo() {
        var speedometer = Speedometer()
        speedometer.record(reading(0))
        speedometer.record(reading(-1, after: 1))
        assertShown(speedometer, after: 1, "0", isCurrent: false)
    }

    func testLosingPermissionKeepsTheLastSpeed() {
        var speedometer = Speedometer()
        speedometer.record(reading(10))
        speedometer.forgetLocation()
        assertShown(speedometer, "36", isCurrent: false)
        XCTAssertEqual(speedometer.latest, .unknown)
    }

    func testTheLastSpeedFollowsTheUnit() {
        var speedometer = Speedometer()
        speedometer.record(reading(2.5))
        assertShown(speedometer, after: 60, in: .minutesPerKilometer, "6:40", isCurrent: false)
        assertShown(speedometer, after: 60, in: .metersPerSecond, "2.5", isCurrent: false)
    }
}

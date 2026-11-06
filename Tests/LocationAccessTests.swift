import XCTest
@testable import SpeedTrack

final class LocationAccessTests: XCTestCase {
    private let now = Date(timeIntervalSinceReferenceDate: 1_000)
    private let looking = "Looking for your location"
    private let locationOnly = "Location found, no speed yet"
    private let locationAndSpeed = "Location and speed available"

    private func message(speed: Double, age: TimeInterval) -> String {
        let reading = SpeedReading(rawSpeed: speed, measuredAt: now.addingTimeInterval(-age))
        return LocationAccess.precise.message(for: reading, at: now)
    }

    func testPermissionOutranksEveryReading() {
        let readings = [
            SpeedReading(rawSpeed: 10, measuredAt: now),
            SpeedReading(rawSpeed: -1, measuredAt: now),
            SpeedReading.unknown,
        ]
        let messages: [(LocationAccess, String)] = [
            (.undecided, "Waiting for location permission"),
            (.denied, "Location is off. Turn it on in Settings."),
            (.restricted, "Location is restricted on this iPhone"),
            (.approximate, "Turn on Precise Location in Settings."),
        ]
        for (access, expected) in messages {
            for reading in readings {
                XCTAssertEqual(access.message(for: reading, at: now), expected)
            }
        }
    }

    func testRestrictedGivesNoInstruction() {
        let message = LocationAccess.restricted.message(for: .unknown, at: now)
        XCTAssertFalse(message.contains("Settings"))
    }

    func testAFreshSpeedHasLocationAndSpeed() {
        XCTAssertEqual(message(speed: 10, age: 0), locationAndSpeed)
    }

    func testAValidZeroIsASpeed() {
        XCTAssertEqual(message(speed: 0, age: 0), locationAndSpeed)
    }

    func testAFixWithoutASpeedIsLocationOnly() {
        XCTAssertEqual(message(speed: -1, age: 0), locationOnly)
    }

    func testASpeedStopsCountingBeforeTheLocationDoes() {
        XCTAssertEqual(message(speed: 10, age: SpeedReading.maximumAge), locationAndSpeed)
        XCTAssertEqual(message(speed: 10, age: SpeedReading.maximumAge + 0.1), locationOnly)
    }

    func testALocationCountsForThirtySeconds() {
        XCTAssertEqual(message(speed: -1, age: 30), locationOnly)
        XCTAssertEqual(message(speed: -1, age: 30.1), looking)
    }

    func testAnOldSpeedIsNoLocation() {
        XCTAssertEqual(message(speed: 10, age: 30.1), looking)
    }

    func testNoReadingYetIsStillLooking() {
        XCTAssertEqual(LocationAccess.precise.message(for: .unknown, at: now), looking)
    }

    func testTheUnitPlaysNoPartInTheMessage() {
        // A pace has no label at a standstill, yet the app does have a speed there.
        let reading = SpeedReading(rawSpeed: 0, measuredAt: now)
        XCTAssertEqual(reading.label(in: .minutesPerKilometer, at: now), "--")
        XCTAssertEqual(LocationAccess.precise.message(for: reading, at: now), locationAndSpeed)
    }
}

import XCTest
@testable import SpeedTrack

final class SpeedReadingTests: XCTestCase {
    func testNegativeSpeedMeansUnknown() {
        let reading = SpeedReading(rawSpeed: -1)
        XCTAssertNil(reading.kilometersPerHour)
        XCTAssertEqual(reading.label, "--")
    }

    func testZeroIsAValidSpeed() {
        let reading = SpeedReading(rawSpeed: 0)
        XCTAssertEqual(reading.kilometersPerHour, 0)
        XCTAssertEqual(reading.label, "0")
    }

    func testMetersPerSecondBecomeKilometersPerHour() {
        let reading = SpeedReading(rawSpeed: 10)
        XCTAssertEqual(reading.kilometersPerHour ?? 0, 36, accuracy: 0.001)
        XCTAssertEqual(reading.label, "36")
    }
}

import XCTest
@testable import SpeedTrack

final class StillnessDetectorTests: XCTestCase {
    private let start = Date(timeIntervalSinceReferenceDate: 1_000)

    private func time(_ seconds: TimeInterval) -> Date {
        start.addingTimeInterval(seconds)
    }

    func testNothingRecordedIsNotStill() {
        XCTAssertFalse(StillnessDetector().isStill(at: start))
    }

    func testStillOnlyAfterTheHoldTime() {
        var detector = StillnessDetector()
        detector.record(x: 0, y: 0, z: 0, at: start)
        detector.record(x: 0.01, y: 0, z: 0, at: time(1))
        XCTAssertFalse(detector.isStill(at: time(1.9)))
        XCTAssertTrue(detector.isStill(at: time(2)))
    }

    func testMovementRestartsTheHoldTime() {
        var detector = StillnessDetector()
        detector.record(x: 0, y: 0, z: 0, at: start)
        detector.record(x: 0, y: 0.5, z: 0, at: time(1))
        detector.record(x: 0, y: 0, z: 0, at: time(1.1))
        XCTAssertFalse(detector.isStill(at: time(2.5)))
        XCTAssertTrue(detector.isStill(at: time(3.1)))
    }

    func testMovementCountsAcrossAllThreeAxes() {
        var detector = StillnessDetector()
        detector.record(x: 0, y: 0, z: 0, at: start)
        detector.record(x: 0.02, y: 0.02, z: 0.02, at: time(1))
        XCTAssertFalse(detector.isStill(at: time(2.5)))
    }
}

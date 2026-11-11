import XCTest
@testable import SpeedTrack

final class MapZoomLevelTests: XCTestCase {
    func testAZoomLevelShowsTheSpanAcrossTheView() {
        // At zoom 0 MapLibre draws the equator 512 points long.
        XCTAssertEqual(MapZoom.zoomLevel(span: 40_075_016.686, latitude: 0, points: 512), 0, accuracy: 1e-9)
        // Half the span is one level closer, and so is twice the width.
        XCTAssertEqual(MapZoom.zoomLevel(span: 20_037_508.343, latitude: 0, points: 512), 1, accuracy: 1e-9)
        XCTAssertEqual(MapZoom.zoomLevel(span: 40_075_016.686, latitude: 0, points: 1_024), 1, accuracy: 1e-9)
        // At 60 degrees a degree of longitude is half as long, so the same span is one level further out.
        XCTAssertEqual(MapZoom.zoomLevel(span: 20_037_508.343, latitude: 60, points: 512), 0, accuracy: 1e-9)
        // A phone's map 350 points wide, showing 4 km.
        XCTAssertEqual(MapZoom.zoomLevel(span: 4_000, latitude: 38.7, points: 350), 12.38, accuracy: 0.01)
    }
}

final class MapZoomTests: XCTestCase {
    private func span(
        _ kilometersPerHour: Double?,
        accuracy: Double = 5,
        offline: Bool = false,
        after zoom: inout MapZoom
    ) -> Double {
        zoom.span(speed: kilometersPerHour.map { $0 / 3.6 }, accuracy: accuracy, offline: offline)
    }

    private func firstSpan(_ kilometersPerHour: Double?, accuracy: Double = 5, offline: Bool = false) -> Double {
        var zoom = MapZoom()
        return span(kilometersPerHour, accuracy: accuracy, offline: offline, after: &zoom)
    }

    func testTheMapShowsAboutTwoMinutesOfTravel() {
        XCTAssertEqual(firstSpan(0), 1_000)
        XCTAssertEqual(firstSpan(5), 1_000)
        XCTAssertEqual(firstSpan(100), 4_000)
        XCTAssertEqual(firstSpan(300), 16_000)
        XCTAssertEqual(firstSpan(900), 32_000)
    }

    func testTheSpanHasALimit() {
        XCTAssertEqual(firstSpan(10_000), 128_000)
    }

    func testTheMapZoomsOutAtOnceAndBackInOnlyWhenClearlySlower() {
        var zoom = MapZoom()
        XCTAssertEqual(span(200, after: &zoom), 8_000)
        // 110 km/h asks for 3.7 km, which is too close to the step of 4 km to leave 8 km.
        XCTAssertEqual(span(110, after: &zoom), 8_000)
        XCTAssertEqual(span(90, after: &zoom), 4_000)
        XCTAssertEqual(span(130, after: &zoom), 8_000)
    }

    func testAnUnknownSpeedKeepsTheSpan() {
        var zoom = MapZoom()
        XCTAssertEqual(span(300, after: &zoom), 16_000)
        XCTAssertEqual(span(nil, after: &zoom), 16_000)
    }

    func testWithoutInternetTheMapShowsTheOverview() {
        var zoom = MapZoom()
        XCTAssertEqual(span(100, offline: true, after: &zoom), 64_000)
        XCTAssertEqual(span(100, after: &zoom), 4_000)
        XCTAssertEqual(firstSpan(10_000, offline: true), 128_000)
    }

    func testAnApproximateLocationFitsOnTheMap() {
        XCTAssertEqual(firstSpan(nil, accuracy: 5_000), 20_000)
        XCTAssertEqual(firstSpan(0, accuracy: 65), 1_000)
    }
}

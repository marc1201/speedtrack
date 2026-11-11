import XCTest
@testable import SpeedTrack

final class OverviewMapTests: XCTestCase {
    private typealias Point = (latitude: Int32, longitude: Int32)

    /// Writes the file format of tools/build-overview-map.py, for small hand-made maps.
    private func file(
        lines: [(kind: UInt8, points: [Point])] = [],
        places: [(rank: UInt8, point: Point, name: String)] = [],
        countries: [(first: UInt8, last: UInt8, point: Point, name: String)] = [],
        magic: String = "SPOM",
        version: UInt8 = 2
    ) -> [UInt8] {
        var bytes = Array(magic.utf8) + [version]
        func add<T: FixedWidthInteger>(_ value: T) {
            withUnsafeBytes(of: value.littleEndian) { bytes += $0 }
        }
        add(UInt32(lines.count))
        for line in lines {
            add(line.kind)
            add(UInt16(line.points.count))
            add(line.points[0].latitude)
            add(line.points[0].longitude)
            for (previous, point) in zip(line.points, line.points.dropFirst()) {
                add(Int16(point.latitude - previous.latitude))
                add(Int16(point.longitude - previous.longitude))
            }
        }
        add(UInt32(places.count))
        for place in places {
            add(place.rank)
            add(place.point.latitude)
            add(place.point.longitude)
            add(UInt8(place.name.utf8.count))
            bytes += Array(place.name.utf8)
        }
        add(UInt32(countries.count))
        for country in countries {
            add(country.first)
            add(country.last)
            add(country.point.latitude)
            add(country.point.longitude)
            add(UInt8(country.name.utf8.count))
            bytes += Array(country.name.utf8)
        }
        return bytes
    }

    private func map(_ bytes: [UInt8]) throws -> OverviewMap {
        try OverviewMap(data: Data(bytes))
    }

    /// A box of `span` degrees around a point.
    private func box(_ latitude: Double, _ longitude: Double, span: Double) -> GeoBox {
        .around(GeoPoint(latitude: latitude, longitude: longitude), latitudeSpan: span, longitudeSpan: span)
    }

    func testReadsLinesAndPlaces() throws {
        let overview = try map(file(
            lines: [(kind: 4, points: [(387_000, -91_000), (387_100, -91_250), (386_900, -91_000)])],
            places: [(rank: 7, point: (385_667, -79_000), name: "Évora")],
            countries: [(first: 30, last: 80, point: (396_067, -82_718), name: "Portugal")]
        ))
        XCTAssertEqual(overview.lines.count, 1)
        XCTAssertEqual(overview.lines[0].kind, .railway)
        XCTAssertEqual(overview.lines[0].points, [
            GeoPoint(latitude: 38.7, longitude: -9.1),
            GeoPoint(latitude: 38.71, longitude: -9.125),
            GeoPoint(latitude: 38.69, longitude: -9.1),
        ])
        XCTAssertEqual(overview.lines[0].bounds, GeoBox(south: 38.69, north: 38.71, west: -9.125, east: -9.1))
        XCTAssertEqual(overview.places.count, 1)
        XCTAssertEqual(overview.places[0].name, "Évora")
        XCTAssertEqual(overview.places[0].rank, 7)
        XCTAssertEqual(overview.places[0].point, GeoPoint(latitude: 38.5667, longitude: -7.9))
        XCTAssertEqual(overview.countryNames.count, 1)
        XCTAssertEqual(overview.countryNames[0].name, "Portugal")
        XCTAssertEqual(overview.countryNames[0].point, GeoPoint(latitude: 39.6067, longitude: -8.2718))
        XCTAssertEqual(overview.countryNames[0].zooms, 3...8)
    }

    func testRejectsADamagedFile() {
        let line: (kind: UInt8, points: [Point]) = (kind: 1, points: [(0, 0), (10, 10)])
        let good = file(lines: [line])
        XCTAssertNoThrow(try map(good))
        XCTAssertThrowsError(try map(file(lines: [line], magic: "XXXX")))
        XCTAssertThrowsError(try map(file(lines: [line], version: 1)))
        XCTAssertThrowsError(try map(Array(good.dropLast())))
        XCTAssertThrowsError(try map(good + [0]))
        XCTAssertThrowsError(try map(file(lines: [(kind: 9, points: line.points)])))
        XCTAssertThrowsError(try map(file(lines: [(kind: 1, points: [(0, 0)])])))
        XCTAssertThrowsError(try map(file(lines: [(kind: 1, points: [(900_001, 0), (900_002, 0)])])))
        XCTAssertThrowsError(try map(file(places: [(rank: 0, point: (0, 1_800_001), name: "Nowhere")])))
        XCTAssertThrowsError(try map(file(countries: [(first: 70, last: 17, point: (0, 0), name: "Backwards")])))
        XCTAssertThrowsError(try map(file(countries: [(first: 17, last: 70, point: (900_001, 0), name: "Nowhere")])))
    }

    func testFindsTheLinesInView() throws {
        let overview = try map(file(lines: [
            (kind: 1, points: [(387_000, -94_000), (388_000, -94_200)]),
            (kind: 5, points: [(387_000, -91_000), (388_000, -90_000)]),
            (kind: 4, points: [(356_800, 1_397_600), (356_900, 1_397_700)]),
        ]))
        XCTAssertEqual(overview.lines(in: box(38.7, -9.1, span: 1)).map(\.id), [0, 1])
        // A view too wide to read roads and railways keeps only the coastline.
        XCTAssertEqual(overview.lines(in: box(38.7, -9.1, span: 10)).map(\.id), [0])
        XCTAssertEqual(overview.lines(in: box(35.68, 139.77, span: 1)).map(\.id), [2])
    }

    func testAKindThatDoesNotFitIsLeftOutWithTheKindsAfterIt() throws {
        let points: [Point] = [(0, 0), (100, 100)]
        let coastline: (kind: UInt8, points: [Point]) = (kind: 1, points: points)
        let border: (kind: UInt8, points: [Point]) = (kind: 2, points: points)
        let lake: (kind: UInt8, points: [Point]) = (kind: 3, points: points)
        let view = box(0, 0, span: 1)
        let fitting = [coastline] + Array(repeating: border, count: OverviewMap.lineLimit - 2) + [lake]
        XCTAssertEqual(try map(file(lines: fitting)).lines(in: view).count, OverviewMap.lineLimit)
        let tooMany = [coastline] + Array(repeating: border, count: OverviewMap.lineLimit) + [lake]
        XCTAssertEqual(try map(file(lines: tooMany)).lines(in: view).map(\.kind), [.coastline])
        // MapLibre sets no limit, and gets them all.
        XCTAssertEqual(try map(file(lines: tooMany)).lines(in: view, limit: .max).count, tooMany.count)
    }

    func testLeavesOutLinesTooSmallToSee() throws {
        // In a view 40 degrees across, a line under a tenth of a degree both ways is under a point.
        let overview = try map(file(lines: [
            (kind: 1, points: [(0, 0), (900, 900)]),
            (kind: 1, points: [(0, 0), (1_100, 1_100)]),
            // A border running north is narrow, but tall enough to see.
            (kind: 2, points: [(0, 0), (20_000, 100)]),
        ]))
        XCTAssertEqual(overview.lines(in: box(0, 0, span: 40)).map(\.id), [1, 2])
        XCTAssertEqual(overview.lines(in: box(0, 0, span: 4)).map(\.id), [0, 1, 2])
    }

    func testNamesTheMostImportantPlacesInView() throws {
        let overview = try map(file(places: [
            (rank: 0, point: (356_895, 1_396_917), name: "Tokyo"),
            (rank: 2, point: (387_223, -91_393), name: "Lisbon"),
            (rank: 7, point: (385_667, -79_000), name: "Évora"),
            (rank: 10, point: (387_436, -86_428), name: "Montijo"),
        ]))
        let names = overview.places(in: box(38.5, -8.5, span: 2), limit: 2).map(\.name)
        XCTAssertEqual(names, ["Lisbon", "Évora"])
    }

    func testNamesCountriesOnlyWhenZoomedOutFarEnough() throws {
        let overview = try map(file(countries: [
            (first: 17, last: 70, point: (361_425, 1_384_422), name: "Japan"),
            (first: 57, last: 100, point: (497_337, 60_776), name: "Luxembourg"),
        ]))
        let world = GeoBox.around(GeoPoint(latitude: 0, longitude: 0), latitudeSpan: 180, longitudeSpan: 360)
        // Two levels further out than Natural Earth says: Japan from the whole world on.
        XCTAssertEqual(overview.countryNames(in: world, zoom: 0).map(\.name), ["Japan"])
        XCTAssertEqual(overview.countryNames(in: world, zoom: 4).map(\.name), ["Japan", "Luxembourg"])
        XCTAssertEqual(overview.countryNames(in: box(36, 138, span: 20), zoom: 4).map(\.name), ["Japan"])
        // Closer in than zoom 5 none, though Natural Earth names Luxembourg to its zoom 10: while
        // the map follows, the name would cover the towns.
        XCTAssertEqual(overview.countryNames(in: world, zoom: 5.5).map(\.name), [])
        let following = MapZoom.zoomLevel(span: MapZoom.offlineSpan, latitude: 49.6, points: 230)
        XCTAssertEqual(overview.countryNames(in: world, zoom: following).map(\.name), [])
    }

    func testABoxCanCrossTheDateLine() {
        let view = box(0, 179.5, span: 2)
        XCTAssertEqual(view, GeoBox(south: -1, north: 1, west: 178.5, east: -179.5))
        XCTAssertEqual(view.longitudeSpan, 2, accuracy: 1e-9)
        XCTAssertTrue(view.contains(GeoPoint(latitude: 0, longitude: -179.8)))
        XCTAssertTrue(view.contains(GeoPoint(latitude: 0, longitude: 179)))
        XCTAssertFalse(view.contains(GeoPoint(latitude: 0, longitude: -179)))
        XCTAssertTrue(view.intersects(GeoBox(south: 0, north: 0.5, west: -179.9, east: -179.6)))
        XCTAssertFalse(view.intersects(GeoBox(south: 0, north: 0.5, west: -179, east: -177)))
    }

    func testABoxStopsAtThePolesAndCanCoverTheWorld() {
        XCTAssertEqual(box(89.5, 0, span: 2).north, 90)
        let world = GeoBox.around(GeoPoint(latitude: 0, longitude: 10), latitudeSpan: 10, longitudeSpan: 400)
        XCTAssertEqual(world.west, -180)
        XCTAssertEqual(world.east, 180)
        XCTAssertEqual(world.longitudeSpan, 360)
    }

    #if os(iOS)
    /// The real file, in the app the tests run in. The Linux check has no app bundle.
    func testTheBundledMapReads() {
        let overview = OverviewMap.bundled
        XCTAssertGreaterThan(overview.lines.count, 20_000)
        XCTAssertGreaterThan(overview.places.count, 7_000)
        let lisbon = box(38.72, -9.14, span: 0.6)
        XCTAssertTrue(overview.lines(in: lisbon).contains { $0.kind == .coastline })
        XCTAssertTrue(overview.places(in: lisbon, limit: 12).contains { $0.name == "Lisbon" })
        XCTAssertGreaterThan(overview.countryNames.count, 200)
        let world = GeoBox.around(GeoPoint(latitude: 0, longitude: 0), latitudeSpan: 180, longitudeSpan: 360)
        XCTAssertTrue(overview.countryNames(in: world, zoom: 0).contains { $0.name == "Japan" })
    }

    /// While the map follows, at its widest on the shortest map, no country's name shows.
    func testNoCountryIsNamedWhileTheMapFollows() {
        let overview = OverviewMap.bundled
        for country in overview.countryNames where abs(country.point.latitude) < 80 {
            let zoom = MapZoom.zoomLevel(span: MapZoom.offlineSpan, latitude: country.point.latitude, points: 160)
            let view = GeoBox.around(country.point, latitudeSpan: 1, longitudeSpan: 1)
            XCTAssertEqual(overview.countryNames(in: view, zoom: zoom).map(\.name), [], country.name)
        }
    }

    /// Zoomed out over East Asia or the world, the coastlines once had so many islands in view
    /// that the limit left out every line.
    func testAWideViewKeepsItsCoastlines() {
        let overview = OverviewMap.bundled
        let eastAsia = GeoBox.around(GeoPoint(latitude: 24, longitude: 118), latitudeSpan: 67, longitudeSpan: 97)
        XCTAssertTrue(overview.lines(in: eastAsia).contains { $0.kind == .coastline })
        let world = GeoBox.around(GeoPoint(latitude: 10, longitude: 160), latitudeSpan: 170, longitudeSpan: 400)
        XCTAssertTrue(overview.lines(in: world, limit: .max).contains { $0.kind == .coastline })
    }
    #endif
}

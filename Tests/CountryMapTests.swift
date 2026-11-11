import XCTest
@testable import SpeedTrack

final class CountryMapTests: XCTestCase {
    private let hash = String(repeating: "ab", count: 32)

    private func list(_ entries: [[String: Any]]) throws -> [CountryMap] {
        try CountryMap.list(from: JSONSerialization.data(withJSONObject: ["files": entries]))
    }

    private func entry(name: String = "pt-z12-20261110.pmtiles", bytes: Int = 90_611_760, sha256: String? = nil) -> [String: Any] {
        // Keys the app does not read, such as those the map server may add, are ignored.
        ["name": name, "bytes": bytes, "sha256": sha256 ?? hash, "title": "Portugal", "note": "ignored"]
    }

    func testReadsTheList() throws {
        let maps = try list([entry()])
        XCTAssertEqual(maps.count, 1)
        XCTAssertEqual(maps[0].title, "Portugal")
        XCTAssertEqual(maps[0].bytes, 90_611_760)
        XCTAssertEqual(maps[0].url.absoluteString, "https://maps.1201.de/pt-z12-20261110.pmtiles")
    }

    func testRefusesANameThatCouldLeaveTheMapsDirectory() {
        for name in ["../pt.pmtiles", "maps/pt.pmtiles", "pt.zip", "-pt.pmtiles", "PT.pmtiles", ".pmtiles"] {
            XCTAssertThrowsError(try list([entry(name: name)]), name)
        }
    }

    func testRefusesASizeOrHashThatCannotBeRight() {
        XCTAssertThrowsError(try list([entry(bytes: 0)]))
        XCTAssertThrowsError(try list([entry(sha256: String(hash.dropLast()))]))
        XCTAssertThrowsError(try list([entry(sha256: hash.uppercased())]))
        XCTAssertThrowsError(try list([entry(), entry()]))
    }

    func testReadsWhenAPausedServerResumes() {
        let now = Date(timeIntervalSince1970: 1_000)
        XCTAssertEqual(CountryMap.resumption(retryAfter: "3600", now: now), Date(timeIntervalSince1970: 4_600))
        XCTAssertEqual(CountryMap.resumption(retryAfter: " 30 ", now: now), Date(timeIntervalSince1970: 1_030))
        XCTAssertNil(CountryMap.resumption(retryAfter: nil, now: now))
        XCTAssertNil(CountryMap.resumption(retryAfter: "Wed, 12 Nov 2026 00:00:00 GMT", now: now))
        XCTAssertNil(CountryMap.resumption(retryAfter: "-5", now: now))
    }

    #if os(iOS)
    /// The list in the app, which the map server also publishes from.
    func testTheBundledListOffersTheFourCountries() {
        XCTAssertEqual(CountryMap.all.map(\.title), ["Japan", "South Korea", "Portugal", "Germany"])
    }
    #endif
}

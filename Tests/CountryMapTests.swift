import XCTest
@testable import SpeedTrack

final class CountryMapTests: XCTestCase {
    private let digest = String(repeating: "ab", count: 32)

    private func list(_ entries: [[String: Any]]) throws -> [CountryMap] {
        try CountryMap.list(from: JSONSerialization.data(withJSONObject: ["files": entries]))
    }

    private func entry(name: String = "pt-z12-20261110.pmtiles", bytes: Int = 90_611_760, sha256: String? = nil) -> [String: Any] {
        // Keys the app does not read, such as those the map server may add, are ignored.
        ["name": name, "bytes": bytes, "sha256": sha256 ?? digest, "title": "Portugal", "note": "ignored"]
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
        XCTAssertThrowsError(try list([entry(sha256: String(digest.dropLast()))]))
        XCTAssertThrowsError(try list([entry(sha256: digest.uppercased())]))
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

    func testTheServersAnswerDecidesWhatHappensToThePartialFile() throws {
        let map = try XCTUnwrap(list([entry()]).first)
        let now = Date(timeIntervalSince1970: 1_000)
        func answer(_ status: Int, range: String? = nil, retryAfter: String? = nil, offset: Int64 = 0) -> CountryMap.Answer {
            map.answer(status: status, contentRange: range, retryAfter: retryAfter, offset: offset, now: now)
        }
        XCTAssertEqual(answer(200), .restart)
        // A server that ignores the range sends the whole file again.
        XCTAssertEqual(answer(200, offset: 500), .restart)
        XCTAssertEqual(answer(206, range: "bytes 500-90611759/90611760", offset: 500), .append)
        XCTAssertEqual(answer(206, range: "bytes 0-90611759/90611760", offset: 500),
                       .refused("The map server sent the wrong part. Try again later.", discardPart: false))
        XCTAssertEqual(answer(416, offset: 90_611_760), .complete)
        XCTAssertEqual(answer(416, offset: 90_611_761),
                       .refused("The download did not fit the map. Download again.", discardPart: true))
        XCTAssertEqual(answer(503, retryAfter: "60"), .paused(until: Date(timeIntervalSince1970: 1_060)))
        XCTAssertEqual(answer(503), .refused("The map server is busy. Try again later.", discardPart: false))
        XCTAssertEqual(answer(404), .refused("This map is not on the map server yet.", discardPart: false))
        XCTAssertEqual(answer(500, offset: 500), .refused("The map server answered 500.", discardPart: false))
    }

    #if os(iOS)
    /// A download becomes the map only once its size and SHA-256 match the list.
    func testADownloadIsUsedOnlyWhenItsSizeAndHashMatch() throws {
        let map = CountryMap(
            name: "test-z0-00000000.pmtiles",
            bytes: 3,
            sha256: "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
            title: "Test"
        )
        let part = CountryMapStore.part(for: map)
        let file = CountryMapStore.file(for: map)
        defer {
            try? FileManager.default.removeItem(at: part)
            try? FileManager.default.removeItem(at: file)
        }
        try Data("ab".utf8).write(to: part)
        XCTAssertEqual(CountryMapStore.finish(map), .failed(CountryMapStore.stoppedMessage))
        XCTAssertTrue(FileManager.default.fileExists(atPath: part.path), "a short file is kept for the rest")
        try Data("abd".utf8).write(to: part)
        XCTAssertEqual(CountryMapStore.finish(map), .failed("The download was damaged. Download again."))
        XCTAssertFalse(FileManager.default.fileExists(atPath: part.path))
        try Data("abcd".utf8).write(to: part)
        XCTAssertEqual(CountryMapStore.finish(map), .failed("The download was damaged. Download again."))
        try Data("abc".utf8).write(to: part)
        XCTAssertEqual(CountryMapStore.finish(map), .ready)
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: part.path))
    }

    /// The list in the app, which the map server also publishes from.
    func testTheBundledListOffersTheFourCountries() {
        XCTAssertEqual(CountryMap.all.map(\.title), ["Japan", "South Korea", "Portugal", "Germany"])
    }
    #endif
}

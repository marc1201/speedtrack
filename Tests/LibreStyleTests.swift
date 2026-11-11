import XCTest
@testable import SpeedTrack

final class LibreStyleTests: XCTestCase {
    private let glyphs = "file:///app/NotoSans-{range}.pbf"
    private let japan = URL(fileURLWithPath: "/data/Library/Maps/jp-z12-20261110.pmtiles")
    private let korea = URL(fileURLWithPath: "/data/Library/Maps/kr-z12-20261110.pmtiles")

    private func layers(_ style: [String: Any]) -> [[String: Any]] {
        style["layers"] as? [[String: Any]] ?? []
    }

    private func sources(_ style: [String: Any]) -> [String: [String: Any]] {
        style["sources"] as? [String: [String: Any]] ?? [:]
    }

    func testEveryLayerHasAUniqueIdAndAKnownSource() {
        let style = LibreStyle.json(glyphs: glyphs, countries: [japan, korea])
        XCTAssertTrue(JSONSerialization.isValidJSONObject(style))
        let ids = layers(style).compactMap { $0["id"] as? String }
        XCTAssertEqual(ids.count, layers(style).count)
        XCTAssertEqual(Set(ids).count, ids.count)
        for layer in layers(style) where layer["type"] as? String != "background" {
            XCTAssertNotNil(sources(style)[layer["source"] as? String ?? ""], "\(layer["id"] ?? "")")
        }
    }

    func testTheOutlinesAloneNeedNoFile() {
        let style = LibreStyle.json(glyphs: glyphs, countries: [])
        XCTAssertEqual(Set(sources(style).keys), [
            LibreStyle.outlineSource, LibreStyle.outlinePlaceSource, LibreStyle.outlineCountrySource,
            LibreStyle.positionSource,
        ])
        XCTAssertEqual(style["glyphs"] as? String, glyphs)
    }

    func testEachCountryReadsItsDownloadedFile() {
        let style = LibreStyle.json(glyphs: glyphs, countries: [japan, korea])
        XCTAssertEqual(sources(style)["jp-z12-20261110"]?["url"] as? String,
                       "pmtiles://file:///data/Library/Maps/jp-z12-20261110.pmtiles")
        XCTAssertEqual(sources(style)["kr-z12-20261110"]?["url"] as? String,
                       "pmtiles://file:///data/Library/Maps/kr-z12-20261110.pmtiles")
        // Nothing is fetched from the internet.
        let urls = sources(style).values.compactMap { $0["url"] as? String }
        XCTAssertTrue(urls.allSatisfy { $0.hasPrefix("pmtiles://file://") })
    }

    func testTheOutlinesLieUnderTheCountriesAndThePositionOnTop() {
        let ids = layers(LibreStyle.json(glyphs: glyphs, countries: [japan])).compactMap { $0["id"] as? String }
        let outlines = ids.firstIndex(of: "outline-water") ?? .max
        let land = ids.firstIndex(of: "jp-z12-20261110-earth") ?? .min
        XCTAssertLessThan(outlines, land)
        XCTAssertEqual(ids.last, "position")
        // MapLibre places the upper layer's names first, so a country's name wins over a place's.
        XCTAssertLessThan(ids.firstIndex(of: "outline-places") ?? .max, ids.firstIndex(of: "outline-countries") ?? .min)
    }
}

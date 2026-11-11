import Foundation

/// The MapLibre style of the outlines and OpenStreetMap maps, as JSON. Everything it names is on the
/// phone: the outlines come from the app, the countries from their downloaded files, and the label
/// font from the app's glyph files. So MapLibre never goes online. The countries use the layers of
/// Protomaps' basemap, version 4: https://docs.protomaps.com/basemaps/layers
enum LibreStyle {
    /// Sources the map fills in itself: the outlines in view, their places and country names, and
    /// the position.
    static let outlineSource = "outlines"
    static let outlinePlaceSource = "outline-places"
    static let outlineCountrySource = "outline-countries"
    static let positionSource = "position"

    private static let font = ["Noto Sans Regular"]
    private static let land = "#f4f1ea"
    private static let water = "#a7cdf2"
    private static let green = "#d6ebc8"

    /// - Parameters:
    ///   - glyphs: where the label font is, with `{range}` in place of each file's range.
    ///   - countries: the downloaded files, drawn over the outlines, which they cover.
    static func json(glyphs: String, countries: [URL]) -> [String: Any] {
        var sources: [String: Any] = [
            outlineSource: emptySource,
            outlinePlaceSource: emptySource,
            outlineCountrySource: emptySource,
            positionSource: emptySource,
        ]
        var layers: [[String: Any]] = [
            ["id": "background", "type": "background", "paint": ["background-color": land]],
        ]
        layers += outlineLayers()
        var places: [[String: Any]] = []
        for file in countries {
            let source = file.deletingPathExtension().lastPathComponent
            // MapLibre takes the credit from the file, which says "© OpenStreetMap".
            sources[source] = ["type": "vector", "url": "pmtiles://" + file.absoluteString]
            layers += countryLayers(source)
            places.append(countryPlaces(source))
        }
        // Names come last, so no country's land covers another's names.
        layers += places
        layers.append([
            "id": "position", "type": "circle", "source": positionSource,
            "paint": [
                "circle-radius": 7, "circle-color": "#0a84ff",
                "circle-stroke-width": 2.5, "circle-stroke-color": "#ffffff",
            ],
        ])
        return ["version": 8, "glyphs": glyphs, "sources": sources, "layers": layers]
    }

    private static let emptySource: [String: Any] = [
        "type": "geojson", "data": ["type": "FeatureCollection", "features": [Any]()],
    ]

    /// The built-in outlines. Under a country's land they are covered, so they show only where no
    /// country is downloaded. Their `kind` is `OverviewMap.Kind`'s raw value.
    private static func outlineLayers() -> [[String: Any]] {
        func line(_ id: String, kinds: [Int], color: String, width: Double, dash: [Double]? = nil) -> [String: Any] {
            var paint: [String: Any] = ["line-color": color, "line-width": width]
            paint["line-dasharray"] = dash
            return [
                "id": id, "type": "line", "source": outlineSource,
                "filter": ["match", ["get", "kind"], kinds, true, false],
                "paint": paint,
            ]
        }
        return [
            line("outline-water", kinds: [1, 3], color: "#2f7fd8", width: 1.5),
            line("outline-border", kinds: [2], color: "#8e7cc3", width: 1.5, dash: [4, 3]),
            line("outline-railway", kinds: [4], color: "#8c6d4f", width: 1.5, dash: [1.5, 2]),
            line("outline-road", kinds: [5], color: "#e8924a", width: 1.8),
            [
                "id": "outline-places", "type": "symbol", "source": outlinePlaceSource,
                "layout": ["text-field": ["get", "name"], "text-font": font, "text-size": 12, "text-max-width": 8],
                "paint": ["text-color": "#333333", "text-halo-color": "#ffffff", "text-halo-width": 1.5],
            ],
            // Above the places, because MapLibre places the upper layer's names first: where a
            // country's name and a place's do not both fit, the country's shows. `order` is 0 for the
            // most important country.
            [
                "id": "outline-countries", "type": "symbol", "source": outlineCountrySource,
                "layout": [
                    "text-field": ["get", "name"], "text-font": font, "text-size": 11,
                    "text-transform": "uppercase", "text-letter-spacing": 0.1, "text-max-width": 7,
                    "symbol-sort-key": ["get", "order"],
                ],
                "paint": ["text-color": "#6a5a99", "text-halo-color": "#ffffff", "text-halo-width": 1.5],
            ],
        ]
    }

    private static func countryLayers(_ source: String) -> [[String: Any]] {
        func layer(_ name: String, _ type: String, from sourceLayer: String, filter: [Any]? = nil,
                   minzoom: Double? = nil, paint: [String: Any]) -> [String: Any] {
            var layer: [String: Any] = [
                "id": "\(source)-\(name)", "type": type, "source": source, "source-layer": sourceLayer, "paint": paint,
            ]
            layer["filter"] = filter
            layer["minzoom"] = minzoom
            return layer
        }
        func kind(_ kinds: [String]) -> [Any] {
            ["match", ["get", "kind"], kinds, true, false]
        }
        func width(_ stops: [Double]) -> [Any] {
            ["interpolate", ["exponential", 1.6], ["zoom"]] + stops
        }
        let polygon: [Any] = ["==", ["geometry-type"], "Polygon"]
        let line: [Any] = ["==", ["geometry-type"], "LineString"]
        return [
            layer("earth", "fill", from: "earth", filter: polygon, paint: ["fill-color": land]),
            layer("landcover", "fill", from: "landcover", filter: kind(["forest", "grassland", "scrub"]),
                  paint: ["fill-color": green, "fill-opacity": 0.6]),
            layer("green", "fill", from: "landuse", filter: kind([
                "park", "forest", "wood", "nature_reserve", "grass", "grassland", "meadow", "scrub",
                "garden", "golf_course", "cemetery", "village_green", "allotments", "recreation_ground",
            ]), paint: ["fill-color": green]),
            layer("sand", "fill", from: "landuse", filter: kind(["sand", "beach"]), paint: ["fill-color": "#f5e9c6"]),
            layer("water", "fill", from: "water", filter: polygon, paint: ["fill-color": water]),
            layer("rivers", "line", from: "water", filter: line, paint: ["line-color": water, "line-width": 1.2]),
            layer("buildings", "fill", from: "buildings", minzoom: 13, paint: ["fill-color": "#e0dad0"]),
            layer("regions", "line", from: "boundaries", filter: kind(["region"]),
                  paint: ["line-color": "#b9add6", "line-width": 0.8, "line-dasharray": [3, 2]]),
            layer("countries", "line", from: "boundaries", filter: kind(["country"]),
                  paint: ["line-color": "#8e7cc3", "line-width": 1.5, "line-dasharray": [3, 2]]),
            layer("paths", "line", from: "roads", filter: kind(["path"]), minzoom: 13,
                  paint: ["line-color": "#c9bfae", "line-width": 0.8, "line-dasharray": [2, 1.5]]),
            layer("minor-roads", "line", from: "roads", filter: kind(["minor_road", "other"]),
                  paint: ["line-color": "#d2c9ba", "line-width": width([11, 0.6, 16, 6])]),
            layer("railways", "line", from: "roads", filter: kind(["rail"]),
                  paint: ["line-color": "#8c8c8c", "line-width": 1.2, "line-dasharray": [3, 2]]),
            layer("ferries", "line", from: "roads", filter: kind(["ferry"]),
                  paint: ["line-color": "#5b9bd5", "line-width": 1, "line-dasharray": [3, 3]]),
            layer("major-roads", "line", from: "roads", filter: kind(["major_road"]),
                  paint: ["line-color": "#f2c661", "line-width": width([7, 0.6, 12, 2, 16, 10])]),
            layer("highways", "line", from: "roads", filter: kind(["highway"]),
                  paint: ["line-color": "#e8924a", "line-width": width([5, 0.6, 12, 3, 16, 14])]),
        ]
    }

    /// Countries, regions and towns, the largest placed first. English names where OpenStreetMap
    /// has them, the local name otherwise.
    private static func countryPlaces(_ source: String) -> [String: Any] {
        [
            "id": "\(source)-places", "type": "symbol", "source": source, "source-layer": "places",
            "filter": ["match", ["get", "kind"], ["country", "region", "locality"], true, false],
            "layout": [
                "text-field": ["coalesce", ["get", "name:en"], ["get", "name"]],
                "text-font": font,
                "text-size": ["interpolate", ["linear"], ["coalesce", ["get", "population_rank"], 0], 0, 11, 15, 16],
                "text-max-width": 8,
                "symbol-sort-key": ["-", 0, ["coalesce", ["get", "population_rank"], 0]],
            ],
            "paint": ["text-color": "#333333", "text-halo-color": "#ffffff", "text-halo-width": 1.5],
        ]
    }
}

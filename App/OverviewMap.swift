import Foundation

/// A point on the Earth in degrees. The map logic uses it instead of CoreLocation's type, so it
/// builds and is tested where CoreLocation does not exist.
struct GeoPoint: Equatable {
    let latitude: Double
    let longitude: Double
}

/// A range of latitude and longitude. It crosses the 180° meridian when `west` is greater than
/// `east`. The lines of the overview map never do, because Natural Earth splits them there.
struct GeoBox: Equatable {
    let south: Double
    let north: Double
    let west: Double
    let east: Double

    /// The box around a center. A box as wide as the world covers every longitude.
    static func around(_ center: GeoPoint, latitudeSpan: Double, longitudeSpan: Double) -> GeoBox {
        let south = max(center.latitude - latitudeSpan / 2, -90)
        let north = min(center.latitude + latitudeSpan / 2, 90)
        guard longitudeSpan < 360 else { return GeoBox(south: south, north: north, west: -180, east: 180) }
        return GeoBox(
            south: south,
            north: north,
            west: normalized(center.longitude - longitudeSpan / 2),
            east: normalized(center.longitude + longitudeSpan / 2)
        )
    }

    /// The smallest box around points that do not cross the 180° meridian.
    static func enclosing(_ points: [GeoPoint]) -> GeoBox {
        GeoBox(
            south: points.map(\.latitude).min() ?? 0,
            north: points.map(\.latitude).max() ?? 0,
            west: points.map(\.longitude).min() ?? 0,
            east: points.map(\.longitude).max() ?? 0
        )
    }

    var latitudeSpan: Double { north - south }

    func contains(_ point: GeoPoint) -> Bool {
        south <= point.latitude && point.latitude <= north
            && longitudes.contains { $0.contains(point.longitude) }
    }

    func intersects(_ other: GeoBox) -> Bool {
        south <= other.north && other.south <= north
            && longitudes.contains { mine in other.longitudes.contains { mine.overlaps($0) } }
    }

    private var longitudes: [ClosedRange<Double>] {
        west <= east ? [west...east] : [west...180, -180...east]
    }

    private static func normalized(_ longitude: Double) -> Double {
        let turned = (longitude + 180).truncatingRemainder(dividingBy: 360)
        return (turned < 0 ? turned + 360 : turned) - 180
    }
}

/// The map the app draws when Apple's map has no internet: coastlines, borders, lakes, the larger
/// railways and roads, and places, from Natural Earth, which is in the public domain.
/// `tools/build-overview-map.py` makes the file and describes its format.
struct OverviewMap {
    /// In the order the file sorts lines, the most important first.
    enum Kind: UInt8, CaseIterable {
        case coastline = 1
        case border
        case lake
        case railway
        case road

        /// Too small to read and too many to draw in a wide view.
        var isDetail: Bool { self == .railway || self == .road }
    }

    struct Line: Identifiable {
        let id: Int
        let kind: Kind
        let points: [GeoPoint]
        let bounds: GeoBox
    }

    struct Place: Identifiable {
        let id: Int
        let name: String
        /// 0 for the most important.
        let rank: Int
        let point: GeoPoint
    }

    struct FormatError: Error {}

    /// Degrees of latitude above which a view leaves out railways and roads.
    static let detailLimit = 3.0
    /// The most lines drawn at once.
    static let lineLimit = 1_000
    /// A map has room for a few names only, so only the most important places get one.
    static let placeLimit = 12
    /// How much more than the screen a map asks for, so its lines are there before they scroll in.
    static let margin = 1.5
    static let empty = OverviewMap(lines: [], places: [])

    let lines: [Line]
    /// The most important first.
    let places: [Place]

    /// The lines in a view, whole kinds in order of importance. A kind that does not fit under the
    /// limit is left out, and so is every kind after it: a border drawn partway looks broken, and a
    /// lake without the coastline looks lost.
    func lines(in box: GeoBox) -> [Line] {
        let detailed = box.latitudeSpan <= Self.detailLimit
        let inView = lines.filter { (detailed || !$0.kind.isDetail) && $0.bounds.intersects(box) }
        var shown: [Line] = []
        for kind in Kind.allCases {
            let ofKind = inView.filter { $0.kind == kind }
            guard shown.count + ofKind.count <= Self.lineLimit else { break }
            shown += ofKind
        }
        return shown
    }

    func places(in box: GeoBox, limit: Int) -> [Place] {
        Array(places.lazy.filter { box.contains($0.point) }.prefix(limit))
    }
}

extension OverviewMap {
    /// The file in the app, read once. A missing or damaged file leaves the overview empty rather
    /// than stopping the app.
    static let bundled: OverviewMap = {
        guard let url = Bundle.main.url(forResource: "OverviewMap", withExtension: "dat"),
              let data = try? Data(contentsOf: url),
              let map = try? OverviewMap(data: data)
        else { return .empty }
        return map
    }()

    /// Reads the file format of `tools/build-overview-map.py`.
    init(data: Data) throws {
        var reader = ByteReader(bytes: [UInt8](data))
        let magic = try reader.take(4)
        let version = try reader.uint8()
        guard magic.elementsEqual("SPOM".utf8), version == 1 else { throw FormatError() }
        var lines: [Line] = []
        let lineCount = try reader.uint32()
        for id in 0..<Int(lineCount) {
            guard let kind = try Kind(rawValue: reader.uint8()) else { throw FormatError() }
            let count = try Int(reader.uint16())
            guard count >= 2 else { throw FormatError() }
            var latitude = try Int(reader.int32())
            var longitude = try Int(reader.int32())
            var points = try [Self.point(latitude, longitude)]
            for _ in 1..<count {
                latitude += try Int(reader.int16())
                longitude += try Int(reader.int16())
                try points.append(Self.point(latitude, longitude))
            }
            lines.append(Line(id: id, kind: kind, points: points, bounds: .enclosing(points)))
        }
        var places: [Place] = []
        let placeCount = try reader.uint32()
        for id in 0..<Int(placeCount) {
            let rank = try Int(reader.uint8())
            let latitude = try Int(reader.int32())
            let longitude = try Int(reader.int32())
            let length = try Int(reader.uint8())
            guard let name = try String(bytes: reader.take(length), encoding: .utf8) else { throw FormatError() }
            try places.append(Place(id: id, name: name, rank: rank, point: Self.point(latitude, longitude)))
        }
        guard reader.isAtEnd else { throw FormatError() }
        self.init(lines: lines, places: places)
    }

    /// The file counts in units of 1/10,000 degree.
    private static func point(_ latitude: Int, _ longitude: Int) throws -> GeoPoint {
        guard abs(latitude) <= 900_000, abs(longitude) <= 1_800_000 else { throw FormatError() }
        return GeoPoint(latitude: Double(latitude) / 10_000, longitude: Double(longitude) / 10_000)
    }
}

/// Reads little-endian integers, and throws rather than read past the end.
private struct ByteReader {
    let bytes: [UInt8]
    private var offset = 0

    init(bytes: [UInt8]) {
        self.bytes = bytes
    }

    var isAtEnd: Bool { offset == bytes.count }

    mutating func take(_ count: Int) throws -> ArraySlice<UInt8> {
        guard count <= bytes.count - offset else { throw OverviewMap.FormatError() }
        defer { offset += count }
        return bytes[offset..<offset + count]
    }

    mutating func uint8() throws -> UInt8 { try UInt8(unsigned(1)) }
    mutating func uint16() throws -> UInt16 { try UInt16(unsigned(2)) }
    mutating func uint32() throws -> UInt32 { try UInt32(unsigned(4)) }
    mutating func int16() throws -> Int16 { try Int16(bitPattern: uint16()) }
    mutating func int32() throws -> Int32 { try Int32(bitPattern: uint32()) }

    private mutating func unsigned(_ size: Int) throws -> UInt64 {
        try take(size).reversed().reduce(0) { $0 << 8 | UInt64($1) }
    }
}

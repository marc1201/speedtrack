import Foundation

/// A country's OpenStreetMap file, which Settings downloads and MapLibre draws. `CountryMaps.json`
/// lists them, and the map server publishes exactly the files that list names, so the app and the
/// server read one list. `tools/extract-country-map.py` makes the files.
struct CountryMap: Decodable, Identifiable, Equatable {
    /// The file's name on the server and on the phone. It carries the date of its data, so a name
    /// never gets other bytes.
    let name: String
    let bytes: Int64
    /// Of the whole file, in lowercase hex.
    let sha256: String
    let title: String

    var id: String { name }

    struct FormatError: Error {}

    /// Where the files are published. The server pauses downloads when its monthly budget is spent.
    static let server = URL(string: "https://maps.1201.de/")!

    var url: URL { Self.server.appendingPathComponent(name) }

    /// Reads the list, and refuses an entry whose name could leave the maps directory, or whose size
    /// or hash cannot be right.
    static func list(from data: Data) throws -> [CountryMap] {
        struct List: Decodable { let files: [CountryMap] }
        let maps = try JSONDecoder().decode(List.self, from: data).files
        for map in maps {
            guard map.name.range(of: #"^[a-z0-9][a-z0-9-]*\.pmtiles$"#, options: .regularExpression) != nil,
                  map.bytes > 0,
                  map.sha256.range(of: #"^[0-9a-f]{64}$"#, options: .regularExpression) != nil,
                  !map.title.isEmpty
            else { throw FormatError() }
        }
        guard Set(maps.map(\.name)).count == maps.count else { throw FormatError() }
        return maps
    }

    /// The list in the app. A damaged list offers no downloads rather than stopping the app.
    static let all: [CountryMap] = {
        guard let url = Bundle.main.url(forResource: "CountryMaps", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let maps = try? list(from: data)
        else { return [] }
        return maps
    }()

    /// When a paused server takes downloads again. Its answer 503 says in how many seconds.
    static func resumption(retryAfter: String?, now: Date) -> Date? {
        guard let retryAfter,
              let seconds = Int(retryAfter.trimmingCharacters(in: .whitespaces)),
              seconds >= 0
        else { return nil }
        return now.addingTimeInterval(TimeInterval(seconds))
    }
}

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

    /// What a download does with the map server's answer, before it writes a byte.
    enum Answer: Equatable {
        /// The rest of the file follows: add it to the partial file.
        case append
        /// The whole file follows: start the partial file over.
        case restart
        /// The partial file is whole already, and only needs its check.
        case complete
        case paused(until: Date)
        case refused(String, discardPart: Bool)
    }

    /// `offset` is how much of the file the phone has already, and a request with an offset asked
    /// for the rest only.
    func answer(status: Int, contentRange: String?, retryAfter: String?, offset: Int64, now: Date) -> Answer {
        switch status {
        case 200:
            return .restart
        case 206 where offset > 0 && contentRange?.hasPrefix("bytes \(offset)-") == true:
            return .append
        case 206:
            return .refused("The map server sent the wrong part. Try again later.", discardPart: false)
        case 416 where offset == bytes:
            return .complete
        case 416:
            return .refused("The download did not fit the map. Download again.", discardPart: true)
        case 503:
            return Self.resumption(retryAfter: retryAfter, now: now).map { .paused(until: $0) }
                ?? .refused("The map server is busy. Try again later.", discardPart: false)
        case 404:
            return .refused("This map is not on the map server yet.", discardPart: false)
        default:
            return .refused("The map server answered \(status).", discardPart: false)
        }
    }

    /// When a paused server takes downloads again. Its answer 503 says in how many seconds.
    static func resumption(retryAfter: String?, now: Date) -> Date? {
        guard let retryAfter,
              let seconds = Int(retryAfter.trimmingCharacters(in: .whitespaces)),
              seconds >= 0
        else { return nil }
        return now.addingTimeInterval(TimeInterval(seconds))
    }
}

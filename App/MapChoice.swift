/// The map under the speed, chosen in Settings.
enum MapChoice: String, CaseIterable, Identifiable {
    /// Apple's map, which needs internet. Without it the app draws the outlines on top.
    case apple
    /// The outlines alone, built into the app, so the map never needs internet.
    case outlines
    /// The countries downloaded in Settings, over the outlines.
    case openStreetMap

    var id: Self { self }

    var title: String {
        switch self {
        case .apple: "Apple Maps"
        case .outlines: "Outlines"
        case .openStreetMap: "OpenStreetMap"
        }
    }

    var explanation: String {
        switch self {
        case .apple:
            "Apple's map, loaded over the internet. Without internet the app draws the outlines on it."
        case .outlines:
            "Coastlines, borders, main roads, railways and towns, built into the app. Needs no internet."
        case .openStreetMap:
            "Roads, towns and land of the countries downloaded below, over the outlines. Needs no internet once a country is downloaded."
        }
    }
}

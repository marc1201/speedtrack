import SwiftUI

/// The second tab: which map the app draws, and the countries downloaded for OpenStreetMap.
struct SettingsView: View {
    @AppStorage("map") private var map: MapChoice = .apple
    @EnvironmentObject private var countryMaps: CountryMapStore

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Map", selection: $map) {
                        ForEach(MapChoice.allCases) { choice in
                            Text(choice.title).tag(choice)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Map")
                } footer: {
                    Text(map.explanation)
                }
                Section {
                    ForEach(CountryMap.all) { country in
                        CountryRow(country: country, state: countryMaps.state(of: country))
                    }
                } header: {
                    Text("OpenStreetMap countries")
                } footer: {
                    Text("Each country downloads once from maps.1201.de, then works without internet. The map server sees your IP address and which country you download, never your position. Map data © OpenStreetMap contributors, prepared by Protomaps.")
                }
                Section {
                    Link("Privacy policy", destination: ProjectPage.privacyPolicy)
                    Link("Help and contact", destination: ProjectPage.support)
                    NavigationLink("Licences") { LicencesView() }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

/// The app's pages in its public repository. The browser opens them on a tap, and the app itself
/// requests nothing there. `ci/build-test.sh` checks that each file named here exists.
private enum ProjectPage {
    static let repository = URL(string: "https://github.com/marc1201/speedtrack")!
    static let privacyPolicy = repository.appending(path: "blob/main/PRIVACY.md")
    static let support = repository.appending(path: "blob/main/SUPPORT.md")
}

private struct CountryRow: View {
    let country: CountryMap
    let state: CountryMapStore.State
    @EnvironmentObject private var countryMaps: CountryMapStore

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(country.title)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(state.isFailure ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
            }
            Spacer()
            switch state {
            case .absent, .failed, .paused:
                Button("Download") { countryMaps.download(country) }
                    .disabled(state.isPaused)
            case .downloading(let fraction):
                ProgressView(value: fraction)
                    .frame(width: 80)
                Button("Cancel", systemImage: "xmark.circle.fill") { countryMaps.cancel(country) }
                    .labelStyle(.iconOnly)
            case .ready:
                Button("Delete", role: .destructive) { countryMaps.delete(country) }
            }
        }
        .buttonStyle(.borderless)
    }

    private var detail: String {
        let size = ByteCountFormatter.string(fromByteCount: country.bytes, countStyle: .file)
        switch state {
        case .absent: return size
        case .downloading(let fraction): return "\(size), \(Int(fraction * 100)) % downloaded"
        case .ready: return "\(size), downloaded"
        case .failed(let message): return message
        case .paused(let until):
            return "The map server pauses downloads until \(until.formatted(date: .abbreviated, time: .shortened))."
        }
    }
}

private extension CountryMapStore.State {
    var isFailure: Bool {
        if case .failed = self { true } else { false }
    }

    var isPaused: Bool {
        if case .paused = self { true } else { false }
    }
}

/// The licences of what the app ships besides its own code: the map data, MapLibre Native and the
/// label font.
private struct LicencesView: View {
    var body: some View {
        List {
            Section("Map data") {
                Text("OpenStreetMap: © OpenStreetMap contributors, under the Open Database License. The country maps are prepared by Protomaps.")
                Link("openstreetmap.org/copyright", destination: URL(string: "https://www.openstreetmap.org/copyright")!)
                Text("Outlines: Natural Earth, which is in the public domain.")
            }
            Section("MapLibre Native") {
                ForEach(Self.mapLibre.indices, id: \.self) { index in
                    Text(Self.mapLibre[index]).font(.caption.monospaced())
                }
            }
            Section("Noto Sans") {
                ForEach(Self.notoSans.indices, id: \.self) { index in
                    Text(Self.notoSans[index]).font(.caption.monospaced())
                }
            }
        }
        .navigationTitle("Licences")
    }

    private static let mapLibre = paragraphs(of: "MapLibreLicense")
    private static let notoSans = paragraphs(of: "OFL")

    /// A licence as paragraphs, one row each: MapLibre's runs to 100 KB, far more than one view can
    /// draw at once.
    private static func paragraphs(of name: String) -> [String] {
        let text = Bundle.main.url(forResource: name, withExtension: "txt")
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? "Missing from the app."
        return text.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .newlines) }
            .filter { !$0.isEmpty }
    }
}

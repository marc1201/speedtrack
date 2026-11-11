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
                    Text("Each country downloads once from maps.1201.de, then works without internet. The map server sees which country is downloaded, not where you are. Map data © OpenStreetMap contributors, prepared by Protomaps.")
                }
            }
            .navigationTitle("Settings")
        }
    }
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

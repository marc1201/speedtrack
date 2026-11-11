import SwiftUI

@main
struct SpeedTrackApp: App {
    @StateObject private var countryMaps = CountryMapStore()

    var body: some Scene {
        WindowGroup {
            TabView {
                ContentView()
                    .tabItem { Label("Speed", systemImage: "speedometer") }
                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape") }
            }
            .environmentObject(countryMaps)
        }
    }
}

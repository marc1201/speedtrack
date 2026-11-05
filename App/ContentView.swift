import CoreLocation
import SwiftUI

struct ContentView: View {
    @StateObject private var monitor = SpeedMonitor()

    private var accessDenied: Bool {
        monitor.authorization == .denied || monitor.authorization == .restricted
    }

    var body: some View {
        VStack(spacing: 8) {
            Text(monitor.reading.label)
                .font(.system(size: 120, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text("km/h")
                .font(.title2)
                .foregroundStyle(.secondary)
            if accessDenied {
                Text("Location access is off. Turn it on in Settings to see your speed.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.top, 24)
            }
        }
        .padding()
        .onAppear { monitor.start() }
        .onDisappear { monitor.stop() }
    }
}

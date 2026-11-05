import CoreLocation
import SwiftUI

struct ContentView: View {
    @StateObject private var monitor = SpeedMonitor()
    @AppStorage("speedUnit") private var unit: SpeedUnit = .kilometersPerHour
    @Environment(\.scenePhase) private var scenePhase

    private var accessDenied: Bool {
        monitor.authorization == .denied || monitor.authorization == .restricted
    }

    var body: some View {
        VStack(spacing: 8) {
            // Redrawn every second, so a reading that stops updating turns into "--".
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                Text(monitor.reading.label(in: unit, at: timeline.date))
                    .font(.system(size: 120, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
            Text(unit.title)
                .font(.title2)
                .foregroundStyle(.secondary)
            Picker("Unit", selection: $unit) {
                ForEach(SpeedUnit.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .padding(.top, 24)
            if accessDenied {
                Text("Location access is off. Turn it on in Settings to see your speed.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.top, 24)
            }
        }
        .padding()
        .onChange(of: scenePhase, initial: true) { _, phase in
            let onScreen = phase == .active
            UIApplication.shared.isIdleTimerDisabled = onScreen
            if onScreen {
                monitor.start()
            } else {
                monitor.stop()
            }
        }
    }
}

import SwiftUI

struct ContentView: View {
    @StateObject private var monitor = SpeedMonitor()
    @AppStorage("speedUnit") private var unit: SpeedUnit = .kilometersPerHour
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 8) {
            // Redrawn every second, so a speed that stops updating turns grey.
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                let speed = monitor.speedometer.shown(in: unit, at: timeline.date)
                VStack(spacing: 8) {
                    // The speed is all the app shows, so it may take the whole width. A label too wide
                    // for it, such as a pace, shrinks to fit.
                    Text(speed.label)
                        .font(.system(size: 200, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        // Grey marks the last speed measured, and the line below says why no current
                        // one comes in.
                        .foregroundStyle(speed.isCurrent ? HierarchicalShapeStyle.primary : .secondary)
                    Text(unit.title)
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    // Always two lines tall, so a longer message cannot move the number. The size
                    // cap keeps every message within those two lines on the narrowest iPhone.
                    Text(monitor.access.message(for: monitor.speedometer.latest, at: timeline.date))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2, reservesSpace: true)
                        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                    Text(monitor.speedometer.topSpeedLine(in: unit, at: timeline.date))
                        .font(.title3)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .padding(.top, 16)
                }
            }
            Picker("Unit", selection: $unit) {
                ForEach(SpeedUnit.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .padding(.top, 24)
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

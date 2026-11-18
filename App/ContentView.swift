import SwiftUI

struct ContentView: View {
    @StateObject private var monitor = SpeedMonitor()
    @AppStorage("speedUnit") private var unit: SpeedUnit = .kilometersPerHour
    @AppStorage("map") private var map: MapChoice = .apple
    @EnvironmentObject private var countryMaps: CountryMapStore
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 8) {
            // Redrawn every second, so a speed that stops updating turns grey.
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                let speed = monitor.speedometer.shown(in: unit, at: timeline.date)
                VStack(spacing: 8) {
                    // The speed comes first, so it may take the whole width, and it shrinks to the
                    // height that its half leaves. A label too wide for it, such as a pace, shrinks
                    // further and is lower, so a hidden digit keeps the height, and the lines below
                    // do not move with the unit or the speed.
                    ZStack {
                        Text(verbatim: "0")
                            .font(Self.speedFont)
                            .lineLimit(1)
                            .minimumScaleFactor(Self.speedMinimumScale)
                            .hidden()
                        Text(speed.label)
                            .font(Self.speedFont)
                            .monospacedDigit()
                            .minimumScaleFactor(Self.speedMinimumScale)
                            .lineLimit(1)
                            // Grey marks the last speed measured, and the line below says why no
                            // current one comes in.
                            .foregroundStyle(speed.isCurrent ? HierarchicalShapeStyle.primary : .secondary)
                    }
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
                    ZStack {
                        Text(verbatim: "0")
                            .font(.title3)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .hidden()
                        Text(monitor.speedometer.topSpeedLine(in: unit, at: timeline.date))
                            .font(.title3)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                    .padding(.top, 16)
                }
            }
            // The numbers and the map always get the same height, by Marc's word of 2026-11-18: on
            // a short or wide screen the speed shrinks, not the map. Both take any height offered,
            // so the stack gives them equal shares of the room the unit picker leaves.
            .frame(maxHeight: .infinity)
            Picker("Unit", selection: $unit) {
                ForEach(SpeedUnit.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .padding(.top, 24)
            .padding(.bottom, 8)
            mapView
                .frame(maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12))
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

    private static let speedFont = Font.system(size: 200, weight: .bold, design: .rounded)
    /// How far the speed may shrink to fit its half, which is shortest on the smallest iPhone with
    /// large text. Both of its texts use it, so the hidden digit and the label fit the same height.
    private static let speedMinimumScale: CGFloat = 0.25

    @ViewBuilder
    private var mapView: some View {
        let speed = monitor.speedometer.latest.metersPerSecond
        switch map {
        case .apple:
            PositionMap(location: monitor.location, speed: speed)
        case .outlines:
            LibreMap(location: monitor.location, speed: speed, countries: nil)
        case .openStreetMap:
            LibreMap(location: monitor.location, speed: speed, countries: countryMaps.readyFiles)
        }
    }
}

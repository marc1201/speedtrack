import Foundation

/// The units a speed can be shown in. All conversion and formatting lives here.
enum SpeedUnit: String, CaseIterable, Identifiable {
    case kilometersPerHour
    case metersPerSecond
    case milesPerHour
    case minutesPerKilometer
    case minutesPerMile

    private static let metersPerMile = 1_609.344
    /// A pace of 100 minutes or more means nothing and would not fit the screen.
    private static let slowestPaceSeconds = 6_000.0

    var id: Self { self }

    var title: String {
        switch self {
        case .kilometersPerHour: "km/h"
        case .metersPerSecond: "m/s"
        case .milesPerHour: "mph"
        case .minutesPerKilometer: "min/km"
        case .minutesPerMile: "min/mi"
        }
    }

    func label(metersPerSecond speed: Double) -> String {
        switch self {
        case .kilometersPerHour: String(format: "%.0f", speed * 3.6)
        case .metersPerSecond: String(format: "%.1f", speed)
        case .milesPerHour: String(format: "%.0f", speed * 3_600 / Self.metersPerMile)
        case .minutesPerKilometer: Self.paceLabel(seconds: 1_000 / speed)
        case .minutesPerMile: Self.paceLabel(seconds: Self.metersPerMile / speed)
        }
    }

    /// Rounds before splitting, so 5:59.7 reads 6:00 and never 5:60. At a standstill the division
    /// gives infinity, which fails the guard: standing still has no pace.
    private static func paceLabel(seconds: Double) -> String {
        let rounded = seconds.rounded()
        guard rounded < slowestPaceSeconds else { return SpeedReading.unknownLabel }
        return String(format: "%d:%02d", Int(rounded) / 60, Int(rounded) % 60)
    }
}

/// One speed sample. CoreLocation reports metres per second and a negative value when the speed
/// is unknown.
struct SpeedReading: Equatable {
    static let unknownLabel = "--"
    static let unknown = SpeedReading(rawSpeed: -1, measuredAt: .distantPast)
    /// Seconds after which a sample no longer says how fast the device is moving.
    static let maximumAge: TimeInterval = 5
    /// Metres per second below which a device lying still counts as stopped: GPS speed drifts at a
    /// standstill. Anything faster is real, because a phone on a smooth train feels no more
    /// acceleration than one on a table.
    static let standstillSpeed = 1.0

    let metersPerSecond: Double?
    let measuredAt: Date

    init(rawSpeed: Double, measuredAt: Date, deviceIsStill: Bool = false) {
        if rawSpeed.isFinite, rawSpeed >= 0 {
            metersPerSecond = deviceIsStill && rawSpeed < Self.standstillSpeed ? 0 : rawSpeed
        } else {
            metersPerSecond = nil
        }
        self.measuredAt = measuredAt
    }

    func label(in unit: SpeedUnit, at now: Date) -> String {
        guard let metersPerSecond, now.timeIntervalSince(measuredAt) <= Self.maximumAge else {
            return Self.unknownLabel
        }
        return unit.label(metersPerSecond: metersPerSecond)
    }
}

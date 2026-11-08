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
    /// Seconds after which a sample no longer says where the device is. This is a judgement, not
    /// an Apple figure: Core Location promises no rate, and fixes can come far apart indoors.
    static let locationMaximumAge: TimeInterval = 30
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

    func currentSpeed(at now: Date) -> Double? {
        now.timeIntervalSince(measuredAt) <= Self.maximumAge ? metersPerSecond : nil
    }

    func hasLocation(at now: Date) -> Bool {
        now.timeIntervalSince(measuredAt) <= Self.locationMaximumAge
    }

    func label(in unit: SpeedUnit, at now: Date) -> String {
        guard let speed = currentSpeed(at: now) else { return Self.unknownLabel }
        return unit.label(metersPerSecond: speed)
    }
}

/// What the screen knows of the speed: the newest fix, and the last speed measured, which stays on
/// screen in grey while no current one comes in. It lives only as long as the app does.
struct Speedometer {
    /// The newest fix. It says whether the speed is current and whether there is a location.
    private(set) var latest = SpeedReading.unknown
    /// The newest fix that had a speed.
    private(set) var lastSpeed = SpeedReading.unknown

    mutating func record(_ reading: SpeedReading) {
        latest = reading
        if reading.metersPerSecond != nil {
            lastSpeed = reading
        }
    }

    /// Without permission no fix counts, but the last speed stays on screen.
    mutating func forgetLocation() {
        latest = .unknown
    }

    /// The number on screen: the current speed, or else the last one, which is not current.
    func shown(in unit: SpeedUnit, at now: Date) -> (label: String, isCurrent: Bool) {
        if let speed = latest.currentSpeed(at: now) {
            return (unit.label(metersPerSecond: speed), true)
        }
        guard let speed = lastSpeed.metersPerSecond else { return (SpeedReading.unknownLabel, false) }
        return (unit.label(metersPerSecond: speed), false)
    }
}

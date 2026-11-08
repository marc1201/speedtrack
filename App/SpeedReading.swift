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

/// What the screen knows of the speed: the newest fix, the last speed measured, which stays on
/// screen in grey while no current one comes in, and the top speed of the day. Only the top speed
/// outlasts the app, and only when there is a store for it.
struct Speedometer {
    /// The newest fix. It says whether the speed is current and whether there is a location.
    private(set) var latest = SpeedReading.unknown
    /// The newest fix that had a speed.
    private(set) var lastSpeed = SpeedReading.unknown
    /// The fastest fix of the newest day that had a speed.
    private(set) var topSpeed: SpeedReading
    private let store: TopSpeedStore?

    init(store: TopSpeedStore? = nil, now: Date = Date()) {
        self.store = store
        topSpeed = store?.load(at: now) ?? .unknown
    }

    mutating func record(_ reading: SpeedReading, calendar: Calendar = .current) {
        latest = reading
        guard let speed = reading.metersPerSecond else { return }
        lastSpeed = reading
        if let top = topSpeed.metersPerSecond,
           calendar.isDate(reading.measuredAt, inSameDayAs: topSpeed.measuredAt) {
            guard speed > top else { return }
        } else {
            // A new day starts over. An older fix, such as a cached one from yesterday, does not.
            guard reading.measuredAt > topSpeed.measuredAt else { return }
        }
        topSpeed = reading
        store?.save(reading)
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

    /// The smaller line under the speed. Only a speed measured on the day of `now` counts.
    func topSpeedLine(in unit: SpeedUnit, at now: Date, calendar: Calendar = .current) -> String {
        var label = SpeedReading.unknownLabel
        if let speed = topSpeed.metersPerSecond, calendar.isDate(topSpeed.measuredAt, inSameDayAs: now) {
            label = unit.label(metersPerSecond: speed)
        }
        // "--" takes no unit. A pace gives it at a standstill too.
        let unitTitle = label == SpeedReading.unknownLabel ? "" : " \(unit.title)"
        return "Top speed today: \(label)\(unitTitle)"
    }
}

/// Keeps the top speed of the day in the app's own settings on the phone, so it outlasts the app.
/// By Marc's decision of 2026-11-08 it is the only thing from location the app stores: one speed
/// and its time, which the app sends nowhere.
struct TopSpeedStore {
    static let speedKey = "topSpeedMetersPerSecond"
    static let timeKey = "topSpeedMeasuredAt"

    let defaults: UserDefaults

    /// A top speed from the future means the clock was wrong. It would keep out every newer top
    /// speed until then, so it is dropped.
    func load(at now: Date) -> SpeedReading {
        guard defaults.object(forKey: Self.speedKey) != nil,
              defaults.object(forKey: Self.timeKey) != nil
        else { return .unknown }
        let measuredAt = Date(timeIntervalSinceReferenceDate: defaults.double(forKey: Self.timeKey))
        guard measuredAt <= now else { return .unknown }
        let topSpeed = SpeedReading(rawSpeed: defaults.double(forKey: Self.speedKey), measuredAt: measuredAt)
        return topSpeed.metersPerSecond == nil ? .unknown : topSpeed
    }

    func save(_ topSpeed: SpeedReading) {
        guard let speed = topSpeed.metersPerSecond else { return }
        defaults.set(speed, forKey: Self.speedKey)
        defaults.set(topSpeed.measuredAt.timeIntervalSinceReferenceDate, forKey: Self.timeKey)
    }
}

import Foundation

/// One speed sample. CoreLocation reports metres per second and a negative value when the speed
/// is unknown.
struct SpeedReading: Equatable {
    let metersPerSecond: Double?

    init(rawSpeed: Double) {
        metersPerSecond = rawSpeed >= 0 ? rawSpeed : nil
    }

    var kilometersPerHour: Double? {
        metersPerSecond.map { $0 * 3.6 }
    }

    var label: String {
        guard let kilometersPerHour else { return "--" }
        return String(format: "%.0f", kilometersPerHour)
    }
}

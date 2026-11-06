import Foundation

/// What the user lets the app do. SpeedMonitor maps CoreLocation's values to this, because
/// CoreLocation does not exist where the tests of the pure logic run.
enum LocationAccess: Equatable {
    case undecided
    case denied
    case restricted
    case approximate
    case precise

    /// The line that explains the speed. Permission comes first, because no reading can help then.
    /// Core Location never says whether a fix came from GPS, so this says location, not GPS. .denied
    /// also covers Location Services being off for the whole iPhone, and .restricted cannot be
    /// changed by this user, so it gives no instruction.
    func message(for reading: SpeedReading, at now: Date) -> String {
        switch self {
        case .undecided: "Waiting for location permission"
        case .denied: "Location is off. Turn it on in Settings."
        case .restricted: "Location is restricted on this iPhone"
        case .approximate: "Turn on Precise Location in Settings."
        case .precise:
            if reading.currentSpeed(at: now) != nil {
                "Location and speed available"
            } else if reading.hasLocation(at: now) {
                "Location found, no speed yet"
            } else {
                "Looking for your location"
            }
        }
    }
}

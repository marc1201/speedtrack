import Foundation

/// Tells from the accelerometer whether the device is lying still. Acceleration says nothing about
/// a steady speed, so this may only correct a low GPS speed, never replace one.
struct StillnessDetector {
    /// Acceleration in g, with gravity removed, at which the device counts as moved.
    static let threshold = 0.03
    /// Seconds without movement before the device counts as still.
    static let holdTime: TimeInterval = 2

    private var quietSince: Date?

    mutating func record(x: Double, y: Double, z: Double, at time: Date) {
        if (x * x + y * y + z * z).squareRoot() >= Self.threshold {
            quietSince = nil
        } else if quietSince == nil {
            quietSince = time
        }
    }

    func isStill(at time: Date) -> Bool {
        guard let quietSince else { return false }
        return time.timeIntervalSince(quietSince) >= Self.holdTime
    }
}

import Foundation

/// How much ground the map shows: about two minutes of travel. The map then stays readable at any
/// speed, and while there is signal the stretch ahead is loaded before it is reached. The span moves
/// in steps that double. It steps out as soon as the speed asks for it, and back in only when the
/// speed has clearly dropped, so small changes in speed do not zoom the map. Without internet the map
/// zooms out to the scale of the built-in overview.
struct MapZoom {
    /// Metres across, from walking to a plane.
    static let steps: [Double] = [1_000, 2_000, 4_000, 8_000, 16_000, 32_000, 64_000, 128_000]
    static let travelTime: TimeInterval = 120
    /// A step gives way to a smaller one only below this share of it, well inside the step below.
    static let stepInBelow = 0.4
    /// The span is at least this many times the fix's accuracy, so the circle of an approximate
    /// location fits on the map.
    static let accuracyFactor = 4.0
    /// The built-in overview has no streets, and Natural Earth draws its lines for this scale and
    /// wider.
    static let offlineSpan = 64_000.0

    private var step = 0

    /// The span for the newest fix, in metres. Without a speed the span stays as it was.
    mutating func span(speed metersPerSecond: Double?, accuracy: Double, offline: Bool) -> Double {
        if let metersPerSecond {
            let wanted = metersPerSecond * Self.travelTime
            let fitting = Self.steps.firstIndex { $0 >= wanted } ?? Self.steps.count - 1
            if fitting > step || wanted <= Self.steps[step] * Self.stepInBelow {
                step = fitting
            }
        }
        let span = max(Self.steps[step], accuracy * Self.accuracyFactor)
        return offline ? max(span, Self.offlineSpan) : span
    }
}

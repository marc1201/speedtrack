import CoreLocation
import CoreMotion
import Foundation

/// Follows the device's location and motion and publishes the current speed.
final class SpeedMonitor: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var reading = SpeedReading.unknown
    @Published private(set) var authorization: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()
    private let motion = CMMotionManager()
    private var stillness = StillnessDetector()
    private var isFollowing = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.activityType = .otherNavigation
        // A pause while standing still would turn a true 0 into "--".
        manager.pausesLocationUpdatesAutomatically = false
        authorization = manager.authorizationStatus
        motion.deviceMotionUpdateInterval = 0.1
    }

    func start() {
        isFollowing = true
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        manager.startUpdatingLocation()
        guard motion.isDeviceMotionAvailable else { return }
        motion.startDeviceMotionUpdates(to: .main) { [weak self] sample, _ in
            guard let self, let acceleration = sample?.userAcceleration else { return }
            self.stillness.record(x: acceleration.x, y: acceleration.y, z: acceleration.z, at: .now)
        }
    }

    func stop() {
        isFollowing = false
        manager.stopUpdatingLocation()
        motion.stopDeviceMotionUpdates()
        stillness = StillnessDetector()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorization = manager.authorizationStatus
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            // This also fires while the app is off screen, and start() is what decides.
            if isFollowing {
                manager.startUpdatingLocation()
            }
        default:
            reading = .unknown
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        reading = SpeedReading(
            rawSpeed: latest.speed,
            measuredAt: latest.timestamp,
            deviceIsStill: stillness.isStill(at: latest.timestamp)
        )
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        reading = .unknown
    }
}

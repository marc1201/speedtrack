import CoreLocation
import CoreMotion
import Foundation

/// Follows the device's location and motion and publishes the current speed.
final class SpeedMonitor: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var speedometer = Speedometer(store: TopSpeedStore(defaults: .standard))
    @Published private(set) var access = LocationAccess.undecided
    /// The newest fix, for the map. Like every fix it stays in memory only.
    @Published private(set) var location: CLLocation?

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
        refreshAccess()
        motion.deviceMotionUpdateInterval = 0.1
    }

    func start() {
        isFollowing = true
        refreshAccess()
        follow()
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

    /// Fires when Precise Location changes too, when authorizationStatus stays the same.
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        refreshAccess()
        if access != .precise && access != .approximate {
            speedometer.forgetLocation()
            location = nil
        }
        // This also fires while the app is off screen, and start() is what decides.
        if isFollowing {
            follow()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // A negative accuracy marks invalid coordinates, and 0 is not expected either.
        guard let latest = locations.last, latest.horizontalAccuracy > 0 else { return }
        location = latest
        speedometer.record(SpeedReading(
            rawSpeed: latest.speed,
            measuredAt: latest.timestamp,
            deviceIsStill: stillness.isStill(at: latest.timestamp)
        ))
    }

    /// Core Location requires this method, but no error needs an answer here. A real denial also
    /// changes the permission, and after anything else the reading ages out if no fix follows.
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}

    private func refreshAccess() {
        switch manager.authorizationStatus {
        case .notDetermined:
            access = .undecided
        case .restricted:
            access = .restricted
        case .authorizedWhenInUse, .authorizedAlways:
            access = manager.accuracyAuthorization == .fullAccuracy ? .precise : .approximate
        default:
            access = .denied
        }
    }

    /// Does what the current permission calls for. Starting updates while denied can make iOS
    /// prompt the user, and start() runs on every return to the screen.
    private func follow() {
        switch access {
        case .undecided:
            manager.requestWhenInUseAuthorization()
        case .approximate, .precise:
            manager.startUpdatingLocation()
        case .denied, .restricted:
            manager.stopUpdatingLocation()
        }
    }
}

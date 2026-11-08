import XCTest
@testable import SpeedTrack

final class SpeedometerTests: XCTestCase {
    private let now = Date(timeIntervalSinceReferenceDate: 1_000)

    private func reading(_ speed: Double, after seconds: TimeInterval = 0) -> SpeedReading {
        SpeedReading(rawSpeed: speed, measuredAt: now.addingTimeInterval(seconds))
    }

    private func assertShown(
        _ speedometer: Speedometer,
        after seconds: TimeInterval = 0,
        in unit: SpeedUnit = .kilometersPerHour,
        _ label: String,
        isCurrent: Bool,
        line: UInt = #line
    ) {
        let shown = speedometer.shown(in: unit, at: now.addingTimeInterval(seconds))
        XCTAssertEqual(shown.label, label, line: line)
        XCTAssertEqual(shown.isCurrent, isCurrent, line: line)
    }

    func testNothingMeasuredShowsNothing() {
        assertShown(Speedometer(), "--", isCurrent: false)
    }

    func testAFreshSpeedIsCurrent() {
        var speedometer = Speedometer()
        speedometer.record(reading(10))
        assertShown(speedometer, after: SpeedReading.maximumAge, "36", isCurrent: true)
    }

    func testAnOldSpeedStaysButIsNotCurrent() {
        var speedometer = Speedometer()
        speedometer.record(reading(10))
        assertShown(speedometer, after: SpeedReading.maximumAge + 0.1, "36", isCurrent: false)
        assertShown(speedometer, after: 3_600, "36", isCurrent: false)
    }

    func testAFixWithoutASpeedKeepsTheLastSpeed() {
        var speedometer = Speedometer()
        speedometer.record(reading(10))
        speedometer.record(reading(-1, after: 1))
        assertShown(speedometer, after: 1, "36", isCurrent: false)
        // The status line reads the newest fix, so it says that no speed comes in.
        XCTAssertEqual(speedometer.latest, reading(-1, after: 1))
    }

    func testANewSpeedReplacesTheLastOne() {
        var speedometer = Speedometer()
        speedometer.record(reading(10))
        speedometer.record(reading(5, after: 1))
        assertShown(speedometer, after: 1, "18", isCurrent: true)
    }

    func testAStandstillIsALastSpeedToo() {
        var speedometer = Speedometer()
        speedometer.record(reading(0))
        speedometer.record(reading(-1, after: 1))
        assertShown(speedometer, after: 1, "0", isCurrent: false)
    }

    func testLosingPermissionKeepsTheLastSpeed() {
        var speedometer = Speedometer()
        speedometer.record(reading(10))
        speedometer.forgetLocation()
        assertShown(speedometer, "36", isCurrent: false)
        XCTAssertEqual(speedometer.latest, .unknown)
    }

    func testTheLastSpeedFollowsTheUnit() {
        var speedometer = Speedometer()
        speedometer.record(reading(2.5))
        assertShown(speedometer, after: 60, in: .minutesPerKilometer, "6:40", isCurrent: false)
        assertShown(speedometer, after: 60, in: .metersPerSecond, "2.5", isCurrent: false)
    }

    // MARK: - The top speed of the day

    /// Days in UTC, so the tests do not depend on the time zone of the machine.
    private let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()
    /// Noon on 1 January 2001, UTC.
    private let noon = Date(timeIntervalSinceReferenceDate: 12 * 3_600)

    private func time(hoursAfterNoon hours: Double) -> Date {
        noon.addingTimeInterval(hours * 3_600)
    }

    private func record(_ speed: Double, hoursAfterNoon hours: Double, into speedometer: inout Speedometer) {
        let reading = SpeedReading(rawSpeed: speed, measuredAt: time(hoursAfterNoon: hours))
        speedometer.record(reading, calendar: utc)
    }

    private func topSpeedLine(
        _ speedometer: Speedometer,
        hoursAfterNoon hours: Double,
        in unit: SpeedUnit = .kilometersPerHour
    ) -> String {
        speedometer.topSpeedLine(in: unit, at: time(hoursAfterNoon: hours), calendar: utc)
    }

    func testNoSpeedYetHasNoTopSpeed() {
        XCTAssertEqual(topSpeedLine(Speedometer(), hoursAfterNoon: 0), "Top speed today: --")
    }

    func testTheTopSpeedIsTheHighestOfTheDay() {
        var speedometer = Speedometer()
        record(10, hoursAfterNoon: 0, into: &speedometer)
        record(20, hoursAfterNoon: 1, into: &speedometer)
        record(15, hoursAfterNoon: 2, into: &speedometer)
        record(-1, hoursAfterNoon: 3, into: &speedometer)
        XCTAssertEqual(topSpeedLine(speedometer, hoursAfterNoon: 4), "Top speed today: 72 km/h")
    }

    func testTheTopSpeedStartsOverOnANewDay() {
        var speedometer = Speedometer()
        record(20, hoursAfterNoon: 0, into: &speedometer)
        record(5, hoursAfterNoon: 12.5, into: &speedometer)
        XCTAssertEqual(topSpeedLine(speedometer, hoursAfterNoon: 13), "Top speed today: 18 km/h")
    }

    func testYesterdaysTopSpeedIsNotShownToday() {
        var speedometer = Speedometer()
        record(20, hoursAfterNoon: 0, into: &speedometer)
        XCTAssertEqual(topSpeedLine(speedometer, hoursAfterNoon: 11.9), "Top speed today: 72 km/h")
        XCTAssertEqual(topSpeedLine(speedometer, hoursAfterNoon: 12), "Top speed today: --")
    }

    func testAnOlderDayCannotReplaceToday() {
        var speedometer = Speedometer()
        record(5, hoursAfterNoon: 0, into: &speedometer)
        record(20, hoursAfterNoon: -13, into: &speedometer)
        XCTAssertEqual(topSpeedLine(speedometer, hoursAfterNoon: 0), "Top speed today: 18 km/h")
    }

    func testTheTopSpeedFollowsTheUnit() {
        var speedometer = Speedometer()
        record(2.5, hoursAfterNoon: 0, into: &speedometer)
        let pace = topSpeedLine(speedometer, hoursAfterNoon: 0, in: .minutesPerKilometer)
        XCTAssertEqual(pace, "Top speed today: 6:40 min/km")
        let metersPerSecond = topSpeedLine(speedometer, hoursAfterNoon: 0, in: .metersPerSecond)
        XCTAssertEqual(metersPerSecond, "Top speed today: 2.5 m/s")
    }

    func testAStandstillHasATopSpeedButNoTopPace() {
        var speedometer = Speedometer()
        record(0, hoursAfterNoon: 0, into: &speedometer)
        XCTAssertEqual(topSpeedLine(speedometer, hoursAfterNoon: 0), "Top speed today: 0 km/h")
        let pace = topSpeedLine(speedometer, hoursAfterNoon: 0, in: .minutesPerKilometer)
        XCTAssertEqual(pace, "Top speed today: --")
    }

    // MARK: - The top speed on the phone

    private let suiteName = "SpeedTrackTests.TopSpeedStore"
    private var defaults: UserDefaults!
    private var store: TopSpeedStore { TopSpeedStore(defaults: defaults) }

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testNothingStoredIsNoTopSpeed() {
        XCTAssertEqual(store.load(at: noon), .unknown)
        XCTAssertEqual(Speedometer(store: store, now: noon).topSpeed, .unknown)
    }

    func testTheTopSpeedOutlastsTheApp() {
        var before = Speedometer(store: store, now: noon)
        record(20, hoursAfterNoon: 0, into: &before)
        let after = Speedometer(store: store, now: time(hoursAfterNoon: 1))
        XCTAssertEqual(topSpeedLine(after, hoursAfterNoon: 1), "Top speed today: 72 km/h")
    }

    func testOnlyANewTopSpeedIsStored() {
        var speedometer = Speedometer(store: store, now: noon)
        record(10, hoursAfterNoon: 0, into: &speedometer)
        record(20, hoursAfterNoon: 1, into: &speedometer)
        record(15, hoursAfterNoon: 2, into: &speedometer)
        record(-1, hoursAfterNoon: 3, into: &speedometer)
        let stored = store.load(at: time(hoursAfterNoon: 4))
        XCTAssertEqual(stored, SpeedReading(rawSpeed: 20, measuredAt: time(hoursAfterNoon: 1)))
    }

    func testOnlyTheTopSpeedAndItsTimeAreStored() {
        var speedometer = Speedometer(store: store, now: noon)
        record(20, hoursAfterNoon: 0, into: &speedometer)
        record(10, hoursAfterNoon: 1, into: &speedometer)
        speedometer.forgetLocation()
        let stored = defaults.persistentDomain(forName: suiteName) ?? [:]
        XCTAssertEqual(Set(stored.keys), [TopSpeedStore.speedKey, TopSpeedStore.timeKey])
    }

    func testYesterdaysStoredTopSpeedGivesWayToToday() {
        var yesterday = Speedometer(store: store, now: noon)
        record(20, hoursAfterNoon: 0, into: &yesterday)
        var today = Speedometer(store: store, now: time(hoursAfterNoon: 13))
        XCTAssertEqual(topSpeedLine(today, hoursAfterNoon: 13), "Top speed today: --")
        record(5, hoursAfterNoon: 13, into: &today)
        let stored = store.load(at: time(hoursAfterNoon: 14))
        XCTAssertEqual(stored, SpeedReading(rawSpeed: 5, measuredAt: time(hoursAfterNoon: 13)))
    }

    func testATopSpeedFromTheFutureIsDropped() {
        store.save(SpeedReading(rawSpeed: 20, measuredAt: time(hoursAfterNoon: 2)))
        XCTAssertEqual(store.load(at: noon), .unknown)
        var speedometer = Speedometer(store: store, now: noon)
        record(5, hoursAfterNoon: 0, into: &speedometer)
        XCTAssertEqual(topSpeedLine(speedometer, hoursAfterNoon: 0), "Top speed today: 18 km/h")
    }

    func testAnInvalidOrHalfStoredTopSpeedIsNone() {
        defaults.set(-1.0, forKey: TopSpeedStore.speedKey)
        defaults.set(noon.timeIntervalSinceReferenceDate, forKey: TopSpeedStore.timeKey)
        XCTAssertEqual(store.load(at: noon), .unknown)
        defaults.removeObject(forKey: TopSpeedStore.speedKey)
        XCTAssertEqual(store.load(at: noon), .unknown)
    }
}

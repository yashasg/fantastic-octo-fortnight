@testable import EyePostureReminder
import XCTest

// MARK: - PauseConditionManagerTests

/// Unit tests for `PauseConditionManager`.
///
/// All three live detectors are replaced with mocks so no system APIs are hit.
/// State changes are triggered synchronously via mock `simulate*` helpers, which
/// fire the same callbacks the live detectors would fire.
@MainActor
final class PauseConditionManagerTests: XCTestCase {

    var mockFocus: MockFocusStatusDetector!
    var mockCarPlay: MockCarPlayDetector!
    var mockDriving: MockDrivingActivityDetector!
    var mockPersistence: MockSettingsPersisting!
    var settings: SettingsStore!
    var sut: PauseConditionManager!

    override func setUp() {
        super.setUp()
        mockFocus = MockFocusStatusDetector()
        mockCarPlay = MockCarPlayDetector()
        mockDriving = MockDrivingActivityDetector()
        mockPersistence = MockSettingsPersisting()
        settings = SettingsStore(store: mockPersistence)
        sut = makeSUT()
        sut.startMonitoring()
    }

    override func tearDown() {
        sut?.stopMonitoring()
        sut = nil
        settings = nil
        mockPersistence = nil
        mockDriving = nil
        mockCarPlay = nil
        mockFocus = nil
        super.tearDown()
    }

    // Creates a fresh `PauseConditionManager` wired to the shared mock detectors.
    private func makeSUT() -> PauseConditionManager {
        PauseConditionManager(
            settings: settings,
            focusDetector: mockFocus,
            carPlayDetector: mockCarPlay,
            drivingDetector: mockDriving
        )
    }

    // MARK: - Initial State

    func test_init_isPaused_isFalse() {
        let freshSUT = makeSUT()
        XCTAssertFalse(freshSUT.isPaused, "PauseConditionManager must not be paused on init — no conditions active yet")
    }

    // MARK: - Focus Mode

    func test_focusMode_whenActive_pausesReminders() {
        settings.pauseDuringFocus = true
        mockFocus.simulateFocusChange(true)
        XCTAssertTrue(sut.isPaused, "Focus active with pauseDuringFocus=true must set isPaused=true")
    }

    func test_focusMode_whenInactive_isNotPaused() {
        settings.pauseDuringFocus = true
        mockFocus.simulateFocusChange(false)
        XCTAssertFalse(sut.isPaused, "Focus inactive must not pause reminders")
    }

    /// Auth denied → `LiveFocusStatusDetector` never fires the callback.
    /// No callback means no condition is ever inserted, so `isPaused` stays `false`.
    /// This is the "fail open" contract: unknown state = don't pause.
    func test_focusMode_whenAuthDenied_failsOpen() {
        settings.pauseDuringFocus = true
        // No simulate call — detector never fires because auth was denied.
        XCTAssertFalse(sut.isPaused, "Auth-denied focus detector must not trigger a pause (fail-open)")
    }

    func test_focusMode_whenPauseSettingDisabled_ignoresFocusSignal() {
        settings.pauseDuringFocus = false
        mockFocus.simulateFocusChange(true)
        XCTAssertFalse(sut.isPaused, "Focus signal must be ignored when pauseDuringFocus is disabled")
    }

    // MARK: - CarPlay

    func test_carPlay_whenConnected_pausesReminders() {
        settings.pauseWhileDriving = true
        mockCarPlay.simulateCarPlayChange(true)
        XCTAssertTrue(sut.isPaused, "CarPlay connected with pauseWhileDriving=true must set isPaused=true")
    }

    func test_carPlay_whenDisconnected_isNotPaused() {
        settings.pauseWhileDriving = true
        mockCarPlay.simulateCarPlayChange(false)
        XCTAssertFalse(sut.isPaused, "CarPlay disconnected must not pause reminders")
    }

    // MARK: - Driving

    func test_driving_whenDetected_pausesReminders() {
        settings.pauseWhileDriving = true
        mockDriving.simulateDrivingChange(true)
        XCTAssertTrue(sut.isPaused, "Driving detected with pauseWhileDriving=true must set isPaused=true")
    }

    func test_driving_whenNotDetected_isNotPaused() {
        settings.pauseWhileDriving = true
        mockDriving.simulateDrivingChange(false)
        XCTAssertFalse(sut.isPaused, "Driving=false must not pause reminders")
    }

    func test_driving_whenPauseSettingDisabled_ignoresDrivingSignal() {
        settings.pauseWhileDriving = false
        mockDriving.simulateDrivingChange(true)
        XCTAssertFalse(sut.isPaused, "Driving signal must be ignored when pauseWhileDriving is disabled")
    }

    // MARK: - Multiple Conditions

    func test_multipleConditions_whenBothActive_remainsPaused() {
        settings.pauseDuringFocus = true
        settings.pauseWhileDriving = true
        mockFocus.simulateFocusChange(true)
        mockDriving.simulateDrivingChange(true)
        XCTAssertTrue(sut.isPaused, "Multiple active conditions must keep isPaused=true")
    }

    func test_multipleConditions_whenOneClears_remainsPausedIfOtherActive() {
        settings.pauseDuringFocus = true
        settings.pauseWhileDriving = true
        mockFocus.simulateFocusChange(true)
        mockDriving.simulateDrivingChange(true)

        mockFocus.simulateFocusChange(false)

        XCTAssertTrue(sut.isPaused, "Must remain paused while at least one condition is still active")
    }

    func test_allConditions_whenAllClear_resumes() {
        settings.pauseDuringFocus = true
        settings.pauseWhileDriving = true
        mockFocus.simulateFocusChange(true)
        mockCarPlay.simulateCarPlayChange(true)
        mockDriving.simulateDrivingChange(true)

        mockFocus.simulateFocusChange(false)
        mockCarPlay.simulateCarPlayChange(false)
        mockDriving.simulateDrivingChange(false)

        XCTAssertFalse(sut.isPaused, "Must resume when all conditions have cleared")
    }

    // MARK: - Snooze Interaction
    //
    // PauseConditionManager and snooze are independent pause axes (per spec).
    // PauseConditionManager reports its own state truthfully; AppCoordinator is
    // responsible for checking both before calling resumeAll().

    func test_pause_whenPauseClearsWhileSnoozeActive_conditionManagerReportsNotPaused() {
        settings.pauseDuringFocus = true
        settings.snoozedUntil = Date().addingTimeInterval(300)
        mockFocus.simulateFocusChange(true)
        XCTAssertTrue(sut.isPaused)

        var callbackValue: Bool?
        sut.onPauseStateChanged = { callbackValue = $0 }

        // Pause condition clears — snooze is still active.
        mockFocus.simulateFocusChange(false)

        XCTAssertFalse(sut.isPaused, "PauseConditionManager.isPaused is false: all conditions have cleared")
        XCTAssertEqual(callbackValue, false, "onPauseStateChanged fires false when all conditions clear")
        // The consumer (AppCoordinator) must still gate resumeAll() behind this snooze check:
        let snoozeStillActive = settings.snoozedUntil.map { $0 > Date() } ?? false
        XCTAssertTrue(snoozeStillActive, "Snooze is still active — AppCoordinator must not resume tracking yet")
    }

    func test_snooze_aloneDoesNotAffect_isPaused() {
        // Snooze lives in SettingsStore, not in PauseConditionManager.
        // When snooze is set and no pause conditions are active, isPaused is still false.
        settings.snoozedUntil = Date().addingTimeInterval(300)

        XCTAssertFalse(sut.isPaused, "Snooze alone must not affect PauseConditionManager.isPaused")
        let snoozeActive = settings.snoozedUntil.map { $0 > Date() } ?? false
        XCTAssertTrue(snoozeActive, "Snooze flag is set in SettingsStore — consumer must respect it independently")
    }

    // MARK: - Lifecycle

    func test_startMonitoring_callsStartOnAllDetectors() {
        // Use fresh detectors so the startMonitoring call from setUp doesn't inflate counts.
        let focus = MockFocusStatusDetector()
        let carPlay = MockCarPlayDetector()
        let driving = MockDrivingActivityDetector()
        let mgr = PauseConditionManager(
            settings: settings,
            focusDetector: focus,
            carPlayDetector: carPlay,
            drivingDetector: driving
        )

        XCTAssertEqual(focus.startMonitoringCallCount, 0, "Detectors must not start before startMonitoring() is called")

        mgr.startMonitoring()

        XCTAssertEqual(focus.startMonitoringCallCount, 1, "focusDetector.startMonitoring() must be called once")
        XCTAssertEqual(carPlay.startMonitoringCallCount, 1, "carPlayDetector.startMonitoring() must be called once")
        XCTAssertEqual(driving.startMonitoringCallCount, 1, "drivingDetector.startMonitoring() must be called once")

        mgr.stopMonitoring()
    }

    func test_startMonitoring_registersCallbacksOnAllDetectors() {
        let focus = MockFocusStatusDetector()
        let carPlay = MockCarPlayDetector()
        let driving = MockDrivingActivityDetector()
        let mgr = PauseConditionManager(
            settings: settings,
            focusDetector: focus,
            carPlayDetector: carPlay,
            drivingDetector: driving
        )

        mgr.startMonitoring()

        XCTAssertNotNil(
            focus.onFocusChanged,
            "focusDetector.onFocusChanged must be registered after startMonitoring()"
        )
        XCTAssertNotNil(
            carPlay.onCarPlayChanged,
            "carPlayDetector.onCarPlayChanged must be registered after startMonitoring()"
        )
        XCTAssertNotNil(
            driving.onDrivingChanged,
            "drivingDetector.onDrivingChanged must be registered after startMonitoring()"
        )

        mgr.stopMonitoring()
    }

    func test_stopMonitoring_callsStopOnAllDetectors() {
        // setUp already called startMonitoring() on sut.
        sut.stopMonitoring()

        XCTAssertEqual(mockFocus.stopMonitoringCallCount, 1, "focusDetector.stopMonitoring() must be called")
        XCTAssertEqual(mockCarPlay.stopMonitoringCallCount, 1, "carPlayDetector.stopMonitoring() must be called")
        XCTAssertEqual(mockDriving.stopMonitoringCallCount, 1, "drivingDetector.stopMonitoring() must be called")

        // Prevent double-stop in tearDown.
        sut = nil
    }

    func test_onPauseStateChanged_firesOnStateFlip() {
        settings.pauseDuringFocus = true
        var callbackValues: [Bool] = []
        sut.onPauseStateChanged = { callbackValues.append($0) }

        mockFocus.simulateFocusChange(true)   // paused
        mockFocus.simulateFocusChange(false)  // unpaused

        XCTAssertEqual(callbackValues, [true, false], "onPauseStateChanged must fire for each state flip")
    }

    func test_onPauseStateChanged_notFiredWhenStateUnchanged() {
        settings.pauseDuringFocus = true
        settings.pauseWhileDriving = true
        var callbackCount = 0
        sut.onPauseStateChanged = { _ in callbackCount += 1 }

        mockFocus.simulateFocusChange(true)        // first condition → paused (fires: count=1)
        mockCarPlay.simulateCarPlayChange(true)    // second condition, still paused (must NOT fire)

        XCTAssertEqual(callbackCount, 1, "Callback must not fire when isPaused value does not change")
    }

    // MARK: - Settings Toggle Re-evaluation (Issue #26)

    func test_pauseDuringFocus_toggledOff_whileFocusActive_resumesImmediately() {
        settings.pauseDuringFocus = true
        mockFocus.simulateFocusChange(true)
        XCTAssertTrue(sut.isPaused, "Precondition: must be paused with focus active")

        settings.pauseDuringFocus = false

        XCTAssertFalse(sut.isPaused, "Disabling pauseDuringFocus while focus is still active must immediately resume")
    }

    func test_pauseWhileDriving_toggledOff_whileDrivingActive_resumesImmediately() {
        settings.pauseWhileDriving = true
        mockDriving.simulateDrivingChange(true)
        XCTAssertTrue(sut.isPaused, "Precondition: must be paused with driving active")

        settings.pauseWhileDriving = false

        XCTAssertFalse(
            sut.isPaused,
            "Disabling pauseWhileDriving while driving is still active must immediately resume"
        )
    }

    func test_pauseWhileDriving_toggledOff_whileCarPlayActive_resumesImmediately() {
        settings.pauseWhileDriving = true
        mockCarPlay.simulateCarPlayChange(true)
        XCTAssertTrue(sut.isPaused, "Precondition: must be paused with CarPlay active")

        settings.pauseWhileDriving = false

        XCTAssertFalse(
            sut.isPaused,
            "Disabling pauseWhileDriving while CarPlay is still active must immediately resume"
        )
    }

    func test_pauseDuringFocus_toggledOn_whileFocusActive_pausesImmediately() {
        settings.pauseDuringFocus = false
        mockFocus.simulateFocusChange(true)
        XCTAssertFalse(sut.isPaused, "Precondition: must not be paused when setting is off")

        settings.pauseDuringFocus = true

        XCTAssertTrue(sut.isPaused, "Enabling pauseDuringFocus while focus is already active must immediately pause")
    }

    func test_settingToggle_withNoActiveCondition_doesNotChangePauseState() {
        settings.pauseDuringFocus = true
        XCTAssertFalse(sut.isPaused, "Precondition: not paused — no conditions active")

        settings.pauseDuringFocus = false

        XCTAssertFalse(sut.isPaused, "Toggling setting with no active condition must not change isPaused")
    }

    func test_pauseDuringFocus_toggledOff_withMultipleConditions_remainsPausedIfOtherActive() {
        settings.pauseDuringFocus = true
        settings.pauseWhileDriving = true
        mockFocus.simulateFocusChange(true)
        mockDriving.simulateDrivingChange(true)
        XCTAssertTrue(sut.isPaused, "Precondition: paused by both conditions")

        settings.pauseDuringFocus = false

        XCTAssertTrue(sut.isPaused, "Must remain paused — driving condition is still active")
    }
}

// MARK: - SettingsStore Pause-Flag Tests
//
// Verifies the two new SettingsStore properties added for PauseConditionManager:
//   epr.pauseDuringFocus   (default true)
//   epr.pauseWhileDriving  (default true)

final class SettingsPauseFlagsTests: XCTestCase {

    var mockPersistence: MockSettingsPersisting!
    var sut: SettingsStore!

    override func setUp() {
        super.setUp()
        mockPersistence = MockSettingsPersisting()
        sut = SettingsStore(store: mockPersistence)
    }

    override func tearDown() {
        sut = nil
        mockPersistence = nil
        super.tearDown()
    }

    // MARK: - Defaults

    func test_pauseDuringFocus_default_isTrue() {
        XCTAssertTrue(sut.pauseDuringFocus, "pauseDuringFocus must default to true (spec: opt-in Focus pause is on)")
    }

    func test_pauseWhileDriving_default_isTrue() {
        XCTAssertTrue(
            sut.pauseWhileDriving,
            "pauseWhileDriving must default to true (spec: opt-in driving pause is on)"
        )
    }

    // MARK: - Persistence

    func test_pauseDuringFocus_whenSetFalse_persists() {
        sut.pauseDuringFocus = false
        let reloaded = SettingsStore(store: mockPersistence)
        XCTAssertFalse(reloaded.pauseDuringFocus, "pauseDuringFocus=false must survive a SettingsStore reload")
    }

    func test_pauseWhileDriving_whenSetFalse_persists() {
        sut.pauseWhileDriving = false
        let reloaded = SettingsStore(store: mockPersistence)
        XCTAssertFalse(reloaded.pauseWhileDriving, "pauseWhileDriving=false must survive a SettingsStore reload")
    }

    func test_pauseDuringFocus_whenSet_writesToPersistence() {
        sut.pauseDuringFocus = false
        XCTAssertTrue(
            mockPersistence.hasValue(forKey: "epr.pauseDuringFocus"),
            "Setting pauseDuringFocus must write to the persistence store immediately"
        )
    }

    func test_pauseWhileDriving_whenSet_writesToPersistence() {
        sut.pauseWhileDriving = false
        XCTAssertTrue(
            mockPersistence.hasValue(forKey: "epr.pauseWhileDriving"),
            "Setting pauseWhileDriving must write to the persistence store immediately"
        )
    }

    func test_pauseFlags_areIndependent() {
        sut.pauseDuringFocus = false
        XCTAssertTrue(sut.pauseWhileDriving, "Changing pauseDuringFocus must not affect pauseWhileDriving")
    }
}

@testable import EyePostureReminder
import XCTest

// MARK: - Mock Detectors
//
// These satisfy the protocols defined in PauseConditionManager.swift.
// Named to match the production protocols exactly: FocusStatusDetecting,
// CarPlayDetecting, DrivingActivityDetecting.

final class MockFocusStatusDetector: FocusStatusDetecting {

    private(set) var isFocused: Bool = false
    var onFocusChanged: ((Bool) -> Void)?

    private(set) var startMonitoringCallCount = 0
    private(set) var stopMonitoringCallCount = 0

    func startMonitoring() { startMonitoringCallCount += 1 }
    func stopMonitoring()  { stopMonitoringCallCount += 1 }

    /// Test helper — updates state and fires the registered callback.
    func simulateFocusChange(_ focused: Bool) {
        isFocused = focused
        onFocusChanged?(focused)
    }
}

final class MockCarPlayDetector: CarPlayDetecting {

    private(set) var isCarPlayActive: Bool = false
    var onCarPlayChanged: ((Bool) -> Void)?

    private(set) var startMonitoringCallCount = 0
    private(set) var stopMonitoringCallCount = 0

    func startMonitoring() { startMonitoringCallCount += 1 }
    func stopMonitoring()  { stopMonitoringCallCount += 1 }

    func simulateCarPlayChange(_ active: Bool) {
        isCarPlayActive = active
        onCarPlayChanged?(active)
    }
}

final class MockDrivingActivityDetector: DrivingActivityDetecting {

    private(set) var isDriving: Bool = false
    var onDrivingChanged: ((Bool) -> Void)?

    private(set) var startMonitoringCallCount = 0
    private(set) var stopMonitoringCallCount = 0

    func startMonitoring() { startMonitoringCallCount += 1 }
    func stopMonitoring()  { stopMonitoringCallCount += 1 }

    func simulateDrivingChange(_ driving: Bool) {
        isDriving = driving
        onDrivingChanged?(driving)
    }
}

// MARK: - PauseConditionManagerTests

/// Unit tests for `PauseConditionManager`.
///
/// All three live detectors are replaced with mocks so no system APIs are hit.
/// State changes are triggered synchronously via mock `simulate*` helpers, which
/// fire the same callbacks the live detectors would fire.
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

    func testInitialState_IsNotPaused() {
        let freshSUT = makeSUT()
        XCTAssertFalse(freshSUT.isPaused, "PauseConditionManager must not be paused on init — no conditions active yet")
    }

    // MARK: - Focus Mode

    func testFocusModeActive_PausesReminders() {
        settings.pauseDuringFocus = true
        mockFocus.simulateFocusChange(true)
        XCTAssertTrue(sut.isPaused, "Focus active with pauseDuringFocus=true must set isPaused=true")
    }

    func testFocusModeInactive_DoesNotPause() {
        settings.pauseDuringFocus = true
        mockFocus.simulateFocusChange(false)
        XCTAssertFalse(sut.isPaused, "Focus inactive must not pause reminders")
    }

    /// Auth denied → `LiveFocusStatusDetector` never fires the callback.
    /// No callback means no condition is ever inserted, so `isPaused` stays `false`.
    /// This is the "fail open" contract: unknown state = don't pause.
    func testFocusAuthDenied_FailsOpen() {
        settings.pauseDuringFocus = true
        // No simulate call — detector never fires because auth was denied.
        XCTAssertFalse(sut.isPaused, "Auth-denied focus detector must not trigger a pause (fail-open)")
    }

    func testFocusPauseDisabledInSettings_IgnoresFocus() {
        settings.pauseDuringFocus = false
        mockFocus.simulateFocusChange(true)
        XCTAssertFalse(sut.isPaused, "Focus signal must be ignored when pauseDuringFocus is disabled")
    }

    // MARK: - CarPlay

    func testCarPlayConnected_PausesReminders() {
        settings.pauseWhileDriving = true
        mockCarPlay.simulateCarPlayChange(true)
        XCTAssertTrue(sut.isPaused, "CarPlay connected with pauseWhileDriving=true must set isPaused=true")
    }

    func testCarPlayDisconnected_DoesNotPause() {
        settings.pauseWhileDriving = true
        mockCarPlay.simulateCarPlayChange(false)
        XCTAssertFalse(sut.isPaused, "CarPlay disconnected must not pause reminders")
    }

    // MARK: - Driving

    func testDrivingDetected_PausesReminders() {
        settings.pauseWhileDriving = true
        mockDriving.simulateDrivingChange(true)
        XCTAssertTrue(sut.isPaused, "Driving detected with pauseWhileDriving=true must set isPaused=true")
    }

    func testDrivingNotDetected_DoesNotPause() {
        settings.pauseWhileDriving = true
        mockDriving.simulateDrivingChange(false)
        XCTAssertFalse(sut.isPaused, "Driving=false must not pause reminders")
    }

    func testDrivingPauseDisabledInSettings_IgnoresDriving() {
        settings.pauseWhileDriving = false
        mockDriving.simulateDrivingChange(true)
        XCTAssertFalse(sut.isPaused, "Driving signal must be ignored when pauseWhileDriving is disabled")
    }

    // MARK: - Multiple Conditions

    func testMultipleConditionsActive_StillPaused() {
        settings.pauseDuringFocus = true
        settings.pauseWhileDriving = true
        mockFocus.simulateFocusChange(true)
        mockDriving.simulateDrivingChange(true)
        XCTAssertTrue(sut.isPaused, "Multiple active conditions must keep isPaused=true")
    }

    func testOneConditionClears_StillPausedIfOtherActive() {
        settings.pauseDuringFocus = true
        settings.pauseWhileDriving = true
        mockFocus.simulateFocusChange(true)
        mockDriving.simulateDrivingChange(true)

        mockFocus.simulateFocusChange(false)

        XCTAssertTrue(sut.isPaused, "Must remain paused while at least one condition is still active")
    }

    func testAllConditionsClear_Resumes() {
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

    func testPauseAndSnooze_ResumeOnlyWhenBothClear() {
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

    func testSnoozeActiveWhenPauseClears_StaysSnooze() {
        // Snooze lives in SettingsStore, not in PauseConditionManager.
        // When snooze is set and no pause conditions are active, isPaused is still false.
        settings.snoozedUntil = Date().addingTimeInterval(300)

        XCTAssertFalse(sut.isPaused, "Snooze alone must not affect PauseConditionManager.isPaused")
        let snoozeActive = settings.snoozedUntil.map { $0 > Date() } ?? false
        XCTAssertTrue(snoozeActive, "Snooze flag is set in SettingsStore — consumer must respect it independently")
    }

    // MARK: - Lifecycle

    func testStartMonitoring_RegistersObservers() {
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

    func testStartMonitoring_RegistersCallbacks() {
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

    func testStopMonitoring_CleansUp() {
        // setUp already called startMonitoring() on sut.
        sut.stopMonitoring()

        XCTAssertEqual(mockFocus.stopMonitoringCallCount, 1, "focusDetector.stopMonitoring() must be called")
        XCTAssertEqual(mockCarPlay.stopMonitoringCallCount, 1, "carPlayDetector.stopMonitoring() must be called")
        XCTAssertEqual(mockDriving.stopMonitoringCallCount, 1, "drivingDetector.stopMonitoring() must be called")

        // Prevent double-stop in tearDown.
        sut = nil
    }

    func testCallbackFiredOnStateChange() {
        settings.pauseDuringFocus = true
        var callbackValues: [Bool] = []
        sut.onPauseStateChanged = { callbackValues.append($0) }

        mockFocus.simulateFocusChange(true)   // paused
        mockFocus.simulateFocusChange(false)  // unpaused

        XCTAssertEqual(callbackValues, [true, false], "onPauseStateChanged must fire for each state flip")
    }

    func testCallbackNotFiredWhenStateUnchanged() {
        settings.pauseDuringFocus = true
        settings.pauseWhileDriving = true
        var callbackCount = 0
        sut.onPauseStateChanged = { _ in callbackCount += 1 }

        mockFocus.simulateFocusChange(true)        // first condition → paused (fires: count=1)
        mockCarPlay.simulateCarPlayChange(true)    // second condition, still paused (must NOT fire)

        XCTAssertEqual(callbackCount, 1, "Callback must not fire when isPaused value does not change")
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

    func testPauseDuringFocusDefault_IsTrue() {
        XCTAssertTrue(sut.pauseDuringFocus, "pauseDuringFocus must default to true (spec: opt-in Focus pause is on)")
    }

    func testPauseWhileDrivingDefault_IsTrue() {
        XCTAssertTrue(
            sut.pauseWhileDriving,
            "pauseWhileDriving must default to true (spec: opt-in driving pause is on)"
        )
    }

    // MARK: - Persistence

    func testPauseDuringFocusToggle_Persists() {
        sut.pauseDuringFocus = false
        let reloaded = SettingsStore(store: mockPersistence)
        XCTAssertFalse(reloaded.pauseDuringFocus, "pauseDuringFocus=false must survive a SettingsStore reload")
    }

    func testPauseWhileDrivingToggle_Persists() {
        sut.pauseWhileDriving = false
        let reloaded = SettingsStore(store: mockPersistence)
        XCTAssertFalse(reloaded.pauseWhileDriving, "pauseWhileDriving=false must survive a SettingsStore reload")
    }

    func testPauseDuringFocusToggle_WritesToPersistence() {
        sut.pauseDuringFocus = false
        XCTAssertTrue(
            mockPersistence.hasValue(forKey: "epr.pauseDuringFocus"),
            "Setting pauseDuringFocus must write to the persistence store immediately"
        )
    }

    func testPauseWhileDrivingToggle_WritesToPersistence() {
        sut.pauseWhileDriving = false
        XCTAssertTrue(
            mockPersistence.hasValue(forKey: "epr.pauseWhileDriving"),
            "Setting pauseWhileDriving must write to the persistence store immediately"
        )
    }

    func testPauseFlags_IndependentOfEachOther() {
        sut.pauseDuringFocus = false
        XCTAssertTrue(sut.pauseWhileDriving, "Changing pauseDuringFocus must not affect pauseWhileDriving")
    }
}

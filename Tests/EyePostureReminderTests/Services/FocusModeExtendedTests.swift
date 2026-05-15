import XCTest

@testable import EyePostureReminder

// MARK: - FocusModeExtendedTests
//
// PauseConditionManager-level tests for focus mode edge cases.
// Uses mock detectors defined in PauseConditionManagerTests.swift (same test target).
// NOT @MainActor — was not actor-isolated prior to issue #55.
// Updated to @MainActor because PauseConditionManager is now @MainActor-isolated.
@MainActor
final class FocusModeExtendedTests: XCTestCase {

    var mockPersistence: MockSettingsPersisting!
    var settings: SettingsStore!
    var mockFocus: MockFocusStatusDetector!
    var mockCarPlay: MockCarPlayDetector!
    var mockDriving: MockDrivingActivityDetector!
    var manager: PauseConditionManager!

    override func setUp() {
        super.setUp()
        mockPersistence = MockSettingsPersisting()
        settings = SettingsStore(store: mockPersistence)
        mockFocus   = MockFocusStatusDetector()
        mockCarPlay = MockCarPlayDetector()
        mockDriving = MockDrivingActivityDetector()
        manager = PauseConditionManager(
            settings: settings,
            focusDetector: mockFocus,
            carPlayDetector: mockCarPlay,
            drivingDetector: mockDriving
        )
        manager.startMonitoring()
        settings.pauseDuringFocus = true
    }

    override func tearDown() {
        manager?.stopMonitoring()
        manager = nil
        mockDriving = nil
        mockCarPlay = nil
        mockFocus = nil
        settings = nil
        mockPersistence = nil
        super.tearDown()
    }

    // MARK: - Rapid Focus Toggle: Coalesce Behaviour

    /// After an even number of on/off cycles the net state is "not focused" → not paused.
    func test_rapidFocusToggle_evenCycles_resultNotPaused() {
        for _ in 0..<10 {
            mockFocus.simulateFocusChange(true)
            mockFocus.simulateFocusChange(false)
        }
        XCTAssertFalse(
            manager.isPaused,
            "After 10 complete on/off cycles the manager must not be paused")
    }

    /// After cycles that end on focus=true the net state is "paused".
    func test_rapidFocusToggle_endsOnFocusTrue_resultPaused() {
        for _ in 0..<5 {
            mockFocus.simulateFocusChange(false)
            mockFocus.simulateFocusChange(true)
        }
        XCTAssertTrue(
            manager.isPaused,
            "Rapid toggling ending on focus=true must leave manager paused")
    }

    /// Each state flip (paused ↔ unpaused) must produce exactly one callback.
    /// Three on/off cycles → 6 callbacks: [true, false, true, false, true, false].
    func test_rapidFocusToggle_callbacksMatchStateFlips() {
        var callbackValues: [Bool] = []
        manager.onPauseStateChanged = { callbackValues.append($0) }

        for _ in 0..<3 {
            mockFocus.simulateFocusChange(true)    // → paused
            mockFocus.simulateFocusChange(false)   // → unpaused
        }

        XCTAssertEqual(
            callbackValues.count,
            6,
            "3 on/off cycles must fire exactly 6 callbacks (one per state flip)")
        XCTAssertEqual(
            callbackValues,
            [true, false, true, false, true, false],
            "Callback sequence must be strictly alternating true/false")
    }

    /// Rapid identical events (no state change) must not produce extra callbacks.
    func test_rapidFocusToggle_duplicateEvents_noExtraCallbacks() {
        var callbackCount = 0
        manager.onPauseStateChanged = { _ in callbackCount += 1 }

        // Fire "focus=true" five times — only the first changes state.
        for _ in 0..<5 {
            mockFocus.simulateFocusChange(true)
        }

        XCTAssertEqual(
            callbackCount,
            1,
            "Repeated focus=true events must only fire one callback (state unchanged after first)")
    }

    // MARK: - Focus Mode While App is in Background (Simulated)

    /// PauseConditionManager continues monitoring through detector callbacks regardless
    /// of app foreground/background state. Simulated via synchronous mock.
    func test_focusChange_whileBackground_setsIsPaused() {
        mockFocus.simulateFocusChange(true)
        XCTAssertTrue(
            manager.isPaused,
            "Focus callback arriving in background state must set isPaused=true")
    }

    func test_focusClears_whileBackground_clearsIsPaused() {
        mockFocus.simulateFocusChange(true)
        mockFocus.simulateFocusChange(false)
        XCTAssertFalse(
            manager.isPaused,
            "Focus clearing while app is in background must set isPaused=false")
    }

    func test_focusChange_whileBackground_firesCallback() {
        var callbackFired = false
        manager.onPauseStateChanged = { _ in callbackFired = true }
        mockFocus.simulateFocusChange(true)
        XCTAssertTrue(
            callbackFired,
            "onPauseStateChanged must fire for focus change arriving during background-like conditions")
    }

    // MARK: - Settings Change Mid-Monitoring: Disable pauseDuringFocus

    /// The setting change triggers immediate re-evaluation of active conditions (Issues #26).
    /// Subsequent callbacks with the new setting value also correctly ignore the condition.
    /// The following sequence verifies the final settled state.
    func test_disablePauseDuringFocus_midMonitoring_nextCallbackIgnoresFocus() {
        // Activate focus
        mockFocus.simulateFocusChange(true)
        XCTAssertTrue(manager.isPaused, "Pre-condition: paused with focus=true, setting=true")

        // Disable the setting mid-monitoring
        settings.pauseDuringFocus = false

        // Simulate focus turning off then back on — new callbacks use setting=false
        mockFocus.simulateFocusChange(false)  // callback: setting=false → not inserted
        mockFocus.simulateFocusChange(true)   // callback: setting=false → not inserted

        XCTAssertFalse(
            manager.isPaused,
            "After disabling pauseDuringFocus and re-triggering focus, manager must not be paused")
    }

    func test_disablePauseDuringFocus_midMonitoring_subsequentCallbackDoesNotResume_incorrectly() {
        // Ensure that after disable + re-trigger, isPaused stays false even with focus=true.
        mockFocus.simulateFocusChange(true)
        settings.pauseDuringFocus = false
        mockFocus.simulateFocusChange(false)
        mockFocus.simulateFocusChange(true)

        XCTAssertFalse(manager.isPaused)

        // Firing false again also must not unexpectedly change state
        mockFocus.simulateFocusChange(false)
        XCTAssertFalse(
            manager.isPaused,
            "isPaused must remain false after multiple focus callbacks with setting=false")
    }

    // MARK: - Settings Change Mid-Monitoring: Enable pauseDuringFocus

    /// Re-enabling pauseDuringFocus while monitoring is active takes effect on the next
    /// callback; existing activeConditions are not retroactively re-evaluated.
    func test_enablePauseDuringFocus_midMonitoring_nextCallbackRespects() {
        settings.pauseDuringFocus = false

        // Focus fires but is ignored
        mockFocus.simulateFocusChange(true)
        XCTAssertFalse(manager.isPaused, "Pre-condition: focus with setting=false must not pause")

        // Re-enable setting
        settings.pauseDuringFocus = true

        // Next callback with focus=true must now pause
        mockFocus.simulateFocusChange(false)
        mockFocus.simulateFocusChange(true)

        XCTAssertTrue(
            manager.isPaused,
            "After re-enabling pauseDuringFocus mid-monitoring, next focus=true callback must pause")
    }

    // MARK: - Focus + Another Condition Interaction

    /// Focus and driving both active → one condition clearing must not resume.
    func test_focusAndDriving_focusClears_drivingKeepsPaused() {
        settings.pauseWhileDriving = true
        mockFocus.simulateFocusChange(true)
        mockDriving.simulateDrivingChange(true)
        XCTAssertTrue(manager.isPaused)

        var callbackValues: [Bool] = []
        manager.onPauseStateChanged = { callbackValues.append($0) }

        mockFocus.simulateFocusChange(false)

        XCTAssertTrue(
            manager.isPaused,
            "Clearing focus must not resume when driving is still active")
        XCTAssertTrue(
            callbackValues.isEmpty,
            "onPauseStateChanged must not fire when state remains paused after one condition clears")
    }
}

// MARK: - FocusModeSettingsViewModelTests removed (#755 Phase B)
//
// The `SettingsViewModel.pauseDuringFocus` getter/setter coverage that
// previously lived in `FocusModeSettingsViewModelTests` was removed when
// `SettingsViewModel` was deleted. The `pauseDuringFocus` binding is now
// driven from `SettingsView` via `@AppStorage(SettingsStore.Keys.pauseDuringFocus)`
// and exercised through `SettingsStore` directly.
//
// Rewrite as `SettingsFeature` TestStore coverage once the reducer owns the
// `pauseDuringFocus` analytics emission — tracked under #679.

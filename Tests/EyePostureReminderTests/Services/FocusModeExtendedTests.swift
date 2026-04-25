@testable import EyePostureReminder
import XCTest

// MARK: - FocusModeExtendedTests
//
// PauseConditionManager-level tests for focus mode edge cases.
// Uses mock detectors defined in PauseConditionManagerTests.swift (same test target).
// NOT @MainActor — PauseConditionManager and SettingsStore are not actor-isolated.

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

    /// Disabling pauseDuringFocus mid-monitoring takes effect on the NEXT callback.
    /// The .focusMode condition stays in activeConditions until a callback re-evaluates it.
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

// MARK: - FocusModeSettingsViewModelTests
//
// @MainActor tests for SettingsViewModel's `pauseDuringFocus` binding.
// Verifies the VM correctly bridges the SettingsStore property for the Settings UI.

@MainActor
final class FocusModeSettingsViewModelTests: XCTestCase {

    var mockPersistence: MockSettingsPersisting!
    var settings: SettingsStore!
    var mockScheduler: MockReminderScheduler!
    var vm: SettingsViewModel!

    override func setUp() async throws {
        try await super.setUp()
        mockPersistence = MockSettingsPersisting()
        settings        = SettingsStore(store: mockPersistence)
        mockScheduler   = MockReminderScheduler()
        vm              = SettingsViewModel(settings: settings, scheduler: mockScheduler)
    }

    override func tearDown() async throws {
        vm = nil
        mockScheduler = nil
        settings = nil
        mockPersistence = nil
        try await super.tearDown()
    }

    // MARK: - Getter

    func test_vm_pauseDuringFocus_getter_trueWhenSettingsTrue() {
        settings.pauseDuringFocus = true
        XCTAssertTrue(
            vm.pauseDuringFocus,
            "VM.pauseDuringFocus getter must return true when settings.pauseDuringFocus=true")
    }

    func test_vm_pauseDuringFocus_getter_falseWhenSettingsFalse() {
        settings.pauseDuringFocus = false
        XCTAssertFalse(
            vm.pauseDuringFocus,
            "VM.pauseDuringFocus getter must return false when settings.pauseDuringFocus=false")
    }

    // MARK: - Setter

    func test_vm_pauseDuringFocus_setter_falseWritesToSettings() {
        settings.pauseDuringFocus = true
        vm.pauseDuringFocus = false
        XCTAssertFalse(
            settings.pauseDuringFocus,
            "Setting VM.pauseDuringFocus=false must immediately write false to SettingsStore")
    }

    func test_vm_pauseDuringFocus_setter_trueWritesToSettings() {
        settings.pauseDuringFocus = false
        vm.pauseDuringFocus = true
        XCTAssertTrue(
            settings.pauseDuringFocus,
            "Setting VM.pauseDuringFocus=true must immediately write true to SettingsStore")
    }

    func test_vm_pauseDuringFocus_setter_getterReflectsNewValue() {
        settings.pauseDuringFocus = true
        vm.pauseDuringFocus = false
        XCTAssertFalse(
            vm.pauseDuringFocus,
            "VM.pauseDuringFocus getter must immediately reflect the new value after setter call")
    }

    // MARK: - Settings Persistence Round-Trip

    func test_pauseDuringFocus_offToOn_roundTrip_survivesReload() {
        // Step 1: disable
        vm.pauseDuringFocus = false
        // Step 2: re-enable via VM
        vm.pauseDuringFocus = true
        // Step 3: reload from same MockSettingsPersisting
        let reloaded = SettingsStore(store: mockPersistence)
        XCTAssertTrue(
            reloaded.pauseDuringFocus,
            "pauseDuringFocus=true must survive a SettingsStore reload after an off→on round-trip")
    }

    func test_pauseDuringFocus_false_survivesReload() {
        vm.pauseDuringFocus = false
        let reloaded = SettingsStore(store: mockPersistence)
        XCTAssertFalse(
            reloaded.pauseDuringFocus,
            "pauseDuringFocus=false must survive a SettingsStore reload")
    }

    func test_pauseDuringFocus_writesToPersistence_immediately() {
        vm.pauseDuringFocus = false
        XCTAssertTrue(
            mockPersistence.hasValue(forKey: "epr.pauseDuringFocus"),
            "Setting pauseDuringFocus must immediately write to MockSettingsPersisting")
    }

    // MARK: - Independence from pauseWhileDriving

    func test_pauseDuringFocus_doesNotAffect_pauseWhileDriving() {
        settings.pauseWhileDriving = true
        vm.pauseDuringFocus = false
        XCTAssertTrue(
            settings.pauseWhileDriving,
            "Changing pauseDuringFocus must not modify pauseWhileDriving")
    }

    func test_pauseWhileDriving_doesNotAffect_pauseDuringFocus() {
        settings.pauseDuringFocus = true
        vm.pauseWhileDriving = false
        XCTAssertTrue(
            settings.pauseDuringFocus,
            "Changing pauseWhileDriving must not modify pauseDuringFocus")
    }
}

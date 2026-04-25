@testable import EyePostureReminder
import XCTest

// MARK: - DrivingDetectionExtendedTests
//
// PauseConditionManager-level tests for driving detection edge cases.
// Uses mock detectors defined in PauseConditionManagerTests.swift (same test target).
// NOT @MainActor — PauseConditionManager and SettingsStore are not actor-isolated.

final class DrivingDetectionExtendedTests: XCTestCase {

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
        settings.pauseWhileDriving = true
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

    // MARK: - Both CarPlay AND Driving Active Simultaneously

    func test_carPlayAndDriving_bothActive_isPaused() {
        mockCarPlay.simulateCarPlayChange(true)
        mockDriving.simulateDrivingChange(true)

        XCTAssertTrue(
            manager.isPaused,
            "CarPlay AND driving both active must result in isPaused=true")
    }

    func test_carPlayAndDriving_carPlayFirst_thenDriving_isPaused() {
        mockCarPlay.simulateCarPlayChange(true)
        XCTAssertTrue(manager.isPaused, "Pre-condition: CarPlay alone must pause")

        mockDriving.simulateDrivingChange(true)
        XCTAssertTrue(
            manager.isPaused,
            "Adding driving while CarPlay is already active must keep isPaused=true")
    }

    func test_carPlayAndDriving_drivingFirst_thenCarPlay_isPaused() {
        mockDriving.simulateDrivingChange(true)
        XCTAssertTrue(manager.isPaused, "Pre-condition: driving alone must pause")

        mockCarPlay.simulateCarPlayChange(true)
        XCTAssertTrue(
            manager.isPaused,
            "Adding CarPlay while driving is already active must keep isPaused=true (additive)")
    }

    /// When both conditions are active, the callback fires only once (on first transition).
    /// Adding the second condition must not re-fire because isPaused does not change.
    func test_carPlayAndDriving_bothActive_callbackFiresOnceOnly() {
        var callbackCount = 0
        manager.onPauseStateChanged = { _ in callbackCount += 1 }

        mockCarPlay.simulateCarPlayChange(true)    // first condition → fires callback
        mockDriving.simulateDrivingChange(true)    // still paused → must NOT fire again

        XCTAssertEqual(
            callbackCount,
            1,
            "Callback must fire once when first condition activates, not again when second adds")
    }

    // MARK: - CarPlay Disconnects, Driving Still Active

    func test_carPlayDisconnects_drivingStillActive_remainsPaused() {
        mockCarPlay.simulateCarPlayChange(true)
        mockDriving.simulateDrivingChange(true)

        mockCarPlay.simulateCarPlayChange(false)

        XCTAssertTrue(
            manager.isPaused,
            "CarPlay disconnecting must NOT resume when driving is still active")
    }

    func test_carPlayDisconnects_drivingStillActive_callbackNotFired() {
        mockCarPlay.simulateCarPlayChange(true)
        mockDriving.simulateDrivingChange(true)

        var callbackValues: [Bool] = []
        manager.onPauseStateChanged = { callbackValues.append($0) }

        mockCarPlay.simulateCarPlayChange(false)

        XCTAssertTrue(
            callbackValues.isEmpty,
            "onPauseStateChanged must NOT fire when CarPlay disconnects but driving continues (isPaused unchanged)")
    }

    func test_carPlayDisconnects_thenDrivingStops_resumes() {
        mockCarPlay.simulateCarPlayChange(true)
        mockDriving.simulateDrivingChange(true)

        mockCarPlay.simulateCarPlayChange(false)   // driving still active
        XCTAssertTrue(manager.isPaused, "Must remain paused while driving continues")

        mockDriving.simulateDrivingChange(false)   // both gone → resume

        XCTAssertFalse(
            manager.isPaused,
            "Must resume only after both CarPlay AND driving have cleared")
    }

    func test_carPlayDisconnects_drivingStops_resumeCallbackFires() {
        mockCarPlay.simulateCarPlayChange(true)
        mockDriving.simulateDrivingChange(true)

        var callbackValues: [Bool] = []
        manager.onPauseStateChanged = { callbackValues.append($0) }

        mockCarPlay.simulateCarPlayChange(false)   // no state change
        mockDriving.simulateDrivingChange(false)   // all clear → resumes

        XCTAssertEqual(
            callbackValues,
            [false],
            "Resume callback (false) must fire exactly once when last active condition clears")
    }

    // MARK: - Driving Detected, Then CarPlay Connects

    func test_drivingActive_carPlayConnects_additive_stillPaused() {
        mockDriving.simulateDrivingChange(true)
        XCTAssertTrue(manager.isPaused, "Pre-condition: driving alone must pause")

        mockCarPlay.simulateCarPlayChange(true)
        XCTAssertTrue(
            manager.isPaused,
            "Adding CarPlay while driving must keep isPaused=true (additive conditions)")
    }

    func test_drivingStops_carPlayStillActive_remainsPaused() {
        mockDriving.simulateDrivingChange(true)
        mockCarPlay.simulateCarPlayChange(true)

        mockDriving.simulateDrivingChange(false)

        XCTAssertTrue(
            manager.isPaused,
            "Driving stopping must NOT resume when CarPlay is still connected")
    }

    func test_drivingStops_carPlayStillActive_noCallbackFired() {
        mockDriving.simulateDrivingChange(true)
        mockCarPlay.simulateCarPlayChange(true)

        var callbackValues: [Bool] = []
        manager.onPauseStateChanged = { callbackValues.append($0) }

        mockDriving.simulateDrivingChange(false)

        XCTAssertTrue(
            callbackValues.isEmpty,
            "onPauseStateChanged must NOT fire when driving stops but CarPlay remains active")
    }

    // MARK: - Settings Change Mid-Drive: Disable pauseWhileDriving

    /// Disabling pauseWhileDriving while actively driving takes effect on the next callback,
    /// not retroactively. This is documented expected behaviour for PauseConditionManager.
    func test_disablePauseWhileDriving_midDrive_nextCallbackIgnoresDriving() {
        mockDriving.simulateDrivingChange(true)
        XCTAssertTrue(manager.isPaused, "Pre-condition: paused with driving=true, setting=true")

        settings.pauseWhileDriving = false

        // Next callbacks evaluate with setting=false
        mockDriving.simulateDrivingChange(false)  // callback: setting=false → .driving not inserted
        mockDriving.simulateDrivingChange(true)   // callback: setting=false → .driving not inserted

        XCTAssertFalse(
            manager.isPaused,
            "After disabling pauseWhileDriving and re-triggering driving, manager must not be paused")
    }

    func test_disablePauseWhileDriving_midCarPlay_nextCarPlayCallbackIgnored() {
        mockCarPlay.simulateCarPlayChange(true)
        XCTAssertTrue(manager.isPaused, "Pre-condition: paused with CarPlay=true, setting=true")

        settings.pauseWhileDriving = false

        mockCarPlay.simulateCarPlayChange(false)  // setting=false → .carPlay not inserted
        mockCarPlay.simulateCarPlayChange(true)   // setting=false → .carPlay not inserted

        XCTAssertFalse(
            manager.isPaused,
            "After disabling pauseWhileDriving and re-triggering CarPlay, manager must not be paused")
    }

    func test_disablePauseWhileDriving_withBothConditionsActive_nextCallbacksClear() {
        mockCarPlay.simulateCarPlayChange(true)
        mockDriving.simulateDrivingChange(true)
        XCTAssertTrue(manager.isPaused)

        settings.pauseWhileDriving = false

        // Re-trigger both to evaluate with new setting
        mockCarPlay.simulateCarPlayChange(false)
        mockCarPlay.simulateCarPlayChange(true)
        mockDriving.simulateDrivingChange(false)
        mockDriving.simulateDrivingChange(true)

        XCTAssertFalse(
            manager.isPaused,
            "After disabling pauseWhileDriving, all subsequent driving callbacks must be ignored")
    }

    // MARK: - Settings Change Mid-Drive: Enable pauseWhileDriving

    func test_enablePauseWhileDriving_midMonitoring_nextCallbackRespects() {
        settings.pauseWhileDriving = false

        mockDriving.simulateDrivingChange(true)
        XCTAssertFalse(manager.isPaused, "Pre-condition: driving with setting=false must not pause")

        settings.pauseWhileDriving = true

        // Trigger new callback — now evaluated with setting=true
        mockDriving.simulateDrivingChange(false)
        mockDriving.simulateDrivingChange(true)

        XCTAssertTrue(
            manager.isPaused,
            "After re-enabling pauseWhileDriving, next driving=true callback must pause")
    }

    func test_enablePauseWhileDriving_midMonitoring_carPlayAlsoRespects() {
        settings.pauseWhileDriving = false

        mockCarPlay.simulateCarPlayChange(true)
        XCTAssertFalse(manager.isPaused, "Pre-condition: CarPlay with setting=false must not pause")

        settings.pauseWhileDriving = true

        mockCarPlay.simulateCarPlayChange(false)
        mockCarPlay.simulateCarPlayChange(true)

        XCTAssertTrue(
            manager.isPaused,
            "After re-enabling pauseWhileDriving, next CarPlay=true callback must pause")
    }

    // MARK: - Driving Detection Lifecycle

    /// Rapid driving on/off cycles converge correctly to the last state.
    func test_rapidDrivingToggle_evenCycles_notPaused() {
        for _ in 0..<8 {
            mockDriving.simulateDrivingChange(true)
            mockDriving.simulateDrivingChange(false)
        }
        XCTAssertFalse(
            manager.isPaused,
            "After 8 driving on/off cycles the manager must not be paused")
    }

    func test_rapidCarPlayToggle_evenCycles_notPaused() {
        for _ in 0..<8 {
            mockCarPlay.simulateCarPlayChange(true)
            mockCarPlay.simulateCarPlayChange(false)
        }
        XCTAssertFalse(
            manager.isPaused,
            "After 8 CarPlay connect/disconnect cycles the manager must not be paused")
    }

    func test_rapidDrivingToggle_endsOnTrue_isPaused() {
        for _ in 0..<5 {
            mockDriving.simulateDrivingChange(false)
            mockDriving.simulateDrivingChange(true)
        }
        XCTAssertTrue(
            manager.isPaused,
            "Rapid driving toggles ending on driving=true must leave manager paused")
    }
}

// MARK: - DrivingSettingsViewModelTests
//
// @MainActor tests for SettingsViewModel's `pauseWhileDriving` binding.
// Verifies the VM correctly bridges the SettingsStore property for the Settings UI.

@MainActor
final class DrivingSettingsViewModelTests: XCTestCase {

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

    func test_vm_pauseWhileDriving_getter_trueWhenSettingsTrue() {
        settings.pauseWhileDriving = true
        XCTAssertTrue(
            vm.pauseWhileDriving,
            "VM.pauseWhileDriving getter must return true when settings.pauseWhileDriving=true")
    }

    func test_vm_pauseWhileDriving_getter_falseWhenSettingsFalse() {
        settings.pauseWhileDriving = false
        XCTAssertFalse(
            vm.pauseWhileDriving,
            "VM.pauseWhileDriving getter must return false when settings.pauseWhileDriving=false")
    }

    // MARK: - Setter

    func test_vm_pauseWhileDriving_setter_falseWritesToSettings() {
        settings.pauseWhileDriving = true
        vm.pauseWhileDriving = false
        XCTAssertFalse(
            settings.pauseWhileDriving,
            "Setting VM.pauseWhileDriving=false must immediately write false to SettingsStore")
    }

    func test_vm_pauseWhileDriving_setter_trueWritesToSettings() {
        settings.pauseWhileDriving = false
        vm.pauseWhileDriving = true
        XCTAssertTrue(
            settings.pauseWhileDriving,
            "Setting VM.pauseWhileDriving=true must immediately write true to SettingsStore")
    }

    func test_vm_pauseWhileDriving_setter_getterReflectsNewValue() {
        settings.pauseWhileDriving = true
        vm.pauseWhileDriving = false
        XCTAssertFalse(
            vm.pauseWhileDriving,
            "VM.pauseWhileDriving getter must immediately reflect the new value after setter call")
    }

    // MARK: - Settings Persistence Round-Trip

    func test_pauseWhileDriving_false_survivesReload() {
        vm.pauseWhileDriving = false
        let reloaded = SettingsStore(store: mockPersistence)
        XCTAssertFalse(
            reloaded.pauseWhileDriving,
            "pauseWhileDriving=false must survive a SettingsStore reload")
    }

    func test_pauseWhileDriving_offToOn_roundTrip_survivesReload() {
        vm.pauseWhileDriving = false
        vm.pauseWhileDriving = true
        let reloaded = SettingsStore(store: mockPersistence)
        XCTAssertTrue(
            reloaded.pauseWhileDriving,
            "pauseWhileDriving=true must survive a SettingsStore reload after an off→on round-trip")
    }

    func test_pauseWhileDriving_writesToPersistence_immediately() {
        vm.pauseWhileDriving = false
        XCTAssertTrue(
            mockPersistence.hasValue(forKey: "epr.pauseWhileDriving"),
            "Setting pauseWhileDriving must immediately write to MockSettingsPersisting")
    }

    // MARK: - Independence from pauseDuringFocus

    func test_pauseWhileDriving_doesNotAffect_pauseDuringFocus() {
        settings.pauseDuringFocus = true
        vm.pauseWhileDriving = false
        XCTAssertTrue(
            settings.pauseDuringFocus,
            "Changing pauseWhileDriving must not modify pauseDuringFocus")
    }

    func test_pauseDuringFocus_doesNotAffect_pauseWhileDriving() {
        settings.pauseWhileDriving = true
        vm.pauseDuringFocus = false
        XCTAssertTrue(
            settings.pauseWhileDriving,
            "Changing pauseDuringFocus must not modify pauseWhileDriving")
    }
}

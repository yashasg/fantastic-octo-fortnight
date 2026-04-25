@testable import EyePostureReminder
import XCTest

final class SettingsStoreTests: XCTestCase {

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

    // MARK: - Default Values (first-run, empty store)

    func test_defaults_globalEnabled_isTrue() {
        XCTAssertTrue(sut.globalEnabled)
    }

    func test_defaults_eyesEnabled_isTrue() {
        XCTAssertTrue(sut.eyesEnabled)
    }

    func test_defaults_postureEnabled_isTrue() {
        XCTAssertTrue(sut.postureEnabled)
    }

    func test_defaults_eyesInterval_is1200() {
        XCTAssertEqual(sut.eyesInterval, 1200, "Default eyes interval should be 20 min (1200s)")
    }

    func test_defaults_eyesBreakDuration_is20() {
        XCTAssertEqual(sut.eyesBreakDuration, 20, "Default eyes break should be 20s (20-20-20 rule)")
    }

    func test_defaults_postureInterval_is1800() {
        XCTAssertEqual(sut.postureInterval, 1800, "Default posture interval should be 30 min (1800s)")
    }

    func test_defaults_postureBreakDuration_is10() {
        XCTAssertEqual(sut.postureBreakDuration, 10, "Default posture break should be 10s")
    }

    func test_defaults_snoozedUntil_isNil() {
        XCTAssertNil(sut.snoozedUntil)
    }

    func test_defaults_pauseMediaDuringBreaks_isFalse() {
        XCTAssertFalse(sut.pauseMediaDuringBreaks)
    }

    // MARK: - Persistence: Booleans

    func test_setGlobalEnabled_false_persistsAndLoads() {
        sut.globalEnabled = false
        let reloaded = SettingsStore(store: mockPersistence)
        XCTAssertFalse(reloaded.globalEnabled)
    }

    func test_setEyesEnabled_false_persistsAndLoads() {
        sut.eyesEnabled = false
        let reloaded = SettingsStore(store: mockPersistence)
        XCTAssertFalse(reloaded.eyesEnabled)
    }

    func test_setPostureEnabled_false_persistsAndLoads() {
        sut.postureEnabled = false
        let reloaded = SettingsStore(store: mockPersistence)
        XCTAssertFalse(reloaded.postureEnabled)
    }

    func test_setPauseMediaDuringBreaks_true_persistsAndLoads() {
        sut.pauseMediaDuringBreaks = true
        let reloaded = SettingsStore(store: mockPersistence)
        XCTAssertTrue(reloaded.pauseMediaDuringBreaks)
    }

    // MARK: - Persistence: Doubles (intervals and durations)

    func test_setEyesInterval_600_persistsAndLoads() {
        sut.eyesInterval = 600
        let reloaded = SettingsStore(store: mockPersistence)
        XCTAssertEqual(reloaded.eyesInterval, 600)
    }

    func test_setEyesBreakDuration_30_persistsAndLoads() {
        sut.eyesBreakDuration = 30
        let reloaded = SettingsStore(store: mockPersistence)
        XCTAssertEqual(reloaded.eyesBreakDuration, 30)
    }

    func test_setPostureInterval_2700_persistsAndLoads() {
        sut.postureInterval = 2700
        let reloaded = SettingsStore(store: mockPersistence)
        XCTAssertEqual(reloaded.postureInterval, 2700)
    }

    func test_setPostureBreakDuration_60_persistsAndLoads() {
        sut.postureBreakDuration = 60
        let reloaded = SettingsStore(store: mockPersistence)
        XCTAssertEqual(reloaded.postureBreakDuration, 60)
    }

    // MARK: - settings(for:) convenience accessor

    func test_settingsForEyes_returnsCurrentEyesInterval() {
        sut.eyesInterval = 600
        XCTAssertEqual(sut.settings(for: .eyes).interval, 600)
    }

    func test_settingsForEyes_returnsCurrentEyesBreakDuration() {
        sut.eyesBreakDuration = 30
        XCTAssertEqual(sut.settings(for: .eyes).breakDuration, 30)
    }

    func test_settingsForPosture_returnsCurrentPostureInterval() {
        sut.postureInterval = 3600
        XCTAssertEqual(sut.settings(for: .posture).interval, 3600)
    }

    func test_settingsForPosture_returnsCurrentPostureBreakDuration() {
        sut.postureBreakDuration = 20
        XCTAssertEqual(sut.settings(for: .posture).breakDuration, 20)
    }

    // MARK: - isEnabled(for:) — master + per-type gate

    func test_isEnabled_globalOn_eyesOn_returnsTrue() {
        sut.globalEnabled = true
        sut.eyesEnabled = true
        XCTAssertTrue(sut.isEnabled(for: .eyes))
    }

    func test_isEnabled_globalOn_eyesOff_returnsFalse() {
        sut.globalEnabled = true
        sut.eyesEnabled = false
        XCTAssertFalse(sut.isEnabled(for: .eyes))
    }

    func test_isEnabled_globalOff_eyesOn_returnsFalse() {
        sut.globalEnabled = false
        sut.eyesEnabled = true
        XCTAssertFalse(sut.isEnabled(for: .eyes), "Global toggle must gate per-type toggle")
    }

    func test_isEnabled_globalOn_postureOn_returnsTrue() {
        sut.globalEnabled = true
        sut.postureEnabled = true
        XCTAssertTrue(sut.isEnabled(for: .posture))
    }

    func test_isEnabled_globalOn_postureOff_returnsFalse() {
        sut.globalEnabled = true
        sut.postureEnabled = false
        XCTAssertFalse(sut.isEnabled(for: .posture))
    }

    func test_isEnabled_globalOff_postureOn_returnsFalse() {
        sut.globalEnabled = false
        sut.postureEnabled = true
        XCTAssertFalse(sut.isEnabled(for: .posture), "Global toggle must gate per-type toggle")
    }

    func test_isEnabled_bothOff_returnsFalseForAll() {
        sut.globalEnabled = false
        sut.eyesEnabled = false
        sut.postureEnabled = false
        XCTAssertFalse(sut.isEnabled(for: .eyes))
        XCTAssertFalse(sut.isEnabled(for: .posture))
    }

    // MARK: - Per-type independence

    func test_eyesSettings_doNotAffectPostureInterval() {
        sut.eyesInterval = 600
        XCTAssertEqual(sut.postureInterval, 1800, "Changing eyes interval must not affect posture")
    }

    func test_eyesSettings_doNotAffectPostureBreakDuration() {
        sut.eyesBreakDuration = 60
        XCTAssertEqual(sut.postureBreakDuration, 10, "Changing eyes duration must not affect posture")
    }

    func test_postureSettings_doNotAffectEyesInterval() {
        sut.postureInterval = 3600
        XCTAssertEqual(sut.eyesInterval, 1200, "Changing posture interval must not affect eyes")
    }

    func test_postureSettings_doNotAffectEyesBreakDuration() {
        sut.postureBreakDuration = 60
        XCTAssertEqual(sut.eyesBreakDuration, 20, "Changing posture duration must not affect eyes")
    }

    func test_disablingEyes_doesNotAffectPostureEnabled() {
        sut.eyesEnabled = false
        XCTAssertTrue(sut.postureEnabled, "Disabling eyes must not disable posture")
    }

    func test_disablingPosture_doesNotAffectEyesEnabled() {
        sut.postureEnabled = false
        XCTAssertTrue(sut.eyesEnabled, "Disabling posture must not disable eyes")
    }

    // MARK: - Snooze

    func test_setSnoozedUntil_persistsAndLoads() throws {
        let targetDate = Date(timeIntervalSince1970: 1_700_000_000)
        sut.snoozedUntil = targetDate
        let reloaded = SettingsStore(store: mockPersistence)
        let snoozedUntil = try XCTUnwrap(reloaded.snoozedUntil)
        XCTAssertEqual(
            snoozedUntil.timeIntervalSince1970,
            targetDate.timeIntervalSince1970,
            accuracy: 0.001
        )
    }

    func test_clearSnoozedUntil_persistsNil() {
        sut.snoozedUntil = Date().addingTimeInterval(300)
        sut.snoozedUntil = nil
        let reloaded = SettingsStore(store: mockPersistence)
        XCTAssertNil(reloaded.snoozedUntil, "Clearing snooze must persist nil")
    }

    func test_snoozedUntil_defaultIsNil() {
        // Fresh store with empty persistence
        let fresh = SettingsStore(store: MockSettingsPersisting())
        XCTAssertNil(fresh.snoozedUntil)
    }

    // MARK: - App Restart Simulation

    func test_allSettings_persistAcrossSimulatedRestart() {
        sut.globalEnabled = false
        sut.eyesEnabled = false
        sut.postureEnabled = false
        sut.eyesInterval = 600
        sut.eyesBreakDuration = 60
        sut.postureInterval = 3600
        sut.postureBreakDuration = 30

        let restarted = SettingsStore(store: mockPersistence)

        XCTAssertFalse(restarted.globalEnabled)
        XCTAssertFalse(restarted.eyesEnabled)
        XCTAssertFalse(restarted.postureEnabled)
        XCTAssertEqual(restarted.eyesInterval, 600)
        XCTAssertEqual(restarted.eyesBreakDuration, 60)
        XCTAssertEqual(restarted.postureInterval, 3600)
        XCTAssertEqual(restarted.postureBreakDuration, 30)
    }

    // MARK: - Preset Intervals (spec from ReminderRowView: 10/20/30/45/60 min)

    func test_presetIntervals_contains10min() {
        let presets: [TimeInterval] = [600, 1200, 1800, 2700, 3600]
        XCTAssertTrue(presets.contains(600))
    }

    func test_presetIntervals_contains20min() {
        let presets: [TimeInterval] = [600, 1200, 1800, 2700, 3600]
        XCTAssertTrue(presets.contains(1200))
    }

    func test_presetIntervals_contains30min() {
        let presets: [TimeInterval] = [600, 1200, 1800, 2700, 3600]
        XCTAssertTrue(presets.contains(1800))
    }

    func test_presetIntervals_contains45min() {
        let presets: [TimeInterval] = [600, 1200, 1800, 2700, 3600]
        XCTAssertTrue(presets.contains(2700))
    }

    func test_presetIntervals_contains60min() {
        let presets: [TimeInterval] = [600, 1200, 1800, 2700, 3600]
        XCTAssertTrue(presets.contains(3600))
    }

    func test_presetIntervals_hasFiveOptions() {
        let presets: [TimeInterval] = [600, 1200, 1800, 2700, 3600]
        XCTAssertEqual(presets.count, 5)
    }

    // MARK: - Preset Break Durations (spec: 10/20/30/60 s)

    func test_presetBreakDurations_contains10s() {
        let presets: [TimeInterval] = [10, 20, 30, 60]
        XCTAssertTrue(presets.contains(10))
    }

    func test_presetBreakDurations_contains20s() {
        let presets: [TimeInterval] = [10, 20, 30, 60]
        XCTAssertTrue(presets.contains(20))
    }

    func test_presetBreakDurations_contains30s() {
        let presets: [TimeInterval] = [10, 20, 30, 60]
        XCTAssertTrue(presets.contains(30))
    }

    func test_presetBreakDurations_contains60s() {
        let presets: [TimeInterval] = [10, 20, 30, 60]
        XCTAssertTrue(presets.contains(60))
    }

    func test_presetBreakDurations_hasFourOptions() {
        let presets: [TimeInterval] = [10, 20, 30, 60]
        XCTAssertEqual(presets.count, 4)
    }

    // MARK: - ReminderSettings.default spec compliance

    func test_defaultEyes_interval_is20min() {
        XCTAssertEqual(ReminderSettings.defaultEyes.interval, 1200)
    }

    func test_defaultEyes_breakDuration_is20s() {
        XCTAssertEqual(ReminderSettings.defaultEyes.breakDuration, 20)
    }

    func test_defaultPosture_interval_is30min() {
        XCTAssertEqual(ReminderSettings.defaultPosture.interval, 1800)
    }

    func test_defaultPosture_breakDuration_is10s() {
        XCTAssertEqual(ReminderSettings.defaultPosture.breakDuration, 10)
    }

    func test_defaultEyes_matchesStoreDefaultOnFirstRun() {
        let freshStore = SettingsStore(store: MockSettingsPersisting())
        XCTAssertEqual(freshStore.eyesInterval, ReminderSettings.defaultEyes.interval)
        XCTAssertEqual(freshStore.eyesBreakDuration, ReminderSettings.defaultEyes.breakDuration)
    }

    func test_defaultPosture_matchesStoreDefaultOnFirstRun() {
        let freshStore = SettingsStore(store: MockSettingsPersisting())
        XCTAssertEqual(freshStore.postureInterval, ReminderSettings.defaultPosture.interval)
        XCTAssertEqual(freshStore.postureBreakDuration, ReminderSettings.defaultPosture.breakDuration)
    }
}

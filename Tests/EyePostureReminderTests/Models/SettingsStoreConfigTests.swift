@testable import EyePostureReminder
import XCTest

/// Integration tests for `SettingsStore` + `AppConfig` (data-driven defaults.json system).
///
/// Tests verify the **spec** for first-launch JSON seeding and `resetToDefaults()` behaviour.
///
/// ## Expected SettingsStore API (per decisions.md):
/// ```swift
/// init(store: SettingsPersisting = UserDefaults.standard, config: AppConfig = .load())
/// func resetToDefaults(config: AppConfig = .load())
/// ```
@MainActor
final class SettingsStoreConfigTests: XCTestCase {

    var mockPersistence: MockSettingsPersisting!
    var testConfig: AppConfig!

    override func setUp() {
        super.setUp()
        mockPersistence = MockSettingsPersisting()
        // Use AppConfig.fallback (production values: 1200/20/1800/10) as the test config.
        // These values are intentionally different from the TEST OVERRIDE in ReminderSettings
        // (which uses 10s intervals for simulator testing).
        testConfig = AppConfig.fallback
    }

    override func tearDown() {
        mockPersistence = nil
        testConfig = nil
        super.tearDown()
    }

    // MARK: - First Launch: Defaults Must Come from JSON, Not Hardcode

    func test_firstLaunch_eyesInterval_matchesAppConfigFallback() {
        // A fresh store with empty persistence should read from AppConfig, not hardcode.
        let fresh = SettingsStore(store: MockSettingsPersisting())
        XCTAssertEqual(
            fresh.eyesInterval,
            AppConfig.fallback.defaults.eyeInterval,
            "First-launch eyesInterval must match AppConfig.fallback.defaults.eyeInterval (1200s)" +
            " — SettingsStore.init() must seed from AppConfig."
        )
    }

    func test_firstLaunch_eyesBreakDuration_matchesAppConfigFallback() {
        let fresh = SettingsStore(store: MockSettingsPersisting())
        XCTAssertEqual(
            fresh.eyesBreakDuration,
            AppConfig.fallback.defaults.eyeBreakDuration,
            "First-launch eyesBreakDuration must match AppConfig.fallback (20s)."
        )
    }

    func test_firstLaunch_postureInterval_matchesAppConfigFallback() {
        let fresh = SettingsStore(store: MockSettingsPersisting())
        XCTAssertEqual(
            fresh.postureInterval,
            AppConfig.fallback.defaults.postureInterval,
            "First-launch postureInterval must match AppConfig.fallback (1800s)."
        )
    }

    func test_firstLaunch_postureBreakDuration_matchesAppConfigFallback() {
        let fresh = SettingsStore(store: MockSettingsPersisting())
        XCTAssertEqual(
            fresh.postureBreakDuration,
            AppConfig.fallback.defaults.postureBreakDuration,
            "First-launch postureBreakDuration must match AppConfig.fallback (10s)."
        )
    }

    func test_firstLaunch_globalEnabled_matchesAppConfigFallback() {
        let fresh = SettingsStore(store: MockSettingsPersisting())
        XCTAssertEqual(
            fresh.globalEnabled,
            AppConfig.fallback.features.globalEnabledDefault,
            "First-launch globalEnabled must match AppConfig.fallback.features.globalEnabledDefault."
        )
    }

    // MARK: - Subsequent Launch: UserDefaults Wins Over JSON

    func test_subsequentLaunch_userDefaultsWins_eyesInterval() {
        // Simulate first launch seeding
        mockPersistence.set(600.0, forKey: "kshana.eyes.interval")  // user set 10 min
        let secondLaunch = SettingsStore(store: mockPersistence)
        XCTAssertEqual(
            secondLaunch.eyesInterval,
            600,
            "Subsequent launch: stored UserDefaults value (600) must win over any JSON default")
    }

    func test_subsequentLaunch_userDefaultsWins_postureInterval() {
        mockPersistence.set(3600.0, forKey: "kshana.posture.interval")  // user set 60 min
        let secondLaunch = SettingsStore(store: mockPersistence)
        XCTAssertEqual(
            secondLaunch.postureInterval,
            3600,
            "Subsequent launch: stored posture interval must win over JSON default")
    }

    func test_subsequentLaunch_userDefaultsWins_eyesBreakDuration() {
        mockPersistence.set(30.0, forKey: "kshana.eyes.breakDuration")
        let secondLaunch = SettingsStore(store: mockPersistence)
        XCTAssertEqual(
            secondLaunch.eyesBreakDuration,
            30,
            "Subsequent launch: stored eyesBreakDuration must win over JSON default")
    }

    func test_subsequentLaunch_userDefaultsWins_globalEnabled() {
        mockPersistence.set(false, forKey: "kshana.globalEnabled")
        let secondLaunch = SettingsStore(store: mockPersistence)
        XCTAssertFalse(
            secondLaunch.globalEnabled,
            "Subsequent launch: stored globalEnabled (false) must win over JSON default (true)")
    }

    func test_subsequentLaunch_multipleKeys_allWin() {
        mockPersistence.set(600.0, forKey: "kshana.eyes.interval")
        mockPersistence.set(30.0, forKey: "kshana.eyes.breakDuration")
        mockPersistence.set(2700.0, forKey: "kshana.posture.interval")
        mockPersistence.set(30.0, forKey: "kshana.posture.breakDuration")
        mockPersistence.set(false, forKey: "kshana.globalEnabled")

        let secondLaunch = SettingsStore(store: mockPersistence)
        XCTAssertEqual(secondLaunch.eyesInterval, 600)
        XCTAssertEqual(secondLaunch.eyesBreakDuration, 30)
        XCTAssertEqual(secondLaunch.postureInterval, 2700)
        XCTAssertEqual(secondLaunch.postureBreakDuration, 30)
        XCTAssertFalse(secondLaunch.globalEnabled)
    }

    // MARK: - AppConfig Values ≠ UserDefaults: UserDefaults Must Win

    func test_configDifferentFromUserDefaults_userDefaultsWins() {
        // Even when AppConfig would set 900, if the key is already in the store, store wins.
        mockPersistence.set(300.0, forKey: "kshana.eyes.interval")  // 5-minute user preference
        let store = SettingsStore(store: mockPersistence)
        XCTAssertEqual(
            store.eyesInterval,
            300,
            "When UserDefaults key is already set, it must win over ANY JSON value")
    }

    // MARK: - AppConfig.fallback: Structural Contract

    func test_appConfigFallback_intervalsMatchExpectedProductionValues() {
        // Regression guard: fallback values must match documented production spec.
        XCTAssertEqual(
            AppConfig.fallback.defaults.eyeInterval,
            1200,
            "Production eye interval is 20 min (1200s)")
        XCTAssertEqual(
            AppConfig.fallback.defaults.eyeBreakDuration,
            20,
            "Production eye break is 20s (20-20-20 rule)")
        XCTAssertEqual(
            AppConfig.fallback.defaults.postureInterval,
            1800,
            "Production posture interval is 30 min (1800s)")
        XCTAssertEqual(
            AppConfig.fallback.defaults.postureBreakDuration,
            10,
            "Production posture break is 10s")
    }

    func test_appConfigFallback_featureFlags_matchExpectedDefaults() {
        XCTAssertTrue(
            AppConfig.fallback.features.globalEnabledDefault,
            "App must be on by default (globalEnabled = true)")
        XCTAssertGreaterThan(
            AppConfig.fallback.features.maxSnoozeCount,
            0,
            "maxSnoozeCount must allow at least one snooze")
    }

    // MARK: - Snooze Fields Are NOT in JSON (Runtime State)

    func test_snoozeCount_notAffectedByAppConfig() {
        // Snooze count is runtime state — AppConfig must not touch it.
        // Set a non-zero snooze count before creating the store.
        mockPersistence.set(2, forKey: "kshana.snoozeCount")
        let store = SettingsStore(store: mockPersistence)
        XCTAssertEqual(
            store.snoozeCount,
            2,
            "snoozeCount is runtime state — AppConfig seeding must not reset it")
    }

    func test_snoozedUntil_notAffectedByAppConfig() {
        // snoozedUntil is runtime state — AppConfig must not touch it.
        let futureTimestamp = Date().addingTimeInterval(3600).timeIntervalSince1970
        mockPersistence.set(futureTimestamp, forKey: "kshana.snoozedUntil")
        let store = SettingsStore(store: mockPersistence)
        XCTAssertNotNil(
            store.snoozedUntil,
            "snoozedUntil is runtime state — AppConfig seeding must not clear it")
    }

    // MARK: - resetToDefaults()

    func test_resetToDefaults_eyesInterval_matchesConfig() {
        let store = SettingsStore(store: mockPersistence, config: testConfig)
        store.eyesInterval = 999
        store.resetToDefaults(config: testConfig)
        XCTAssertEqual(store.eyesInterval, testConfig.defaults.eyeInterval,
                       "resetToDefaults() must restore eyesInterval from config")
    }

    func test_resetToDefaults_eyesBreakDuration_matchesConfig() {
        let store = SettingsStore(store: mockPersistence, config: testConfig)
        store.eyesBreakDuration = 999
        store.resetToDefaults(config: testConfig)
        XCTAssertEqual(store.eyesBreakDuration, testConfig.defaults.eyeBreakDuration,
                       "resetToDefaults() must restore eyesBreakDuration from config")
    }

    func test_resetToDefaults_postureInterval_matchesConfig() {
        let store = SettingsStore(store: mockPersistence, config: testConfig)
        store.postureInterval = 999
        store.resetToDefaults(config: testConfig)
        XCTAssertEqual(store.postureInterval, testConfig.defaults.postureInterval,
                       "resetToDefaults() must restore postureInterval from config")
    }

    func test_resetToDefaults_postureBreakDuration_matchesConfig() {
        let store = SettingsStore(store: mockPersistence, config: testConfig)
        store.postureBreakDuration = 999
        store.resetToDefaults(config: testConfig)
        XCTAssertEqual(store.postureBreakDuration, testConfig.defaults.postureBreakDuration,
                       "resetToDefaults() must restore postureBreakDuration from config")
    }

    func test_resetToDefaults_globalEnabled_matchesConfig() {
        let store = SettingsStore(store: mockPersistence, config: testConfig)
        store.globalEnabled = false
        store.resetToDefaults(config: testConfig)
        XCTAssertEqual(store.globalEnabled, testConfig.features.globalEnabledDefault,
                       "resetToDefaults() must restore globalEnabled from config")
    }

    func test_resetToDefaults_eyesEnabled_isTrue() {
        let store = SettingsStore(store: mockPersistence, config: testConfig)
        store.eyesEnabled = false
        store.resetToDefaults(config: testConfig)
        XCTAssertTrue(store.eyesEnabled, "resetToDefaults() must restore eyesEnabled to true")
    }

    func test_resetToDefaults_postureEnabled_isTrue() {
        let store = SettingsStore(store: mockPersistence, config: testConfig)
        store.postureEnabled = false
        store.resetToDefaults(config: testConfig)
        XCTAssertTrue(store.postureEnabled, "resetToDefaults() must restore postureEnabled to true")
    }

    func test_resetToDefaults_snoozedUntil_clearedToNil() {
        let store = SettingsStore(store: mockPersistence, config: testConfig)
        store.snoozedUntil = Date().addingTimeInterval(3600)
        store.resetToDefaults(config: testConfig)
        XCTAssertNil(store.snoozedUntil, "resetToDefaults() must clear snoozedUntil to nil")
    }

    func test_resetToDefaults_snoozeCount_clearedToZero() {
        let store = SettingsStore(store: mockPersistence, config: testConfig)
        store.snoozeCount = 5
        store.resetToDefaults(config: testConfig)
        XCTAssertEqual(store.snoozeCount, 0, "resetToDefaults() must reset snoozeCount to 0")
    }

    func test_resetToDefaults_hapticsEnabled_isTrue() {
        let store = SettingsStore(store: mockPersistence, config: testConfig)
        store.hapticsEnabled = false
        store.resetToDefaults(config: testConfig)
        XCTAssertTrue(store.hapticsEnabled, "resetToDefaults() must restore hapticsEnabled to true")
    }

    func test_resetToDefaults_pauseMediaDuringBreaks_isFalse() {
        let store = SettingsStore(store: mockPersistence, config: testConfig)
        store.pauseMediaDuringBreaks = true
        store.resetToDefaults(config: testConfig)
        XCTAssertFalse(store.pauseMediaDuringBreaks,
                       "resetToDefaults() must restore pauseMediaDuringBreaks to false")
    }

    func test_resetToDefaults_notificationFallbackEnabled_isTrue() {
        let store = SettingsStore(store: mockPersistence, config: testConfig)
        store.notificationFallbackEnabled = false
        store.resetToDefaults(config: testConfig)
        XCTAssertTrue(
            store.notificationFallbackEnabled,
            "resetToDefaults() must restore notificationFallbackEnabled to true"
        )
    }

    func test_resetToDefaults_pauseDuringFocus_isTrue() {
        let store = SettingsStore(store: mockPersistence, config: testConfig)
        store.pauseDuringFocus = false
        store.resetToDefaults(config: testConfig)
        XCTAssertTrue(store.pauseDuringFocus, "resetToDefaults() must restore pauseDuringFocus to true")
    }

    func test_resetToDefaults_pauseWhileDriving_isTrue() {
        let store = SettingsStore(store: mockPersistence, config: testConfig)
        store.pauseWhileDriving = false
        store.resetToDefaults(config: testConfig)
        XCTAssertTrue(store.pauseWhileDriving, "resetToDefaults() must restore pauseWhileDriving to true")
    }

    func test_resetToDefaults_doesNotAffectUnrelatedKeys() {
        // An unrelated key written before reset must survive the reset unchanged.
        mockPersistence.set(42, forKey: "unrelated.key")
        let store = SettingsStore(store: mockPersistence, config: testConfig)
        store.resetToDefaults(config: testConfig)
        XCTAssertTrue(mockPersistence.hasValue(forKey: "unrelated.key"),
                      "resetToDefaults() must not remove unrelated UserDefaults keys")
        XCTAssertEqual(mockPersistence.integer(forKey: "unrelated.key", defaultValue: 0), 42,
                       "resetToDefaults() must not modify unrelated UserDefaults values")
    }

    func test_resetToDefaults_persistsAllValuesToStore() {
        // After reset, a new store reading the same persistence must see default values —
        // confirming that resetToDefaults() writes through to the backing store.
        let store = SettingsStore(store: mockPersistence, config: testConfig)
        store.eyesInterval = 999
        store.postureInterval = 999
        store.snoozeCount = 7
        store.resetToDefaults(config: testConfig)

        let reloaded = SettingsStore(store: mockPersistence, config: testConfig)
        XCTAssertEqual(reloaded.eyesInterval, testConfig.defaults.eyeInterval,
                       "Reset eyesInterval must be persisted so a new SettingsStore reads the correct value")
        XCTAssertEqual(reloaded.postureInterval, testConfig.defaults.postureInterval,
                       "Reset postureInterval must be persisted")
        XCTAssertEqual(reloaded.snoozeCount, 0,
                       "Reset snoozeCount must be persisted as 0")
    }
}

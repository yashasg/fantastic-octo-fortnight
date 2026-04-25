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
            "First-launch eyesInterval must match AppConfig.fallback.defaults.eyeInterval (1200s) — SettingsStore.init() must seed from AppConfig."
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
        mockPersistence.set(600.0, forKey: "epr.eyes.interval")  // user set 10 min
        let secondLaunch = SettingsStore(store: mockPersistence)
        XCTAssertEqual(
            secondLaunch.eyesInterval,
            600,
            "Subsequent launch: stored UserDefaults value (600) must win over any JSON default")
    }

    func test_subsequentLaunch_userDefaultsWins_postureInterval() {
        mockPersistence.set(3600.0, forKey: "epr.posture.interval")  // user set 60 min
        let secondLaunch = SettingsStore(store: mockPersistence)
        XCTAssertEqual(
            secondLaunch.postureInterval,
            3600,
            "Subsequent launch: stored posture interval must win over JSON default")
    }

    func test_subsequentLaunch_userDefaultsWins_eyesBreakDuration() {
        mockPersistence.set(30.0, forKey: "epr.eyes.breakDuration")
        let secondLaunch = SettingsStore(store: mockPersistence)
        XCTAssertEqual(
            secondLaunch.eyesBreakDuration,
            30,
            "Subsequent launch: stored eyesBreakDuration must win over JSON default")
    }

    func test_subsequentLaunch_userDefaultsWins_globalEnabled() {
        mockPersistence.set(false, forKey: "epr.globalEnabled")
        let secondLaunch = SettingsStore(store: mockPersistence)
        XCTAssertFalse(
            secondLaunch.globalEnabled,
            "Subsequent launch: stored globalEnabled (false) must win over JSON default (true)")
    }

    func test_subsequentLaunch_multipleKeys_allWin() {
        mockPersistence.set(600.0, forKey: "epr.eyes.interval")
        mockPersistence.set(30.0, forKey: "epr.eyes.breakDuration")
        mockPersistence.set(2700.0, forKey: "epr.posture.interval")
        mockPersistence.set(30.0, forKey: "epr.posture.breakDuration")
        mockPersistence.set(false, forKey: "epr.globalEnabled")

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
        mockPersistence.set(300.0, forKey: "epr.eyes.interval")  // 5-minute user preference
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
        mockPersistence.set(2, forKey: "epr.snoozeCount")
        let store = SettingsStore(store: mockPersistence)
        XCTAssertEqual(
            store.snoozeCount,
            2,
            "snoozeCount is runtime state — AppConfig seeding must not reset it")
    }

    func test_snoozedUntil_notAffectedByAppConfig() {
        // snoozedUntil is runtime state — AppConfig must not touch it.
        let futureTimestamp = Date().addingTimeInterval(3600).timeIntervalSince1970
        mockPersistence.set(futureTimestamp, forKey: "epr.snoozedUntil")
        let store = SettingsStore(store: mockPersistence)
        XCTAssertNotNil(
            store.snoozedUntil,
            "snoozedUntil is runtime state — AppConfig seeding must not clear it")
    }

    // MARK: - resetToDefaults() — PENDING IMPLEMENTATION
    //
    // Tests for `SettingsStore.resetToDefaults(config:)` will be added once
    // Basher implements the method. Expected API:
    //   func resetToDefaults(config: AppConfig = AppConfig.load())
}

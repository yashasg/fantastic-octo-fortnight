import XCTest

@testable import EyePostureReminder

/// Coverage for `SettingsStore.eyesSnapshotFromUserDefaults` — the
/// non-actor-isolated synchronous read used by `EyePostureReminderApp.init`
/// to seed the TCA root `state.scheduling.settings` before the
/// `SettingsClient.stream` first emission lands. Closes the settings-load
/// race that previously left `reminderNotificationEffect` reading
/// `breakDuration: 0` and showing auto-dismissing overlays during the
/// UI-test backdoor (#737).
final class SettingsStoreSeedTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suiteName = "SettingsStoreSeedTests.\(UUID().uuidString)"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    // MARK: - Empty-store fallback

    func test_eyesSnapshot_emptyDefaults_fallsBackToDefaultEyes() {
        let snapshot = SettingsStore.eyesSnapshotFromUserDefaults(defaults)
        XCTAssertEqual(
            snapshot, ReminderSettings.defaultEyes,
            "First-cold-launch seed must fall back to ReminderSettings.defaultEyes"
        )
    }

    func test_eyesSnapshot_emptyDefaults_breakDurationIsNonZero() {
        let snapshot = SettingsStore.eyesSnapshotFromUserDefaults(defaults)
        XCTAssertGreaterThan(
            snapshot.breakDuration, 0,
            "Seed must never produce breakDuration: 0 — that is the exact race "
            + "#737 closes (overlay would auto-dismiss before UITests interact)"
        )
    }

    func test_eyesSnapshot_emptyDefaults_intervalIsNonZero() {
        let snapshot = SettingsStore.eyesSnapshotFromUserDefaults(defaults)
        XCTAssertGreaterThan(
            snapshot.interval, 0,
            "Seed must never produce interval: 0 — thresholdReachedEffect "
            + "guards on `interval > 0` and would silently no-op"
        )
    }

    // MARK: - Persisted-value reads

    func test_eyesSnapshot_persistedInterval_isReturned() {
        defaults.set(900.0, forKey: SettingsStore.Keys.eyesInterval)
        let snapshot = SettingsStore.eyesSnapshotFromUserDefaults(defaults)
        XCTAssertEqual(snapshot.interval, 900)
    }

    func test_eyesSnapshot_persistedBreakDuration_isReturned() {
        defaults.set(45.0, forKey: SettingsStore.Keys.eyesBreakDuration)
        let snapshot = SettingsStore.eyesSnapshotFromUserDefaults(defaults)
        XCTAssertEqual(snapshot.breakDuration, 45)
    }

    func test_eyesSnapshot_bothKeysPersisted_returnsExactValues() {
        defaults.set(1500.0, forKey: SettingsStore.Keys.eyesInterval)
        defaults.set(30.0, forKey: SettingsStore.Keys.eyesBreakDuration)
        let snapshot = SettingsStore.eyesSnapshotFromUserDefaults(defaults)
        // #899: empty haptics/pauseMedia keys surface the shipping defaults
        // (haptics on, pauseMedia off) — matches SettingsStore.init.
        XCTAssertEqual(
            snapshot,
            ReminderSettings(
                interval: 1500,
                breakDuration: 30,
                hapticsEnabled: true,
                pauseMediaDuringBreaks: false
            )
        )
    }

    // MARK: - UI-test inflation parity

    /// Mirrors the `--show-overlay-eyes` / `--show-overlay-posture` pre-seed
    /// in `EyePostureReminderApp.preSeedReminderSettingsFromLaunchArgsIfNeeded`:
    /// once the inflated 600 s value lands in UserDefaults, the seed must
    /// surface it so the TCA `reminderNotificationEffect` reads
    /// `breakDuration: 600` immediately, with no race against the
    /// `SettingsClient.stream` first emission.
    func test_eyesSnapshot_uiTestOverlayInflation_isHonoured() throws {
#if DEBUG
        defaults.set(
            AppDelegate.uiTestOverlayBreakDuration,
            forKey: SettingsStore.Keys.eyesBreakDuration
        )
        let snapshot = SettingsStore.eyesSnapshotFromUserDefaults(defaults)
        XCTAssertEqual(
            snapshot.breakDuration,
            AppDelegate.uiTestOverlayBreakDuration,
            "Seed must reflect the --show-overlay-* inflation written by "
            + "EyePostureReminderApp.preSeedReminderSettingsFromLaunchArgsIfNeeded"
        )
#else
        throw XCTSkip("uiTestOverlayBreakDuration is DEBUG-only")
#endif
    }

    // MARK: - Partial-key persistence

    func test_eyesSnapshot_onlyIntervalPersisted_breakDurationFallsBack() {
        defaults.set(800.0, forKey: SettingsStore.Keys.eyesInterval)
        let snapshot = SettingsStore.eyesSnapshotFromUserDefaults(defaults)
        XCTAssertEqual(snapshot.interval, 800)
        XCTAssertEqual(snapshot.breakDuration, ReminderSettings.defaultEyes.breakDuration)
    }

    func test_eyesSnapshot_onlyBreakDurationPersisted_intervalFallsBack() {
        defaults.set(15.0, forKey: SettingsStore.Keys.eyesBreakDuration)
        let snapshot = SettingsStore.eyesSnapshotFromUserDefaults(defaults)
        XCTAssertEqual(snapshot.interval, ReminderSettings.defaultEyes.interval)
        XCTAssertEqual(snapshot.breakDuration, 15)
    }

    // MARK: - Overlay-flag propagation (#899)

    /// Until a value is persisted, the seed must surface the same `false`
    /// literal the pre-#899 SchedulingFeature passed to OverlayClient.show
    /// for `pauseMediaDuringBreaks` — preserving cold-launch parity.
    func test_eyesSnapshot_emptyDefaults_pauseMediaDuringBreaksDefaultsFalse() {
        let snapshot = SettingsStore.eyesSnapshotFromUserDefaults(defaults)
        XCTAssertFalse(snapshot.pauseMediaDuringBreaks)
    }

    /// `hapticsEnabled` ships defaulted to `true` (matching
    /// `SettingsStore.init`'s persisted-default), so the seed must surface
    /// `true` when no value has been persisted yet.
    func test_eyesSnapshot_emptyDefaults_hapticsEnabledDefaultsTrue() {
        let snapshot = SettingsStore.eyesSnapshotFromUserDefaults(defaults)
        XCTAssertTrue(snapshot.hapticsEnabled)
    }

    func test_eyesSnapshot_persistedHapticsEnabledFalse_isReturned() {
        defaults.set(false, forKey: SettingsStore.Keys.hapticsEnabled)
        let snapshot = SettingsStore.eyesSnapshotFromUserDefaults(defaults)
        XCTAssertFalse(snapshot.hapticsEnabled)
    }

    func test_eyesSnapshot_persistedPauseMediaTrue_isReturned() {
        defaults.set(true, forKey: SettingsStore.Keys.pauseMediaDuringBreaks)
        let snapshot = SettingsStore.eyesSnapshotFromUserDefaults(defaults)
        XCTAssertTrue(snapshot.pauseMediaDuringBreaks)
    }
}

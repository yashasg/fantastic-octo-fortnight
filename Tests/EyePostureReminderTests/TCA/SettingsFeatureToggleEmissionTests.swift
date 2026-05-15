import ComposableArchitecture
import XCTest

@testable import EyePostureReminder

/// Coverage for `SettingsFeature.Action.settingToggleChanged`, the post-TCA
/// emission shim wired up by `SettingsView`'s `.onChangeCompat` watchers
/// (#777). Asserts every silent `AnalyticsEvent.SettingKey` row now produces
/// a `setting_changed` event through the injected `AnalyticsClient`.
@MainActor
final class SettingsFeatureToggleEmissionTests: XCTestCase {

    func test_settingToggleChanged_globalEnabled_logsSettingChanged() async {
        let clock = TestClock()
        let analyticsEvents = LockIsolated<[AnalyticsEvent]>([])

        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.settingsClient = TCATestDependencies.silentSettingsClient()
            $0.reminderSchedulerClient = TCATestDependencies.silentReminderSchedulerClient()
            $0.analyticsClient = AnalyticsClient(log: { event in
                analyticsEvents.withValue { $0.append(event) }
            })
            $0.continuousClock = clock
        }

        await store.send(.settingToggleChanged(
            setting: .globalEnabled,
            oldValue: "true",
            newValue: "false"
        )) {
            $0.showSavedBanner = true
        }

        await clock.advance(by: .seconds(4))
        await store.receive(\.savedBannerExpired) {
            $0.showSavedBanner = false
        }

        analyticsEvents.withValue { events in
            XCTAssertEqual(events.count, 1)
            guard case let .settingChanged(setting, oldValue, newValue) = events.first else {
                XCTFail("Expected .settingChanged; got \(String(describing: events.first))")
                return
            }
            XCTAssertEqual(setting, .globalEnabled)
            XCTAssertEqual(oldValue, "true")
            XCTAssertEqual(newValue, "false")
        }
    }

    func test_settingToggleChanged_allSilentSettingKeys_logSettingChanged() async {
        // The keys that were silent before #777 wired the `.settingToggleChanged`
        // action up to `SettingsView`'s `.onChangeCompat` watchers. The
        // interval/break-duration eyes keys are still emitted via the
        // bindable surface and are covered by `SettingsFeatureBindingTests`.
        let cases: [(AnalyticsEvent.SettingKey, String, String)] = [
            (.globalEnabled, "true", "false"),
            (.eyesEnabled, "true", "false"),
            (.postureEnabled, "false", "true"),
            (.postureInterval, "1200.0", "1800.0"),
            (.postureBreakDuration, "20.0", "30.0"),
            (.pauseDuringFocus, "true", "false"),
            (.pauseWhileDriving, "false", "true"),
            (.hapticsEnabled, "true", "false"),
            (.notificationFallbackEnabled, "false", "true")
        ]

        let clock = TestClock()
        let analyticsEvents = LockIsolated<[AnalyticsEvent]>([])

        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.settingsClient = TCATestDependencies.silentSettingsClient()
            $0.reminderSchedulerClient = TCATestDependencies.silentReminderSchedulerClient()
            $0.analyticsClient = AnalyticsClient(log: { event in
                analyticsEvents.withValue { $0.append(event) }
            })
            $0.continuousClock = clock
        }

        // Each toggle resets the saved-banner timer (cancelInFlight: true on
        // `CancelID.settingToggleBanner`), so the banner is only marked as
        // appearing on the first send — subsequent sends keep it true.
        let (firstKey, firstOld, firstNew) = cases[0]
        await store.send(.settingToggleChanged(
            setting: firstKey,
            oldValue: firstOld,
            newValue: firstNew
        )) {
            $0.showSavedBanner = true
        }
        for (key, oldValue, newValue) in cases.dropFirst() {
            await store.send(.settingToggleChanged(
                setting: key,
                oldValue: oldValue,
                newValue: newValue
            ))
        }

        // Only the last toggle's 4 s expiry timer survives the
        // `cancelInFlight: true` chain — advancing the clock fires exactly
        // one `.savedBannerExpired`.
        await clock.advance(by: .seconds(4))
        await store.receive(\.savedBannerExpired) {
            $0.showSavedBanner = false
        }

        analyticsEvents.withValue { events in
            XCTAssertEqual(events.count, cases.count,
                           "Every emit should be logged exactly once.")
            for (index, expected) in cases.enumerated() {
                guard case let .settingChanged(setting, oldValue, newValue) = events[index] else {
                    XCTFail("Expected .settingChanged at index \(index); got \(events[index])")
                    return
                }
                XCTAssertEqual(setting, expected.0, "setting key mismatch at index \(index)")
                XCTAssertEqual(oldValue, expected.1, "oldValue mismatch for \(expected.0)")
                XCTAssertEqual(newValue, expected.2, "newValue mismatch for \(expected.0)")
            }
        }
    }

    /// `.settingToggleChanged` must flip `showSavedBanner` to `true` and
    /// schedule a `.savedBannerExpired` 4 s later — the same affordance the
    /// bindable `eyesInterval` / `eyesBreakDuration` rows produce. Without
    /// this, the master-toggle path (and every other non-bindable row
    /// reaching the reducer through this analytics shim) had no visible
    /// feedback after a change, breaking
    /// `SettingsFlowTests.test_settings_savedBanner_appearsOnToggle`
    /// (tracked as #787 before the root cause was identified).
    func test_settingToggleChanged_flipsShowSavedBannerAndSchedulesExpiry() async {
        let clock = TestClock()

        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.settingsClient = TCATestDependencies.silentSettingsClient()
            $0.reminderSchedulerClient = TCATestDependencies.silentReminderSchedulerClient()
            $0.analyticsClient = AnalyticsClient(log: { _ in })
            $0.continuousClock = clock
        }

        await store.send(.settingToggleChanged(
            setting: .hapticsEnabled,
            oldValue: "true",
            newValue: "false"
        )) {
            $0.showSavedBanner = true
        }

        // Banner remains visible during the 4-second window.
        await clock.advance(by: .seconds(3))

        await clock.advance(by: .seconds(1))
        await store.receive(\.savedBannerExpired) {
            $0.showSavedBanner = false
        }
    }

    /// Rapid successive toggles must collapse to a single `.savedBannerExpired`
    /// — the in-flight banner timer is cancel-replaced each time. Without
    /// this, a user mashing toggles would see the banner flicker as each
    /// previous timer expired mid-sequence.
    func test_settingToggleChanged_rapidSuccessionCollapsesToSingleExpiry() async {
        let clock = TestClock()

        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.settingsClient = TCATestDependencies.silentSettingsClient()
            $0.reminderSchedulerClient = TCATestDependencies.silentReminderSchedulerClient()
            $0.analyticsClient = AnalyticsClient(log: { _ in })
            $0.continuousClock = clock
        }

        await store.send(.settingToggleChanged(
            setting: .hapticsEnabled,
            oldValue: "true",
            newValue: "false"
        )) {
            $0.showSavedBanner = true
        }
        await clock.advance(by: .seconds(2))
        // Second toggle within the 4 s window restarts the timer; no expiry
        // emits between the two sends.
        await store.send(.settingToggleChanged(
            setting: .hapticsEnabled,
            oldValue: "false",
            newValue: "true"
        ))
        await clock.advance(by: .seconds(3))
        // Still inside the new 4 s window — no expiry yet.

        await clock.advance(by: .seconds(1))
        await store.receive(\.savedBannerExpired) {
            $0.showSavedBanner = false
        }
    }
}

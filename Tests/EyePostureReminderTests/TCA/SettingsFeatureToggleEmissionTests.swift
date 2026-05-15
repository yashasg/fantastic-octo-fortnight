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
        let analyticsEvents = LockIsolated<[AnalyticsEvent]>([])

        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.settingsClient = TCATestDependencies.silentSettingsClient()
            $0.reminderSchedulerClient = TCATestDependencies.silentReminderSchedulerClient()
            $0.analyticsClient = AnalyticsClient(log: { event in
                analyticsEvents.withValue { $0.append(event) }
            })
            $0.continuousClock = TestClock()
        }

        await store.send(.settingToggleChanged(
            setting: .globalEnabled,
            oldValue: "true",
            newValue: "false"
        ))
        await store.finish()

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

        let analyticsEvents = LockIsolated<[AnalyticsEvent]>([])

        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.settingsClient = TCATestDependencies.silentSettingsClient()
            $0.reminderSchedulerClient = TCATestDependencies.silentReminderSchedulerClient()
            $0.analyticsClient = AnalyticsClient(log: { event in
                analyticsEvents.withValue { $0.append(event) }
            })
            $0.continuousClock = TestClock()
        }

        for (key, oldValue, newValue) in cases {
            await store.send(.settingToggleChanged(
                setting: key,
                oldValue: oldValue,
                newValue: newValue
            ))
        }
        await store.finish()

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

    func test_settingToggleChanged_doesNotMutateState() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.settingsClient = TCATestDependencies.silentSettingsClient()
            $0.reminderSchedulerClient = TCATestDependencies.silentReminderSchedulerClient()
            $0.analyticsClient = AnalyticsClient(log: { _ in })
            $0.continuousClock = TestClock()
        }

        // No trailing closure ⇒ state must be unchanged by the action.
        await store.send(.settingToggleChanged(
            setting: .hapticsEnabled,
            oldValue: "true",
            newValue: "false"
        ))
        await store.finish()
    }
}

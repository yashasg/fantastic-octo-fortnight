import ComposableArchitecture
import XCTest

@testable import EyePostureReminder

/// Phase 3 (`p0-tca-16` / #679) coverage for the bindable surface of
/// `SettingsFeature`. Asserts the 300 ms debounce, the persisted write
/// through `SettingsClient.update*`, the per-type reschedule via
/// `ReminderSchedulerClient.rescheduleReminder`, the analytics delta against
/// the captured `prev*` snapshot, and the 2 s saved-banner expiry. Also
/// verifies that rapid edits within the debounce window collapse to the
/// latest value (`cancelInFlight: true` on the debounce cancellation id).
@MainActor
final class SettingsFeatureBindingTests: XCTestCase {

    func test_binding_eyesInterval_debouncesThenPersistsReschedulesAndLogs() async {
        let clock = TestClock()
        let updateCalls = LockIsolated<[TimeInterval]>([])
        let rescheduleCalls = LockIsolated<[(ReminderType, ReminderSettings)]>([])
        let analyticsEvents = LockIsolated<[AnalyticsEvent]>([])

        var settings = TCATestDependencies.silentSettingsClient()
        settings.updateEyesInterval = { value in
            updateCalls.withValue { $0.append(value) }
        }

        var initial = SettingsFeature.State()
        initial.prevEyesInterval = 1200
        initial.eyesInterval = 1200
        initial.prevEyesBreakDuration = 20
        initial.eyesBreakDuration = 20

        let store = TestStore(initialState: initial) {
            SettingsFeature()
        } withDependencies: {
            $0.settingsClient = settings
            $0.reminderSchedulerClient = ReminderSchedulerClient(
                scheduleReminders: { _ in },
                rescheduleReminder: { type, snapshot in
                    rescheduleCalls.withValue { $0.append((type, snapshot)) }
                },
                cancelReminder: { _ in },
                cancelAllReminders: {}
            )
            $0.analyticsClient = AnalyticsClient(log: { event in
                analyticsEvents.withValue { $0.append(event) }
            })
            $0.continuousClock = clock
        }

        await store.send(.binding(.set(\.eyesInterval, 600))) {
            $0.eyesInterval = 600
            $0.showSavedBanner = true
        }

        // Effect is debounced: nothing fires before 300 ms.
        updateCalls.withValue { XCTAssertTrue($0.isEmpty, "Update must wait for debounce") }
        rescheduleCalls.withValue { XCTAssertTrue($0.isEmpty) }

        await clock.advance(by: .milliseconds(300))
        await clock.advance(by: .seconds(4))
        await store.receive(\.savedBannerExpired) {
            $0.showSavedBanner = false
        }

        updateCalls.withValue { XCTAssertEqual($0, [600]) }
        rescheduleCalls.withValue { calls in
            XCTAssertEqual(calls.count, 1)
            XCTAssertEqual(calls.first?.0, .eyes)
            XCTAssertEqual(calls.first?.1.interval, 600)
            XCTAssertEqual(calls.first?.1.breakDuration, 20)
        }
        analyticsEvents.withValue { events in
            XCTAssertEqual(events.count, 1)
            guard case let .settingChanged(setting, oldValue, newValue) = events.first else {
                XCTFail("Expected .settingChanged; got \(String(describing: events.first))")
                return
            }
            XCTAssertEqual(setting, .eyesInterval)
            XCTAssertEqual(oldValue, "1200.0",
                           "Analytics delta must use prevEyesInterval (1200), not the in-flight new value")
            XCTAssertEqual(newValue, "600.0")
        }
    }

    func test_binding_eyesBreakDuration_debouncesThenPersistsReschedulesAndLogs() async {
        let clock = TestClock()
        let updateCalls = LockIsolated<[TimeInterval]>([])
        let rescheduleCalls = LockIsolated<[(ReminderType, ReminderSettings)]>([])
        let analyticsEvents = LockIsolated<[AnalyticsEvent]>([])

        var settings = TCATestDependencies.silentSettingsClient()
        settings.updateEyesBreakDuration = { value in
            updateCalls.withValue { $0.append(value) }
        }

        var initial = SettingsFeature.State()
        initial.prevEyesInterval = 1200
        initial.eyesInterval = 1200
        initial.prevEyesBreakDuration = 20
        initial.eyesBreakDuration = 20

        let store = TestStore(initialState: initial) {
            SettingsFeature()
        } withDependencies: {
            $0.settingsClient = settings
            $0.reminderSchedulerClient = ReminderSchedulerClient(
                scheduleReminders: { _ in },
                rescheduleReminder: { type, snapshot in
                    rescheduleCalls.withValue { $0.append((type, snapshot)) }
                },
                cancelReminder: { _ in },
                cancelAllReminders: {}
            )
            $0.analyticsClient = AnalyticsClient(log: { event in
                analyticsEvents.withValue { $0.append(event) }
            })
            $0.continuousClock = clock
        }

        await store.send(.binding(.set(\.eyesBreakDuration, 30))) {
            $0.eyesBreakDuration = 30
            $0.showSavedBanner = true
        }
        await clock.advance(by: .milliseconds(300))
        await clock.advance(by: .seconds(4))
        await store.receive(\.savedBannerExpired) {
            $0.showSavedBanner = false
        }

        updateCalls.withValue { XCTAssertEqual($0, [30]) }
        rescheduleCalls.withValue { calls in
            XCTAssertEqual(calls.count, 1)
            XCTAssertEqual(calls.first?.0, .eyes)
            XCTAssertEqual(calls.first?.1.breakDuration, 30)
            XCTAssertEqual(calls.first?.1.interval, 1200,
                           "Reschedule snapshot must carry the unchanged interval")
        }
        analyticsEvents.withValue { events in
            guard case let .settingChanged(setting, oldValue, newValue) = events.first else {
                XCTFail("Expected .settingChanged; got \(String(describing: events.first))")
                return
            }
            XCTAssertEqual(setting, .eyesBreakDuration)
            XCTAssertEqual(oldValue, "20.0")
            XCTAssertEqual(newValue, "30.0")
        }
    }

    func test_binding_eyesInterval_rapidEdits_collapseToLatestValue() async {
        let clock = TestClock()
        let updateCalls = LockIsolated<[TimeInterval]>([])
        let rescheduleCalls = LockIsolated<[ReminderSettings]>([])

        var settings = TCATestDependencies.silentSettingsClient()
        settings.updateEyesInterval = { value in
            updateCalls.withValue { $0.append(value) }
        }

        var initial = SettingsFeature.State()
        initial.prevEyesInterval = 1200
        initial.eyesInterval = 1200

        let store = TestStore(initialState: initial) {
            SettingsFeature()
        } withDependencies: {
            $0.settingsClient = settings
            $0.reminderSchedulerClient = ReminderSchedulerClient(
                scheduleReminders: { _ in },
                rescheduleReminder: { _, snapshot in
                    rescheduleCalls.withValue { $0.append(snapshot) }
                },
                cancelReminder: { _ in },
                cancelAllReminders: {}
            )
            $0.analyticsClient = AnalyticsClient(log: { _ in })
            $0.continuousClock = clock
        }

        await store.send(.binding(.set(\.eyesInterval, 800))) {
            $0.eyesInterval = 800
            $0.showSavedBanner = true
        }
        await store.send(.binding(.set(\.eyesInterval, 700))) {
            $0.eyesInterval = 700
        }
        await store.send(.binding(.set(\.eyesInterval, 600))) {
            $0.eyesInterval = 600
        }
        await clock.advance(by: .milliseconds(300))
        await clock.advance(by: .seconds(4))
        await store.receive(\.savedBannerExpired) {
            $0.showSavedBanner = false
        }

        updateCalls.withValue { calls in
            XCTAssertEqual(calls, [600],
                           "cancelInFlight debounce must collapse rapid edits to the latest value")
        }
        rescheduleCalls.withValue { snapshots in
            XCTAssertEqual(snapshots.count, 1)
            XCTAssertEqual(snapshots.first?.interval, 600)
        }
    }

    // MARK: - Posture-side bindable surface (#805)

    func test_binding_postureInterval_debouncesThenPersistsReschedulesAndLogs() async {
        let clock = TestClock()
        let updateCalls = LockIsolated<[TimeInterval]>([])
        let rescheduleCalls = LockIsolated<[(ReminderType, ReminderSettings)]>([])
        let analyticsEvents = LockIsolated<[AnalyticsEvent]>([])

        var settings = TCATestDependencies.silentSettingsClient()
        settings.updatePostureInterval = { value in
            updateCalls.withValue { $0.append(value) }
        }

        var initial = SettingsFeature.State()
        initial.prevPostureInterval = 1800
        initial.postureInterval = 1800
        initial.prevPostureBreakDuration = 10
        initial.postureBreakDuration = 10

        let store = TestStore(initialState: initial) {
            SettingsFeature()
        } withDependencies: {
            $0.settingsClient = settings
            $0.reminderSchedulerClient = ReminderSchedulerClient(
                scheduleReminders: { _ in },
                rescheduleReminder: { type, snapshot in
                    rescheduleCalls.withValue { $0.append((type, snapshot)) }
                },
                cancelReminder: { _ in },
                cancelAllReminders: {}
            )
            $0.analyticsClient = AnalyticsClient(log: { event in
                analyticsEvents.withValue { $0.append(event) }
            })
            $0.continuousClock = clock
        }

        await store.send(.binding(.set(\.postureInterval, 900))) {
            $0.postureInterval = 900
            $0.showSavedBanner = true
        }

        updateCalls.withValue { XCTAssertTrue($0.isEmpty, "Update must wait for debounce") }
        rescheduleCalls.withValue { XCTAssertTrue($0.isEmpty) }

        await clock.advance(by: .milliseconds(300))
        await clock.advance(by: .seconds(4))
        await store.receive(\.savedBannerExpired) {
            $0.showSavedBanner = false
        }

        updateCalls.withValue { XCTAssertEqual($0, [900]) }
        rescheduleCalls.withValue { calls in
            XCTAssertEqual(calls.count, 1)
            XCTAssertEqual(calls.first?.0, .posture,
                           "Posture-interval bindings must reschedule the posture reminder")
            XCTAssertEqual(calls.first?.1.interval, 900)
            XCTAssertEqual(calls.first?.1.breakDuration, 10)
        }
        analyticsEvents.withValue { events in
            XCTAssertEqual(events.count, 1)
            guard case let .settingChanged(setting, oldValue, newValue) = events.first else {
                XCTFail("Expected .settingChanged; got \(String(describing: events.first))")
                return
            }
            XCTAssertEqual(setting, .postureInterval)
            XCTAssertEqual(oldValue, "1800.0",
                           "Analytics delta must use prevPostureInterval (1800), not the in-flight new value")
            XCTAssertEqual(newValue, "900.0")
        }
    }

    func test_binding_postureBreakDuration_debouncesThenPersistsReschedulesAndLogs() async {
        let clock = TestClock()
        let updateCalls = LockIsolated<[TimeInterval]>([])
        let rescheduleCalls = LockIsolated<[(ReminderType, ReminderSettings)]>([])
        let analyticsEvents = LockIsolated<[AnalyticsEvent]>([])

        var settings = TCATestDependencies.silentSettingsClient()
        settings.updatePostureBreakDuration = { value in
            updateCalls.withValue { $0.append(value) }
        }

        var initial = SettingsFeature.State()
        initial.prevPostureInterval = 1800
        initial.postureInterval = 1800
        initial.prevPostureBreakDuration = 10
        initial.postureBreakDuration = 10

        let store = TestStore(initialState: initial) {
            SettingsFeature()
        } withDependencies: {
            $0.settingsClient = settings
            $0.reminderSchedulerClient = ReminderSchedulerClient(
                scheduleReminders: { _ in },
                rescheduleReminder: { type, snapshot in
                    rescheduleCalls.withValue { $0.append((type, snapshot)) }
                },
                cancelReminder: { _ in },
                cancelAllReminders: {}
            )
            $0.analyticsClient = AnalyticsClient(log: { event in
                analyticsEvents.withValue { $0.append(event) }
            })
            $0.continuousClock = clock
        }

        await store.send(.binding(.set(\.postureBreakDuration, 20))) {
            $0.postureBreakDuration = 20
            $0.showSavedBanner = true
        }
        await clock.advance(by: .milliseconds(300))
        await clock.advance(by: .seconds(4))
        await store.receive(\.savedBannerExpired) {
            $0.showSavedBanner = false
        }

        updateCalls.withValue { XCTAssertEqual($0, [20]) }
        rescheduleCalls.withValue { calls in
            XCTAssertEqual(calls.count, 1)
            XCTAssertEqual(calls.first?.0, .posture)
            XCTAssertEqual(calls.first?.1.breakDuration, 20)
            XCTAssertEqual(calls.first?.1.interval, 1800,
                           "Reschedule snapshot must carry the unchanged posture interval")
        }
        analyticsEvents.withValue { events in
            guard case let .settingChanged(setting, oldValue, newValue) = events.first else {
                XCTFail("Expected .settingChanged; got \(String(describing: events.first))")
                return
            }
            XCTAssertEqual(setting, .postureBreakDuration)
            XCTAssertEqual(oldValue, "10.0")
            XCTAssertEqual(newValue, "20.0")
        }
    }

    func test_binding_postureInterval_rapidEdits_collapseToLatestValue() async {
        let clock = TestClock()
        let updateCalls = LockIsolated<[TimeInterval]>([])
        let rescheduleCalls = LockIsolated<[ReminderSettings]>([])

        var settings = TCATestDependencies.silentSettingsClient()
        settings.updatePostureInterval = { value in
            updateCalls.withValue { $0.append(value) }
        }

        var initial = SettingsFeature.State()
        initial.prevPostureInterval = 1800
        initial.postureInterval = 1800

        let store = TestStore(initialState: initial) {
            SettingsFeature()
        } withDependencies: {
            $0.settingsClient = settings
            $0.reminderSchedulerClient = ReminderSchedulerClient(
                scheduleReminders: { _ in },
                rescheduleReminder: { _, snapshot in
                    rescheduleCalls.withValue { $0.append(snapshot) }
                },
                cancelReminder: { _ in },
                cancelAllReminders: {}
            )
            $0.analyticsClient = AnalyticsClient(log: { _ in })
            $0.continuousClock = clock
        }

        await store.send(.binding(.set(\.postureInterval, 1500))) {
            $0.postureInterval = 1500
            $0.showSavedBanner = true
        }
        await store.send(.binding(.set(\.postureInterval, 1200))) {
            $0.postureInterval = 1200
        }
        await store.send(.binding(.set(\.postureInterval, 900))) {
            $0.postureInterval = 900
        }
        await clock.advance(by: .milliseconds(300))
        await clock.advance(by: .seconds(4))
        await store.receive(\.savedBannerExpired) {
            $0.showSavedBanner = false
        }

        updateCalls.withValue { calls in
            XCTAssertEqual(calls, [900],
                           "cancelInFlight debounce must collapse rapid posture-interval edits to the latest value")
        }
        rescheduleCalls.withValue { snapshots in
            XCTAssertEqual(snapshots.count, 1)
            XCTAssertEqual(snapshots.first?.interval, 900)
        }
    }
}

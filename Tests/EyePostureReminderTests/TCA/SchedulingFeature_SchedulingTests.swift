import ComposableArchitecture
import UserNotifications
import XCTest

@testable import EyePostureReminder

/// `TestStore` parity coverage for `SchedulingFeature` — Phase 3 issue
/// `p0-tca-17` (#680). Covers the `.scheduleReminders` and `.rescheduleType`
/// branches of the reducer (history: ported in `#755` Phase E, PR #760;
/// per-type interval differentiation enabled in #897).
///
/// Behavioural-fidelity caveats from the `SchedulingFeature` preamble
/// (deferred to Phase 2):
///   * `analytics.log(.schedulePathSelected(...))` is not yet emitted by the
///     reducer, so the matching assertion is omitted here.
@MainActor
final class SchedulingFeatureSchedulingTests: XCTestCase {

    // MARK: - .scheduleReminders — authorized path

    /// `.scheduleReminders` with `.authorized` and no active snooze must:
    ///   * refresh the cached auth status,
    ///   * skip the snooze-wake notification (no snooze),
    ///   * call `cancelSnoozeWake` to evict any stale wake task,
    ///   * forward the cached per-type `ReminderSettings` pair to
    ///     `schedulerClient.scheduleReminders` (#897),
    ///   * configure the tracker for both reminder types.
    func test_scheduleReminders_authorized_callsScheduleAndConfiguresTracker() async {
        let scheduledSnapshots = LockIsolated<[(ReminderSettings, ReminderSettings)]>([])
        let cancelledAll = LockIsolated(0)
        let setThresholds = LockIsolated<[(TimeInterval, ReminderType)]>([])
        let enabledTypes = LockIsolated<[ReminderType]>([])
        let resumedAll = LockIsolated(0)
        let removedPending = LockIsolated<[[String]]>([])

        var initial = SchedulingFeature.State()
        initial.settings = ReminderSettings(interval: 1200, breakDuration: 20)
        initial.postureSettings = ReminderSettings(interval: 1800, breakDuration: 30)

        let store = TestStore(initialState: initial) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
            $0.notificationClient = TCATestDependencies.silentNotificationClient(
                authorizationStatus: .authorized
            )
            $0.notificationClient.removePending = { ids in
                removedPending.withValue { $0.append(ids) }
            }
            $0.reminderSchedulerClient = ReminderSchedulerClient(
                scheduleReminders: { eyes, posture in
                    scheduledSnapshots.withValue { $0.append((eyes, posture)) }
                },
                rescheduleReminder: { _, _ in },
                cancelReminder: { _ in },
                cancelAllReminders: { cancelledAll.withValue { $0 += 1 } }
            )
            $0.screenTimeTrackerClient = ScreenTimeTrackerClient(
                setThreshold: { interval, type in
                    setThresholds.withValue { $0.append((interval, type)) }
                },
                enableTracking: { type in enabledTypes.withValue { $0.append(type) } },
                disableTracking: { _ in },
                pauseAll: {},
                resumeAll: { resumedAll.withValue { $0 += 1 } },
                reset: { _ in },
                thresholdReached: { .finished }
            )
        }

        await store.send(.scheduleReminders)
        await store.receive(.internalAction(.authStatusRefreshed(.authorized))) {
            $0.notificationAuthStatus = .authorized
        }
        await store.receive(.internalAction(.cancelSnoozeWake))

        await store.finish()

        XCTAssertEqual(scheduledSnapshots.value.count, 1,
                       "Authorized + no snooze must invoke scheduleReminders exactly once")
        XCTAssertEqual(scheduledSnapshots.value.first?.0,
                       ReminderSettings(interval: 1200, breakDuration: 20),
                       "Scheduler must receive the cached eyes-side settings snapshot")
        XCTAssertEqual(scheduledSnapshots.value.first?.1,
                       ReminderSettings(interval: 1800, breakDuration: 30),
                       "Scheduler must receive the cached posture-side settings snapshot (#897)")
        XCTAssertEqual(cancelledAll.value, 0,
                       "Authorized path must not invoke cancelAllReminders")
        XCTAssertEqual(setThresholds.value.count, 2,
                       "Tracker must be configured for both reminder types")
        XCTAssertEqual(Set(enabledTypes.value), Set(ReminderType.allCases),
                       "Both reminder types must have tracking enabled")
        // Per-type intervals (#897): tracker thresholds use eyes / posture
        // values independently rather than both reading from `state.settings`.
        let thresholdsByType = Dictionary(
            uniqueKeysWithValues: setThresholds.value.map { ($1, $0) }
        )
        XCTAssertEqual(thresholdsByType[.eyes], 1200,
                       "Eyes-side tracker must use eyes interval (#897)")
        XCTAssertEqual(thresholdsByType[.posture], 1800,
                       "Posture-side tracker must use posture interval (#897)")
        XCTAssertEqual(resumedAll.value, 1,
                       "configureTracker must resume tracking after enabling per-type")
        XCTAssertEqual(removedPending.value, [[SchedulingFeature.snoozeWakeCategory]],
                       "cancelSnoozeWake must remove the snooze-wake notification id")
    }

    // MARK: - .scheduleReminders — unauthorized path

    /// `.scheduleReminders` while notifications are denied must call
    /// `cancelAllReminders` instead of scheduling — unauthorized-path
    /// regression coverage (#755 Phase E).
    func test_scheduleReminders_unauthorized_cancelsAllReminders() async {
        let scheduledCount = LockIsolated(0)
        let cancelledAll = LockIsolated(0)

        let store = TestStore(initialState: SchedulingFeature.State()) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
            $0.notificationClient = TCATestDependencies.silentNotificationClient(
                authorizationStatus: .denied
            )
            $0.reminderSchedulerClient = ReminderSchedulerClient(
                scheduleReminders: { _, _ in scheduledCount.withValue { $0 += 1 } },
                rescheduleReminder: { _, _ in },
                cancelReminder: { _ in },
                cancelAllReminders: { cancelledAll.withValue { $0 += 1 } }
            )
        }

        await store.send(.scheduleReminders)
        await store.receive(.internalAction(.authStatusRefreshed(.denied))) {
            $0.notificationAuthStatus = .denied
        }
        await store.receive(.internalAction(.cancelSnoozeWake))
        await store.finish()

        XCTAssertEqual(scheduledCount.value, 0,
                       "Unauthorized path must not schedule")
        XCTAssertEqual(cancelledAll.value, 1,
                       "Unauthorized path must cancel all pending reminders")
    }

    // MARK: - .scheduleReminders — UI-test mode skips tracker reconfig

    /// UI-test mode must short-circuit the foreground tracker reconfig —
    /// UI-test guard inside `scheduleRemindersEffect` (#755 Phase E).
    func test_scheduleReminders_uiTestMode_skipsTrackerConfig() async {
        let setThresholdCount = LockIsolated(0)

        var initial = SchedulingFeature.State()
        initial.isUITestModeEnabled = true

        let store = TestStore(initialState: initial) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
            $0.notificationClient = TCATestDependencies.silentNotificationClient(
                authorizationStatus: .authorized
            )
            $0.screenTimeTrackerClient = ScreenTimeTrackerClient(
                setThreshold: { _, _ in setThresholdCount.withValue { $0 += 1 } },
                enableTracking: { _ in },
                disableTracking: { _ in },
                pauseAll: {},
                resumeAll: {},
                reset: { _ in },
                thresholdReached: { .finished }
            )
        }

        await store.send(.scheduleReminders)
        await store.receive(.internalAction(.authStatusRefreshed(.authorized))) {
            $0.notificationAuthStatus = .authorized
        }
        await store.receive(.internalAction(.cancelSnoozeWake))
        await store.finish()

        XCTAssertEqual(setThresholdCount.value, 0,
                       "UI-test mode must not reconfigure the foreground tracker")
    }

    // MARK: - .rescheduleType — debounce

    /// Two rapid `.rescheduleType(.eyes)` calls within the 300 ms debounce
    /// window must collapse to a single tracker / scheduler invocation, per
    /// `rescheduleTypeEffect`'s `.cancellable(..., cancelInFlight: true)`.
    func test_rescheduleType_doubleFireWithinDebounce_collapsesToSingleInvocation() async {
        let clock = TestClock()
        let setThresholds = LockIsolated<[ReminderType]>([])
        let rescheduledTypes = LockIsolated<[ReminderType]>([])

        var initial = SchedulingFeature.State()
        initial.settings = ReminderSettings(interval: 1200, breakDuration: 20)
        initial.notificationAuthStatus = .authorized

        let store = TestStore(initialState: initial) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
            $0.continuousClock = clock
            $0.notificationClient = TCATestDependencies.silentNotificationClient(
                authorizationStatus: .authorized
            )
            $0.reminderSchedulerClient = ReminderSchedulerClient(
                scheduleReminders: { _, _ in },
                rescheduleReminder: { type, _ in
                    rescheduledTypes.withValue { $0.append(type) }
                },
                cancelReminder: { _ in },
                cancelAllReminders: {}
            )
            $0.screenTimeTrackerClient = ScreenTimeTrackerClient(
                setThreshold: { _, type in setThresholds.withValue { $0.append(type) } },
                enableTracking: { _ in },
                disableTracking: { _ in },
                pauseAll: {},
                resumeAll: {},
                reset: { _ in },
                thresholdReached: { .finished }
            )
        }

        await store.send(.rescheduleType(.eyes))
        await store.send(.rescheduleType(.eyes))

        await clock.advance(by: .milliseconds(300))
        await store.receive(.internalAction(.authStatusRefreshed(.authorized)))

        await store.finish()

        XCTAssertEqual(setThresholds.value, [.eyes],
                       "Debounce must collapse double-fire to a single tracker call")
        XCTAssertEqual(rescheduledTypes.value, [.eyes],
                       "Debounce must collapse double-fire to a single scheduler call")
    }

    // MARK: - .rescheduleType — interval == 0 disables tracking

    /// When the per-type interval is 0 the reducer must disable tracking and
    /// cancel scheduled reminders for that type — disable-debounce branch
    /// of `.rescheduleType` (#755 Phase E).
    func test_rescheduleType_intervalZero_disablesAndCancels() async {
        let clock = TestClock()
        let disabledTypes = LockIsolated<[ReminderType]>([])
        let cancelledTypes = LockIsolated<[ReminderType]>([])

        var initial = SchedulingFeature.State()
        initial.settings = ReminderSettings(interval: 0, breakDuration: 20)
        initial.notificationAuthStatus = .authorized

        let store = TestStore(initialState: initial) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
            $0.continuousClock = clock
            $0.notificationClient = TCATestDependencies.silentNotificationClient(
                authorizationStatus: .authorized
            )
            $0.reminderSchedulerClient = ReminderSchedulerClient(
                scheduleReminders: { _, _ in },
                rescheduleReminder: { _, _ in },
                cancelReminder: { type in cancelledTypes.withValue { $0.append(type) } },
                cancelAllReminders: {}
            )
            $0.screenTimeTrackerClient = ScreenTimeTrackerClient(
                setThreshold: { _, _ in },
                enableTracking: { _ in },
                disableTracking: { type in disabledTypes.withValue { $0.append(type) } },
                pauseAll: {},
                resumeAll: {},
                reset: { _ in },
                thresholdReached: { .finished }
            )
        }

        await store.send(.rescheduleType(.posture))
        await clock.advance(by: .milliseconds(300))
        await store.receive(.internalAction(.authStatusRefreshed(.authorized)))

        await store.finish()

        XCTAssertEqual(disabledTypes.value, [.posture])
        XCTAssertEqual(cancelledTypes.value, [.posture])
    }

    // MARK: - .rescheduleType — unauthorized path

    /// While notifications are denied the reducer must keep tracker enabled
    /// (so the foreground threshold path still fires) but cancel any pending
    /// scheduled notifications, per `rescheduleTypeEffect`'s authorized vs.
    /// denied scheduler branches.
    func test_rescheduleType_unauthorized_keepsTrackerCancelsScheduler() async {
        let clock = TestClock()
        let cancelledTypes = LockIsolated<[ReminderType]>([])
        let rescheduledTypes = LockIsolated<[ReminderType]>([])
        let enabledTypes = LockIsolated<[ReminderType]>([])

        var initial = SchedulingFeature.State()
        initial.settings = ReminderSettings(interval: 600, breakDuration: 30)

        let store = TestStore(initialState: initial) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
            $0.continuousClock = clock
            $0.notificationClient = TCATestDependencies.silentNotificationClient(
                authorizationStatus: .denied
            )
            $0.reminderSchedulerClient = ReminderSchedulerClient(
                scheduleReminders: { _, _ in },
                rescheduleReminder: { type, _ in
                    rescheduledTypes.withValue { $0.append(type) }
                },
                cancelReminder: { type in cancelledTypes.withValue { $0.append(type) } },
                cancelAllReminders: {}
            )
            $0.screenTimeTrackerClient = ScreenTimeTrackerClient(
                setThreshold: { _, _ in },
                enableTracking: { type in enabledTypes.withValue { $0.append(type) } },
                disableTracking: { _ in },
                pauseAll: {},
                resumeAll: {},
                reset: { _ in },
                thresholdReached: { .finished }
            )
        }

        await store.send(.rescheduleType(.eyes))
        await clock.advance(by: .milliseconds(300))
        await store.receive(.internalAction(.authStatusRefreshed(.denied))) {
            $0.notificationAuthStatus = .denied
        }

        await store.finish()

        XCTAssertEqual(enabledTypes.value, [.eyes],
                       "Unauthorized path must still arm the foreground tracker")
        XCTAssertEqual(rescheduledTypes.value, [],
                       "Unauthorized path must skip scheduler.rescheduleReminder")
        XCTAssertEqual(cancelledTypes.value, [.eyes],
                       "Unauthorized path must cancel any pending scheduled reminder")
    }

    // MARK: - .settingsChanged — pure state write

    /// `.settingsChanged` is a synchronous state write fed by the
    /// settings-stream effect; it must update `state.settings` and produce no
    /// follow-up effect.
    func test_settingsChanged_writesStateWithoutEffect() async {
        let store = TestStore(initialState: SchedulingFeature.State()) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
        }

        let updated = ReminderSettings(interval: 1500, breakDuration: 25)
        await store.send(.settingsChanged(updated)) {
            $0.settings = updated
        }
    }

    // MARK: - .backgroundTransition — emits appSessionEnd analytics

    /// `.backgroundTransition` emits `.appSessionEnd` so Console.app traces
    /// show the session boundary after the migration (#755 Phase E).
    func test_backgroundTransition_logsAppSessionEnd() async {
        let loggedEvents = LockIsolated<[String]>([])

        let store = TestStore(initialState: SchedulingFeature.State()) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
            $0.analyticsClient = AnalyticsClient(log: { event in
                loggedEvents.withValue { $0.append(String(describing: event)) }
            })
        }

        await store.send(.backgroundTransition)
        await store.finish()

        XCTAssertEqual(loggedEvents.value.count, 1)
        XCTAssertTrue(loggedEvents.value[0].contains("appSessionEnd"),
                      "backgroundTransition must emit appSessionEnd analytics")
    }

    // MARK: - .postureSettingsChanged — pure state write

    /// `.postureSettingsChanged` is a synchronous state write fed by the
    /// posture-settings-stream effect (#897); it must update
    /// `state.postureSettings` without producing a follow-up effect and
    /// must leave the eyes-side `state.settings` untouched.
    func test_postureSettingsChanged_writesPostureStateOnly() async {
        var initial = SchedulingFeature.State()
        initial.settings = ReminderSettings(interval: 1200, breakDuration: 20)

        let store = TestStore(initialState: initial) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
        }

        let updatedPosture = ReminderSettings(interval: 1800, breakDuration: 30)
        await store.send(.postureSettingsChanged(updatedPosture)) {
            $0.postureSettings = updatedPosture
        }
        XCTAssertEqual(store.state.settings,
                       ReminderSettings(interval: 1200, breakDuration: 20),
                       "Posture-side write must not perturb the eyes-side snapshot (#897)")
    }

    // MARK: - .rescheduleType — per-type interval differentiation (#897)

    /// `.rescheduleType(.posture)` must forward the cached posture-side
    /// `ReminderSettings` to `schedulerClient.rescheduleReminder` instead
    /// of reusing the eyes-side snapshot — per-type interval split (#897).
    func test_rescheduleType_posture_usesPostureSettings() async {
        let clock = TestClock()
        let rescheduledCalls = LockIsolated<[(ReminderType, ReminderSettings)]>([])
        let setThresholds = LockIsolated<[(TimeInterval, ReminderType)]>([])

        var initial = SchedulingFeature.State()
        // Eyes interval is distinct from posture so a regression that
        // re-reads `state.settings` instead of `state.postureSettings`
        // fails this assertion.
        initial.settings = ReminderSettings(interval: 1200, breakDuration: 20)
        initial.postureSettings = ReminderSettings(interval: 2400, breakDuration: 45)
        initial.notificationAuthStatus = .authorized

        let store = TestStore(initialState: initial) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
            $0.continuousClock = clock
            $0.notificationClient = TCATestDependencies.silentNotificationClient(
                authorizationStatus: .authorized
            )
            $0.reminderSchedulerClient = ReminderSchedulerClient(
                scheduleReminders: { _, _ in },
                rescheduleReminder: { type, settings in
                    rescheduledCalls.withValue { $0.append((type, settings)) }
                },
                cancelReminder: { _ in },
                cancelAllReminders: {}
            )
            $0.screenTimeTrackerClient = ScreenTimeTrackerClient(
                setThreshold: { interval, type in
                    setThresholds.withValue { $0.append((interval, type)) }
                },
                enableTracking: { _ in },
                disableTracking: { _ in },
                pauseAll: {},
                resumeAll: {},
                reset: { _ in },
                thresholdReached: { .finished }
            )
        }

        await store.send(.rescheduleType(.posture))
        await clock.advance(by: .milliseconds(300))
        await store.receive(.internalAction(.authStatusRefreshed(.authorized)))

        await store.finish()

        XCTAssertEqual(rescheduledCalls.value.count, 1,
                       "Posture reschedule must hit the scheduler exactly once")
        XCTAssertEqual(rescheduledCalls.value.first?.0, .posture)
        XCTAssertEqual(rescheduledCalls.value.first?.1,
                       ReminderSettings(interval: 2400, breakDuration: 45),
                       "Posture reschedule must forward the posture-side settings (#897)")
        XCTAssertEqual(setThresholds.value.count, 1)
        XCTAssertEqual(setThresholds.value.first?.0, 2400,
                       "Posture tracker threshold must use the posture interval (#897)")
        XCTAssertEqual(setThresholds.value.first?.1, .posture,
                       "Posture tracker threshold must target the posture type")
    }

    /// `.rescheduleType(.eyes)` must continue to use the eyes-side
    /// settings even when the posture interval is different — guards
    /// the eyes path against an accidental flip to `postureSettings`.
    func test_rescheduleType_eyes_usesEyesSettingsWhenPostureDiffers() async {
        let clock = TestClock()
        let rescheduledCalls = LockIsolated<[(ReminderType, ReminderSettings)]>([])
        let setThresholds = LockIsolated<[(TimeInterval, ReminderType)]>([])

        var initial = SchedulingFeature.State()
        initial.settings = ReminderSettings(interval: 900, breakDuration: 15)
        initial.postureSettings = ReminderSettings(interval: 2400, breakDuration: 45)
        initial.notificationAuthStatus = .authorized

        let store = TestStore(initialState: initial) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
            $0.continuousClock = clock
            $0.notificationClient = TCATestDependencies.silentNotificationClient(
                authorizationStatus: .authorized
            )
            $0.reminderSchedulerClient = ReminderSchedulerClient(
                scheduleReminders: { _, _ in },
                rescheduleReminder: { type, settings in
                    rescheduledCalls.withValue { $0.append((type, settings)) }
                },
                cancelReminder: { _ in },
                cancelAllReminders: {}
            )
            $0.screenTimeTrackerClient = ScreenTimeTrackerClient(
                setThreshold: { interval, type in
                    setThresholds.withValue { $0.append((interval, type)) }
                },
                enableTracking: { _ in },
                disableTracking: { _ in },
                pauseAll: {},
                resumeAll: {},
                reset: { _ in },
                thresholdReached: { .finished }
            )
        }

        await store.send(.rescheduleType(.eyes))
        await clock.advance(by: .milliseconds(300))
        await store.receive(.internalAction(.authStatusRefreshed(.authorized)))

        await store.finish()

        XCTAssertEqual(rescheduledCalls.value.first?.1,
                       ReminderSettings(interval: 900, breakDuration: 15),
                       "Eyes reschedule must keep using the eyes-side settings (#897)")
        XCTAssertEqual(setThresholds.value.count, 1)
        XCTAssertEqual(setThresholds.value.first?.0, 900,
                       "Eyes tracker threshold must use the eyes interval (#897)")
        XCTAssertEqual(setThresholds.value.first?.1, .eyes,
                       "Eyes tracker threshold must target the eyes type")
    }
}

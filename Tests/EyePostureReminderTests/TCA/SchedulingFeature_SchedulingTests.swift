import ComposableArchitecture
import UserNotifications
import XCTest

@testable import EyePostureReminder

/// `TestStore` parity coverage for `SchedulingFeature` — Phase 3 issue
/// `p0-tca-17` (#680). Mirrors the scheduling and reschedule paths exercised
/// by the legacy `AppCoordinatorTests` family
/// (`AppCoordinatorTests`, `AppCoordinatorCancelReminderTests`,
/// `AppCoordinatorThresholdGuardTests`).
///
/// Behavioural-fidelity caveats from `SchedulingFeature.swift` lines 18-31
/// (deferred to Phase 2):
///   * `analytics.log(.schedulePathSelected(...))` is not yet emitted by the
///     reducer, so the matching assertion is omitted here.
///   * Per-type interval differentiation is collapsed onto
///     `state.settings.interval`.
@MainActor
final class SchedulingFeatureSchedulingTests: XCTestCase {

    // MARK: - .scheduleReminders — authorized path

    /// `.scheduleReminders` with `.authorized` and no active snooze must:
    ///   * refresh the cached auth status,
    ///   * skip the snooze-wake notification (no snooze),
    ///   * call `cancelSnoozeWake` to evict any stale wake task,
    ///   * forward the cached `ReminderSettings` to
    ///     `schedulerClient.scheduleReminders`,
    ///   * configure the tracker for both reminder types.
    func test_scheduleReminders_authorized_callsScheduleAndConfiguresTracker() async {
        let scheduledSnapshots = LockIsolated<[ReminderSettings]>([])
        let cancelledAll = LockIsolated(0)
        let setThresholds = LockIsolated<[(TimeInterval, ReminderType)]>([])
        let enabledTypes = LockIsolated<[ReminderType]>([])
        let resumedAll = LockIsolated(0)
        let removedPending = LockIsolated<[[String]]>([])

        var initial = SchedulingFeature.State()
        initial.settings = ReminderSettings(interval: 1200, breakDuration: 20)

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
                scheduleReminders: { snap in
                    scheduledSnapshots.withValue { $0.append(snap) }
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
        XCTAssertEqual(scheduledSnapshots.value.first,
                       ReminderSettings(interval: 1200, breakDuration: 20),
                       "Scheduler must receive the cached settings snapshot")
        XCTAssertEqual(cancelledAll.value, 0,
                       "Authorized path must not invoke cancelAllReminders")
        XCTAssertEqual(setThresholds.value.count, 2,
                       "Tracker must be configured for both reminder types")
        XCTAssertEqual(Set(enabledTypes.value), Set(ReminderType.allCases),
                       "Both reminder types must have tracking enabled")
        XCTAssertEqual(resumedAll.value, 1,
                       "configureTracker must resume tracking after enabling per-type")
        XCTAssertEqual(removedPending.value, [[SchedulingFeature.snoozeWakeCategory]],
                       "cancelSnoozeWake must remove the snooze-wake notification id")
    }

    // MARK: - .scheduleReminders — unauthorized path

    /// `.scheduleReminders` while notifications are denied must call
    /// `cancelAllReminders` instead of scheduling, mirroring
    /// `AppCoordinator.scheduleReminders` lines 432-447.
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
                scheduleReminders: { _ in scheduledCount.withValue { $0 += 1 } },
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

    /// UI-test mode must short-circuit the foreground tracker reconfig per
    /// `AppCoordinator.scheduleReminders` lines 452-455 — same parity carried
    /// over to `scheduleRemindersEffect` line 222.
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
    /// `rescheduleTypeEffect` line 264 (`cancelInFlight: true`).
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
                scheduleReminders: { _ in },
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
    /// cancel scheduled reminders for that type, mirroring
    /// `AppCoordinator.performReschedule` lines 234-249.
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
                scheduleReminders: { _ in },
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
    /// scheduled notifications, per `rescheduleTypeEffect` lines 254-258.
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
                scheduleReminders: { _ in },
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

    /// `.backgroundTransition` mirrors `AppCoordinator.appWillResignActive` by
    /// emitting `.appSessionEnd` so Console.app traces show the session
    /// boundary even after the migration.
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
}

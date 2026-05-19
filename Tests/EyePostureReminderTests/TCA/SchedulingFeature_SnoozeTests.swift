import ComposableArchitecture
@preconcurrency import UserNotifications
import XCTest

@testable import EyePostureReminder

/// `TestStore` parity coverage for `SchedulingFeature`'s snooze paths —
/// Phase 3 issue `p0-tca-17` (#680). Covers the snooze-wake / snooze-branch
/// behaviour of the reducer (history: ported in `#755` Phase E, PR #760).
@MainActor
final class SchedulingFeatureSnoozeTests: XCTestCase {

    // MARK: - .scheduleReminders — active snooze branch

    /// `.scheduleReminders` while a snooze window is active must:
    ///   * pause every reminder type via the tracker,
    ///   * cancel every pending scheduled reminder,
    ///   * arm the snooze-wake clock task via `.scheduleSnoozeWake`,
    ///   * schedule the silent snooze-wake notification when authorized.
    /// Active-snooze branch of `.scheduleReminders` (#755 Phase E).
    func test_scheduleReminders_activeSnooze_authorized_pausesAndArmsWake() async {
        // The active-snooze guard inside `scheduleRemindersEffect` compares
        // against the system wall-clock (`Date()`), not `@Dependency(\.date)`,
        // so we have to pick a wall-clock-future timestamp. Using
        // `Date.distantFuture` keeps the test deterministic across machines.
        let snoozedUntil = Date.distantFuture
        let pausedAll = LockIsolated(0)
        let cancelledAll = LockIsolated(0)
        let scheduledNotifications = LockIsolated<[String]>([])

        var initial = SchedulingFeature.State()
        initial.snoozedUntil = snoozedUntil

        let store = TestStore(initialState: initial) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
            // `.scheduleSnoozeWake` uses both `now()` and `continuousClock`
            // to arm a clock.sleep wake task; provide test doubles so the
            // unimplemented defaults don't trip when `.stop` cancels the task.
            $0.date = .constant(Date(timeIntervalSince1970: 1_700_000_000))
            $0.continuousClock = TestClock()
            $0.notificationClient = NotificationClient(
                requestAuthorization: { _ in false },
                authorizationStatus: { .authorized },
                add: { request in
                    scheduledNotifications.withValue { $0.append(request.identifier) }
                },
                removePending: { _ in },
                removeAllPending: {},
                pendingRequests: { [] },
                deliveredNotifications: { [] }
            )
            $0.reminderSchedulerClient = ReminderSchedulerClient(
                scheduleReminders: { _, _ in },
                rescheduleReminder: { _, _ in },
                cancelReminder: { _ in },
                cancelAllReminders: { cancelledAll.withValue { $0 += 1 } }
            )
            $0.screenTimeTrackerClient = ScreenTimeTrackerClient(
                setThreshold: { _, _ in },
                enableTracking: { _ in },
                disableTracking: { _ in },
                pauseAll: { pausedAll.withValue { $0 += 1 } },
                resumeAll: {},
                reset: { _ in },
                thresholdReached: { .finished }
            )
        }

        await store.send(.scheduleReminders)
        await store.receive(.internalAction(.authStatusRefreshed(.authorized))) {
            $0.notificationAuthStatus = .authorized
        }
        await store.receive(.internalAction(.scheduleSnoozeWake(snoozedUntil)))

        // The snooze-wake task is a long-running clock.sleep effect; cancel it
        // so `store.finish()` doesn't trip on outstanding effects.
        await store.send(.stop)

        XCTAssertEqual(pausedAll.value, 1, "Active snooze must pause every type")
        XCTAssertEqual(cancelledAll.value, 1,
                       "Active snooze must cancel every pending reminder")
        XCTAssertEqual(scheduledNotifications.value,
                       [SchedulingFeature.snoozeWakeCategory],
                       "Authorized + active snooze must schedule a silent wake notification")
    }

    /// `.scheduleReminders` with an active snooze but no notification
    /// authorisation must skip the silent-wake notification but still arm
    /// the in-process snooze-wake task — unauthorized-guard inside
    /// `scheduleSnoozeWakeNotificationEffect` (#755 Phase E).
    func test_scheduleReminders_activeSnooze_unauthorized_skipsSilentNotification() async {
        let snoozedUntil = Date.distantFuture
        let scheduledNotifications = LockIsolated<[String]>([])

        var initial = SchedulingFeature.State()
        initial.snoozedUntil = snoozedUntil

        let store = TestStore(initialState: initial) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
            $0.date = .constant(Date(timeIntervalSince1970: 1_700_000_000))
            $0.continuousClock = TestClock()
            $0.notificationClient = NotificationClient(
                requestAuthorization: { _ in false },
                authorizationStatus: { .denied },
                add: { request in
                    scheduledNotifications.withValue { $0.append(request.identifier) }
                },
                removePending: { _ in },
                removeAllPending: {},
                pendingRequests: { [] },
                deliveredNotifications: { [] }
            )
        }

        await store.send(.scheduleReminders)
        await store.receive(.internalAction(.authStatusRefreshed(.denied))) {
            $0.notificationAuthStatus = .denied
        }
        await store.receive(.internalAction(.scheduleSnoozeWake(snoozedUntil)))

        await store.send(.stop)

        XCTAssertTrue(scheduledNotifications.value.isEmpty,
                      "Denied notifications must skip the silent snooze-wake post")
    }

    // MARK: - .scheduleReminders — expired snooze branch

    /// An expired snooze must be cleared before the regular schedule path
    /// runs — expired-snooze branch of `.scheduleReminders`
    /// (#755 Phase E).
    func test_scheduleReminders_expiredSnooze_clearsThenSchedules() async {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let snoozedUntil = now.addingTimeInterval(-60)  // expired one minute ago
        let setUntilCalls = LockIsolated<[Date?]>([])
        let setCountCalls = LockIsolated<[Int]>([])
        let loggedEvents = LockIsolated<[String]>([])

        var initial = SchedulingFeature.State()
        initial.snoozedUntil = snoozedUntil

        let store = TestStore(initialState: initial) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
            $0.date = .constant(now)
            $0.notificationClient = TCATestDependencies.silentNotificationClient(
                authorizationStatus: .authorized
            )
            var settings = TCATestDependencies.silentSettingsClient()
            settings.setSnoozedUntil = { value in
                setUntilCalls.withValue { $0.append(value) }
            }
            settings.setSnoozeCount = { value in
                setCountCalls.withValue { $0.append(value) }
            }
            $0.settingsClient = settings
            $0.analyticsClient = AnalyticsClient(log: { event in
                loggedEvents.withValue { $0.append(String(describing: event)) }
            })
        }

        await store.send(.scheduleReminders)
        await store.receive(.internalAction(.authStatusRefreshed(.authorized))) {
            $0.notificationAuthStatus = .authorized
        }
        await store.receive(.internalAction(.snoozeStateCleared)) {
            $0.snoozedUntil = nil
        }
        await store.receive(.internalAction(.cancelSnoozeWake))
        await store.finish()

        XCTAssertEqual(setUntilCalls.value, [nil],
                       "Expired snooze must clear settingsClient.snoozedUntil")
        XCTAssertEqual(setCountCalls.value, [0],
                       "Expired snooze must reset settingsClient.snoozeCount")
        XCTAssertEqual(loggedEvents.value.count, 1)
        XCTAssertTrue(loggedEvents.value[0].contains("snoozeExpired"),
                      "Expired snooze must emit .snoozeExpired analytics")
    }

    // MARK: - .clearExpiredSnoozeIfNeeded

    /// A future snooze remains untouched.
    func test_clearExpiredSnoozeIfNeeded_futureSnooze_isNoOp() async {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        var initial = SchedulingFeature.State()
        initial.snoozedUntil = now.addingTimeInterval(60 * 60)

        let store = TestStore(initialState: initial) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
            $0.date = .constant(now)
        }

        await store.send(.clearExpiredSnoozeIfNeeded)
        await store.finish()
    }

    /// A `nil` snooze remains a no-op.
    func test_clearExpiredSnoozeIfNeeded_noSnooze_isNoOp() async {
        let store = TestStore(initialState: SchedulingFeature.State()) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
        }

        await store.send(.clearExpiredSnoozeIfNeeded)
        await store.finish()
    }

    /// An expired snooze must be cleared from state, persisted via the
    /// settings client, and emit `.snoozeExpired` analytics — clears the
    /// snooze counter via `.clearExpiredSnoozeIfNeeded` (#755 Phase E).
    func test_clearExpiredSnoozeIfNeeded_expiredSnooze_clearsState() async {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let setUntilCalls = LockIsolated<[Date?]>([])
        let setCountCalls = LockIsolated<[Int]>([])
        let loggedEvents = LockIsolated<[String]>([])

        var initial = SchedulingFeature.State()
        initial.snoozedUntil = now.addingTimeInterval(-30)

        let store = TestStore(initialState: initial) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
            $0.date = .constant(now)
            var settings = TCATestDependencies.silentSettingsClient()
            settings.setSnoozedUntil = { value in
                setUntilCalls.withValue { $0.append(value) }
            }
            settings.setSnoozeCount = { value in
                setCountCalls.withValue { $0.append(value) }
            }
            $0.settingsClient = settings
            $0.analyticsClient = AnalyticsClient(log: { event in
                loggedEvents.withValue { $0.append(String(describing: event)) }
            })
        }

        await store.send(.clearExpiredSnoozeIfNeeded) {
            $0.snoozedUntil = nil
        }
        await store.finish()

        XCTAssertEqual(setUntilCalls.value, [nil])
        XCTAssertEqual(setCountCalls.value, [0])
        XCTAssertEqual(loggedEvents.value.count, 1)
        XCTAssertTrue(loggedEvents.value[0].contains("snoozeExpired"))
    }

    // MARK: - .snoozeWakeFired

    /// `.snoozeWakeFired` clears state, persists, logs analytics, and
    /// re-runs `.scheduleReminders` so the regular schedule resumes —
    /// snooze-wake delivery path inside `.notificationRouted(.snoozeWake)`
    /// (#755 Phase E).
    func test_snoozeWakeFired_clearsStateAndReschedules() async {
        let setUntilCalls = LockIsolated<[Date?]>([])
        let setCountCalls = LockIsolated<[Int]>([])
        let loggedEvents = LockIsolated<[String]>([])

        var initial = SchedulingFeature.State()
        initial.snoozedUntil = Date(timeIntervalSince1970: 1_700_000_000)

        let store = TestStore(initialState: initial) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
            var settings = TCATestDependencies.silentSettingsClient()
            settings.setSnoozedUntil = { value in
                setUntilCalls.withValue { $0.append(value) }
            }
            settings.setSnoozeCount = { value in
                setCountCalls.withValue { $0.append(value) }
            }
            $0.settingsClient = settings
            $0.analyticsClient = AnalyticsClient(log: { event in
                loggedEvents.withValue { $0.append(String(describing: event)) }
            })
        }

        await store.send(.snoozeWakeFired) {
            $0.snoozedUntil = nil
        }
        await store.receive(\.scheduleReminders)
        await store.receive(.internalAction(.authStatusRefreshed(.notDetermined)))
        await store.receive(.internalAction(.cancelSnoozeWake))
        await store.finish()

        XCTAssertEqual(setUntilCalls.value, [nil])
        XCTAssertEqual(setCountCalls.value, [0])
        XCTAssertTrue(loggedEvents.value.contains(where: { $0.contains("snoozeExpired") }))
    }

    // MARK: - reduceInternal(.scheduleSnoozeWake)

    /// `.scheduleSnoozeWake(date)` arms a `clock.sleep` task that fires
    /// `.snoozeWakeFired` once the wall-clock date passes.
    func test_scheduleSnoozeWake_firesAfterClockAdvances() async {
        let clock = TestClock()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let wake = now.addingTimeInterval(120)

        let store = TestStore(initialState: SchedulingFeature.State()) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
            $0.continuousClock = clock
            $0.date = .constant(now)
        }

        await store.send(.internalAction(.scheduleSnoozeWake(wake)))

        await clock.advance(by: .seconds(120))
        await store.receive(\.snoozeWakeFired)
        await store.receive(\.scheduleReminders)
        await store.receive(.internalAction(.authStatusRefreshed(.notDetermined)))
        await store.receive(.internalAction(.cancelSnoozeWake))

        await store.finish()
    }
}

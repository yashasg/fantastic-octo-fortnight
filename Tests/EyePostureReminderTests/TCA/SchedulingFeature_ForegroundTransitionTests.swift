import ComposableArchitecture
import UserNotifications
import XCTest

@testable import EyePostureReminder

/// `TestStore` parity coverage for `SchedulingFeature.foregroundTransition`
/// — Phase 3 issue `p0-tca-17` (#680). Mirrors the foreground branches of
/// the legacy `AppCoordinatorTests`.
@MainActor
final class SchedulingForegroundTransitionTests: XCTestCase {

    // MARK: - No snooze, unchanged auth status

    /// `.foregroundTransition` with no snooze and unchanged auth status must
    /// only refresh the cached auth status — no reschedule should fire.
    func test_foregroundTransition_noSnooze_sameAuthStatus_refreshesAuthOnly() async {
        var initial = SchedulingFeature.State()
        initial.notificationAuthStatus = .denied

        let store = TestStore(initialState: initial) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
            $0.notificationClient = TCATestDependencies.silentNotificationClient(
                authorizationStatus: .denied
            )
        }

        await store.send(.foregroundTransition)
        await store.receive(.internalAction(.authStatusRefreshed(.denied)))
        await store.finish()
    }

    // MARK: - No snooze, auth status changed

    /// When the cached auth status differs from the live one, the reducer
    /// must re-run `.scheduleReminders` so newly-granted authorisation gets
    /// picked up immediately, mirroring `handleForegroundTransition`
    /// lines 587-606.
    func test_foregroundTransition_noSnooze_authChanged_runsScheduleReminders() async {
        var initial = SchedulingFeature.State()
        initial.notificationAuthStatus = .notDetermined

        let store = TestStore(initialState: initial) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
            $0.notificationClient = TCATestDependencies.silentNotificationClient(
                authorizationStatus: .authorized
            )
        }

        await store.send(.foregroundTransition)
        await store.receive(.internalAction(.authStatusRefreshed(.authorized))) {
            $0.notificationAuthStatus = .authorized
        }
        await store.receive(\.scheduleReminders)
        await store.receive(.internalAction(.authStatusRefreshed(.authorized)))
        await store.receive(.internalAction(.cancelSnoozeWake))
        await store.finish()
    }

    // MARK: - Future snooze, authorized

    /// Future snooze + authorized notifications: reducer arms the wake task
    /// and posts the silent snooze-wake notification, but never re-runs
    /// `.scheduleReminders`. Direct port of `handleForegroundTransition`
    /// lines 588-595.
    func test_foregroundTransition_futureSnooze_authorized_armsWakeAndPostsSilentNotification() async {
        // Snooze branch in `foregroundTransitionEffect` compares `until <=
        // Date()` (system wall-clock), so use `Date.distantFuture` to keep
        // the test reproducible.
        let wake = Date.distantFuture
        let scheduledNotifications = LockIsolated<[String]>([])

        var initial = SchedulingFeature.State()
        initial.snoozedUntil = wake

        let store = TestStore(initialState: initial) {
            SchedulingFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
            // `.scheduleSnoozeWake` arms a clock.sleep effect that needs both
            // a date dep and a `ContinuousClock`; without these it trips the
            // unimplemented defaults when `.stop` cancels the wake task.
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
        }

        await store.send(.foregroundTransition)
        await store.receive(.internalAction(.authStatusRefreshed(.authorized))) {
            $0.notificationAuthStatus = .authorized
        }
        await store.receive(.internalAction(.scheduleSnoozeWake(wake)))

        await store.send(.stop)

        XCTAssertEqual(scheduledNotifications.value,
                       [SchedulingFeature.snoozeWakeCategory])
    }

    // MARK: - Future snooze, unauthorized

    /// Future snooze + denied notifications: reducer arms the wake task but
    /// must NOT post the silent notification (UNUserNotificationCenter would
    /// silently drop it anyway).
    func test_foregroundTransition_futureSnooze_unauthorized_skipsSilentNotification() async {
        let snoozedUntil = Date.distantFuture
        let scheduledNotifications = LockIsolated<[String]>([])

        var initial = SchedulingFeature.State()
        initial.snoozedUntil = snoozedUntil
        initial.notificationAuthStatus = .denied

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

        await store.send(.foregroundTransition)
        await store.receive(.internalAction(.authStatusRefreshed(.denied)))
        await store.receive(.internalAction(.scheduleSnoozeWake(snoozedUntil)))

        await store.send(.stop)

        XCTAssertTrue(scheduledNotifications.value.isEmpty)
    }

    // MARK: - Expired snooze on foreground

    /// Returning to foreground after a snooze expired must clear state and
    /// re-run scheduling — `handleForegroundTransition` lines 596-605.
    func test_foregroundTransition_expiredSnooze_clearsAndReschedules() async {
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

        await store.send(.foregroundTransition)
        await store.receive(.internalAction(.authStatusRefreshed(.authorized))) {
            $0.notificationAuthStatus = .authorized
        }
        await store.receive(.internalAction(.snoozeStateCleared)) {
            $0.snoozedUntil = nil
        }
        await store.receive(\.scheduleReminders)
        await store.receive(.internalAction(.authStatusRefreshed(.authorized)))
        await store.receive(.internalAction(.cancelSnoozeWake))
        await store.finish()

        XCTAssertEqual(setUntilCalls.value, [nil])
        XCTAssertEqual(setCountCalls.value, [0])
        XCTAssertTrue(loggedEvents.value.contains(where: { $0.contains("snoozeExpired") }))
    }
}

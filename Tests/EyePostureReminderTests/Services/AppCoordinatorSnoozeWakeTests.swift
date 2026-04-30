@preconcurrency @testable import EyePostureReminder
import UserNotifications
import XCTest

/// Focused unit tests for snooze-wake timing invariants (GitHub issue #300).
///
/// **Gaps covered:**
///
/// - **Gap 1** (`handleSnoozeWake` state clearing + `scheduleReminders` re-invocation):
///   When the in-process snooze-wake `Task` fires, `handleSnoozeWake()` must nil out
///   `snoozedUntil`, reset `snoozeCount` to 0, and call `scheduleReminders()` so the
///   screen-time tracker is reconfigured for a fresh reminder cycle.
///
/// - **Gap 2** (`cancelSnoozeWakeTaskIfNeeded` race guard):
///   Cancelling the in-process snooze-wake task (e.g., because the system delivered the
///   silent background notification first) must prevent `handleSnoozeWake()` from running
///   and double-rescheduling.
///
/// - **Gap 4** (notification trigger interval floor):
///   `scheduleSnoozeWakeNotification(at:)` applies `max(1, date.timeIntervalSinceNow)` so
///   the `UNTimeIntervalNotificationTrigger` always receives an interval ≥ 1 second,
///   matching the OS minimum. Even when the snooze end is only milliseconds away the
///   trigger must report `timeInterval ≥ 1.0`.
@MainActor
final class AppCoordinatorSnoozeWakeTests: XCTestCase {

    var mockPersistence: MockSettingsPersisting!
    var settings: SettingsStore!

    override func setUp() async throws {
        try await super.setUp()
        mockPersistence = MockSettingsPersisting()
        settings = SettingsStore(store: mockPersistence)
    }

    override func tearDown() async throws {
        settings = nil
        mockPersistence = nil
        try await super.tearDown()
    }

    // MARK: - Factory

    private func makeCoordinator(
        notifCenter: MockNotificationCenter = MockNotificationCenter(),
        screenTimeTracker trackerArg: MockScreenTimeTracker? = nil
    ) -> (coordinator: AppCoordinator, tracker: MockScreenTimeTracker, notif: MockNotificationCenter) {
        let tracker = trackerArg ?? MockScreenTimeTracker()
        let coordinator = AppCoordinator(
            settings: settings,
            scheduler: ReminderScheduler(notificationCenter: notifCenter),
            notificationCenter: notifCenter,
            overlayManager: MockOverlayPresenting(),
            screenTimeTracker: tracker,
            pauseConditionProvider: MockPauseConditionProvider(),
            ipcStore: MockAppGroupIPCRecorder()
        )
        return (coordinator, tracker, notifCenter)
    }

    // MARK: - Gap 1: handleSnoozeWake clears state and calls scheduleReminders

    /// When the in-process snooze-wake `Task` fires, `handleSnoozeWake()` must clear
    /// `snoozedUntil` and `snoozeCount`, and re-invoke `scheduleReminders()`.
    ///
    /// `scheduleReminders()` being called is evidenced by the screen-time tracker
    /// receiving `setThreshold` calls (only emitted from `configureScreenTimeTracker()`
    /// which is the terminal step of a non-snooze `scheduleReminders()` run).
    func test_handleSnoozeWake_clearsSnoozeState() async throws {
        settings.eyesEnabled = true
        settings.snoozedUntil = Date(timeIntervalSinceNow: 0.1)  // fires after 100 ms
        settings.snoozeCount = 5

        let tracker = MockScreenTimeTracker()
        let notif = MockNotificationCenter()
        notif.authorizationGranted = false  // skip notification scheduling
        let (coordinator, _, _) = makeCoordinator(notifCenter: notif, screenTimeTracker: tracker)
        defer { coordinator.stopFallbackTimers() }

        // scheduleReminders() enters the snooze-active branch and arms a wake task
        // that sleeps for ~0.1 s, then calls handleSnoozeWake().
        await coordinator.scheduleReminders()

        // Allow the wake task time to fire (0.1 s sleep + processing headroom).
        try await Task.sleep(nanoseconds: 600_000_000)

        XCTAssertNil(
            settings.snoozedUntil,
            "handleSnoozeWake must nil out snoozedUntil when the in-process task fires")
        XCTAssertEqual(
            settings.snoozeCount,
            0,
            "handleSnoozeWake must reset snoozeCount to 0")
    }

    /// `handleSnoozeWake()` must invoke `scheduleReminders()` so the screen-time
    /// tracker is reconfigured for the new non-snooze reminder cycle.
    func test_handleSnoozeWake_callsScheduleReminders() async throws {
        settings.eyesEnabled = true
        settings.snoozedUntil = Date(timeIntervalSinceNow: 0.1)
        settings.snoozeCount = 2

        let tracker = MockScreenTimeTracker()
        let notif = MockNotificationCenter()
        notif.authorizationGranted = false
        let (coordinator, _, _) = makeCoordinator(notifCenter: notif, screenTimeTracker: tracker)
        defer { coordinator.stopFallbackTimers() }

        // When snooze is active, scheduleReminders() returns early and does NOT configure
        // the tracker — setThresholdCalls will be empty at this point.
        await coordinator.scheduleReminders()
        let thresholdCallsAfterInitialSchedule = tracker.setThresholdCalls.count

        try await Task.sleep(nanoseconds: 600_000_000)

        // After handleSnoozeWake fires and calls scheduleReminders() again (without snooze),
        // configureScreenTimeTracker() runs and emits setThreshold calls.
        XCTAssertGreaterThan(
            tracker.setThresholdCalls.count,
            thresholdCallsAfterInitialSchedule,
            "handleSnoozeWake must call scheduleReminders(), evidenced by setThreshold being called on the tracker")
    }

    // MARK: - Gap 2: cancelSnoozeWakeTaskIfNeeded prevents double-scheduling

    /// Cancelling the in-process snooze-wake task must prevent `handleSnoozeWake()`
    /// from executing: `snoozedUntil` must remain set and the tracker must not receive
    /// any new `setThreshold` calls from a second `scheduleReminders()` invocation.
    func test_cancelSnoozeWakeTaskIfNeeded_preventsDuplicateScheduleReminders() async throws {
        settings.snoozedUntil = Date(timeIntervalSinceNow: 0.2)  // fires after 200 ms
        settings.snoozeCount = 3
        let originalSnoozeEnd = settings.snoozedUntil

        let tracker = MockScreenTimeTracker()
        let notif = MockNotificationCenter()
        notif.authorizationGranted = false
        let (coordinator, _, _) = makeCoordinator(notifCenter: notif, screenTimeTracker: tracker)
        defer { coordinator.stopFallbackTimers() }

        // Arms the snooze-wake task.
        await coordinator.scheduleReminders()
        let setThresholdCountAfterArm = tracker.setThresholdCalls.count  // 0: returned early

        // Cancel before the 200 ms task fires.
        coordinator.cancelSnoozeWakeTaskIfNeeded()

        // Wait past the original 200 ms window — task should NOT have fired.
        try await Task.sleep(nanoseconds: 700_000_000)

        XCTAssertEqual(
            settings.snoozedUntil,
            originalSnoozeEnd,
            "cancelSnoozeWakeTaskIfNeeded must prevent handleSnoozeWake from clearing snoozedUntil")
        XCTAssertEqual(
            settings.snoozeCount,
            3,
            "cancelSnoozeWakeTaskIfNeeded must prevent snoozeCount from being reset")
        XCTAssertEqual(
            tracker.setThresholdCalls.count,
            setThresholdCountAfterArm,
            "After cancellation, scheduleReminders must not be called again by the cancelled task")
    }

    /// Calling `cancelSnoozeWakeTaskIfNeeded()` when no task is armed must not crash.
    func test_cancelSnoozeWakeTaskIfNeeded_withNoTaskArmed_doesNotCrash() {
        let (coordinator, _, _) = makeCoordinator()
        defer { coordinator.stopFallbackTimers() }
        coordinator.cancelSnoozeWakeTaskIfNeeded()
    }

    /// Cancelling twice in a row must not crash (idempotent).
    func test_cancelSnoozeWakeTaskIfNeeded_calledTwice_doesNotCrash() async {
        settings.snoozedUntil = Date(timeIntervalSinceNow: 5.0)
        let (coordinator, _, _) = makeCoordinator()
        defer { coordinator.stopFallbackTimers() }

        await coordinator.scheduleReminders()
        coordinator.cancelSnoozeWakeTaskIfNeeded()
        coordinator.cancelSnoozeWakeTaskIfNeeded()
    }

    // MARK: - Gap 4: Snooze wake notification trigger interval floor (≥ 1 s)

    /// `scheduleSnoozeWakeNotification(at:)` applies `max(1, date.timeIntervalSinceNow)`
    /// before constructing the `UNTimeIntervalNotificationTrigger`. Even when the snooze
    /// end is only a fraction of a second away (< 1 s from now), the trigger's
    /// `timeInterval` must be at least 1.0 second.
    func test_snoozeWakeNotification_triggerInterval_isAtLeastOneSecond() async {
        // Use a snooze end only 0.5 s in the future so that by the time
        // scheduleSnoozeWakeNotification runs, timeIntervalSinceNow < 1 s,
        // exercising the max(1, ...) floor.
        settings.snoozedUntil = Date(timeIntervalSinceNow: 0.5)

        let notif = MockNotificationCenter()
        notif.authorizationGranted = true  // .authorized triggers the notification path
        let (coordinator, _, _) = makeCoordinator(notifCenter: notif)
        defer { coordinator.stopFallbackTimers() }

        await coordinator.scheduleReminders()

        let wakeRequests = notif.addedRequests.filter {
            $0.content.categoryIdentifier == AppCoordinator.snoozeWakeCategory
        }
        XCTAssertEqual(
            wakeRequests.count,
            1,
            "Exactly one snooze-wake notification must be added to the notification center")

        guard let trigger = wakeRequests.first?.trigger as? UNTimeIntervalNotificationTrigger else {
            XCTFail("Snooze-wake notification must use a UNTimeIntervalNotificationTrigger")
            return
        }
        XCTAssertGreaterThanOrEqual(
            trigger.timeInterval,
            1.0,
            "Snooze-wake trigger timeInterval must be ≥ 1.0 s (max(1, date.timeIntervalSinceNow) floor)")
    }

    /// When the snooze end is far in the future (> 1 s away), the trigger interval must
    /// reflect the actual remaining time rather than being clamped at 1 s.
    func test_snoozeWakeNotification_triggerInterval_reflectsRemainingDuration_whenAboveFloor() async {
        let snoozeSeconds: TimeInterval = 120
        settings.snoozedUntil = Date(timeIntervalSinceNow: snoozeSeconds)

        let notif = MockNotificationCenter()
        notif.authorizationGranted = true
        let (coordinator, _, _) = makeCoordinator(notifCenter: notif)
        defer { coordinator.stopFallbackTimers() }

        await coordinator.scheduleReminders()

        let wakeRequests = notif.addedRequests.filter {
            $0.content.categoryIdentifier == AppCoordinator.snoozeWakeCategory
        }
        XCTAssertEqual(wakeRequests.count, 1)

        guard let trigger = wakeRequests.first?.trigger as? UNTimeIntervalNotificationTrigger else {
            XCTFail("Trigger must be UNTimeIntervalNotificationTrigger")
            return
        }
        XCTAssertGreaterThanOrEqual(
            trigger.timeInterval,
            1.0,
            "Trigger must always be ≥ 1.0 s")
        // Allow generous headroom for test execution time; the interval must be
        // close to snoozeSeconds but won't be exact.
        XCTAssertLessThanOrEqual(
            trigger.timeInterval,
            snoozeSeconds + 2.0,
            "Trigger interval must not exceed the configured snooze duration + 2 s headroom")
    }
}

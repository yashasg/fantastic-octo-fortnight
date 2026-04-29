@testable import EyePostureReminder
import XCTest

/// Unit tests for `AppCoordinator`.
///
/// Coverage is intentionally limited to logic that executes cleanly without a
/// live `UIWindowScene`. UIKit-dependent paths (`handleNotification` foreground
/// path, `startFallbackTimers`, `scheduleReminders`) are exercised in the
/// simulator integration suite, not here.
///
/// Two test configurations are used:
/// 1. `sut` — default init with real `UNUserNotificationCenter` and a fresh `OverlayManager`
///    (safe for crash-proof and public-API path tests).
/// 2. Helper factory `makeCoordinator(overlay:notifCenter:)` — fully injected with
///    `MockOverlayPresenting` + `MockNotificationCenter` for behavioral assertions.
@MainActor
// swiftlint:disable:next type_body_length
final class AppCoordinatorTests: XCTestCase {

    var mockPersistence: MockSettingsPersisting!
    var settings: SettingsStore!
    var sut: AppCoordinator!

    override func setUp() async throws {
        try await super.setUp()
        mockPersistence = MockSettingsPersisting()
        settings = SettingsStore(store: mockPersistence)
        // Inject MockNotificationCenter everywhere to avoid UNUserNotificationCenter.current()
        // which crashes in the headless test runner (no app bundle).
        // Inject MockScreenTimeTracker and MockPauseConditionProvider to avoid real timers/detectors.
        let mockNotif = MockNotificationCenter()
        sut = AppCoordinator(
            settings: settings,
            scheduler: ReminderScheduler(notificationCenter: mockNotif),
            notificationCenter: mockNotif,
            screenTimeTracker: MockScreenTimeTracker(),
            pauseConditionProvider: MockPauseConditionProvider()
        )
    }

    override func tearDown() async throws {
        sut.stopFallbackTimers()
        sut = nil
        settings = nil
        mockPersistence = nil
        try await super.tearDown()
    }

    // MARK: - Factory

    /// Creates a fully-injected `AppCoordinator` for behavioral tests.
    private func makeCoordinator(
        overlay: MockOverlayPresenting,
        notifCenter: MockNotificationCenter,
        screenTimeTracker screenTimeTrackerArg: MockScreenTimeTracker? = nil,
        pauseConditionProvider pauseProviderArg: MockPauseConditionProvider? = nil
    ) -> (AppCoordinator, MockOverlayPresenting, MockNotificationCenter) {
        let tracker = screenTimeTrackerArg ?? MockScreenTimeTracker()
        let pause = pauseProviderArg ?? MockPauseConditionProvider()
        let coordinator = AppCoordinator(
            settings: settings,
            scheduler: ReminderScheduler(notificationCenter: notifCenter),
            notificationCenter: notifCenter,
            overlayManager: overlay,
            screenTimeTracker: tracker,
            pauseConditionProvider: pause
        )
        return (coordinator, overlay, notifCenter)
    }

    // MARK: - Initialisation

    func test_init_settingsPropertyIsNotNil() {
        XCTAssertNotNil(sut.settings)
    }

    func test_init_schedulerPropertyIsNotNil() {
        XCTAssertNotNil(sut.scheduler)
    }

    func test_init_notificationAuthStatus_defaultsToNotDetermined() {
        XCTAssertEqual(sut.notificationAuthStatus, .notDetermined)
    }

    func test_init_withInjectedSettings_exposesTheSameInstance() {
        XCTAssertTrue(sut.settings === settings)
    }

    func test_init_withMockDependencies_doesNotCrash() {
        let mockNotif = MockNotificationCenter()
        let coordinator = AppCoordinator(
            settings: SettingsStore(store: MockSettingsPersisting()),
            scheduler: ReminderScheduler(notificationCenter: mockNotif),
            notificationCenter: mockNotif,
            screenTimeTracker: MockScreenTimeTracker(),
            pauseConditionProvider: MockPauseConditionProvider()
        )
        XCTAssertNotNil(coordinator)
        coordinator.stopFallbackTimers()
    }

    // MARK: - stopFallbackTimers

    func test_stopFallbackTimers_withNoTimersRunning_doesNotCrash() {
        sut.stopFallbackTimers()
    }

    func test_stopFallbackTimers_calledTwice_doesNotCrash() {
        sut.stopFallbackTimers()
        sut.stopFallbackTimers()
    }

    // MARK: - presentPendingOverlayIfNeeded

    func test_presentPendingOverlayIfNeeded_withNoPendingOverlay_doesNotCrash() {
        sut.presentPendingOverlayIfNeeded()
    }

    // MARK: - handleForegroundTransition

    func test_handleForegroundTransition_whenNoTimersAndDenied_doesNotCrash() async {
        // System will report .notDetermined in headless tests — no crash expected.
        await sut.handleForegroundTransition()
    }

    // MARK: - appWillResignActive

    func test_appWillResignActive_withNoTimers_doesNotCrash() {
        sut.appWillResignActive()
    }

    func test_appWillResignActive_calledTwice_doesNotCrash() {
        sut.appWillResignActive()
        sut.appWillResignActive()
    }

    // MARK: - ReminderScheduling conformance (crash-safety)

    func test_cancelAllReminders_doesNotCrash() {
        sut.cancelAllReminders()
    }

    func test_cancelReminder_forEyes_doesNotCrash() {
        sut.cancelReminder(for: .eyes)
    }

    func test_cancelReminder_forPosture_doesNotCrash() {
        sut.cancelReminder(for: .posture)
    }

    // MARK: - cancelAllReminders + MockOverlayPresenting

    func test_cancelAllReminders_callsClearQueueOnOverlayManager() {
        let (coordinator, mockOverlay, _) = makeCoordinator(
            overlay: MockOverlayPresenting(),
            notifCenter: MockNotificationCenter())
        defer { coordinator.stopFallbackTimers() }

        coordinator.cancelAllReminders()

        XCTAssertEqual(
            mockOverlay.clearQueueCallCount,
            1,
            "cancelAllReminders must clear the overlay queue exactly once")
    }

    func test_cancelAllReminders_calledTwice_clearQueueCalledTwice() {
        let (coordinator, mockOverlay, _) = makeCoordinator(
            overlay: MockOverlayPresenting(),
            notifCenter: MockNotificationCenter())
        defer { coordinator.stopFallbackTimers() }

        coordinator.cancelAllReminders()
        coordinator.cancelAllReminders()

        XCTAssertEqual(mockOverlay.clearQueueCallCount, 2)
    }

    // MARK: - handleNotification + presentPendingOverlayIfNeeded

    /// In a headless test there is no active `UIWindowScene`. `handleNotification`
    /// stores the overlay as a pending request. `presentPendingOverlayIfNeeded`
    /// then calls `overlayManager.showOverlay` — simulating what happens when the
    /// scene becomes active after a notification tap.
    func test_handleNotification_eyes_thenPresentPending_callsShowOverlayWithEyes() {
        let (coordinator, mockOverlay, _) = makeCoordinator(
            overlay: MockOverlayPresenting(),
            notifCenter: MockNotificationCenter())
        defer { coordinator.stopFallbackTimers() }

        coordinator.handleNotification(for: .eyes)
        coordinator.presentPendingOverlayIfNeeded()

        XCTAssertEqual(mockOverlay.showCallCount, 1)
        XCTAssertEqual(mockOverlay.showCallOrder.first, .eyes)
    }

    func test_handleNotification_posture_thenPresentPending_callsShowOverlayWithPosture() {
        let (coordinator, mockOverlay, _) = makeCoordinator(
            overlay: MockOverlayPresenting(),
            notifCenter: MockNotificationCenter())
        defer { coordinator.stopFallbackTimers() }

        coordinator.handleNotification(for: .posture)
        coordinator.presentPendingOverlayIfNeeded()

        XCTAssertEqual(mockOverlay.showCallCount, 1)
        XCTAssertEqual(mockOverlay.showCallOrder.first, .posture)
    }

    func test_handleNotification_thenPresentPending_usesDurationFromSettings() {
        settings.eyesBreakDuration = 30
        let (coordinator, mockOverlay, _) = makeCoordinator(
            overlay: MockOverlayPresenting(),
            notifCenter: MockNotificationCenter())
        defer { coordinator.stopFallbackTimers() }

        coordinator.handleNotification(for: .eyes)
        coordinator.presentPendingOverlayIfNeeded()

        XCTAssertEqual(
            mockOverlay.showCallDurations.first,
            30,
            "showOverlay must use the breakDuration from SettingsStore")
    }

    func test_handleNotification_thenPresentPending_passesHapticsEnabledFromSettings() {
        settings.hapticsEnabled = false
        let (coordinator, mockOverlay, _) = makeCoordinator(
            overlay: MockOverlayPresenting(),
            notifCenter: MockNotificationCenter())
        defer { coordinator.stopFallbackTimers() }

        coordinator.handleNotification(for: .eyes)
        coordinator.presentPendingOverlayIfNeeded()

        XCTAssertEqual(
            mockOverlay.showCallHapticsEnabled.first,
            false,
            "showOverlay must forward hapticsEnabled from SettingsStore")
    }

    func test_handleNotification_thenPresentPending_hapticsTrue_whenHapticsEnabled() {
        settings.hapticsEnabled = true
        let (coordinator, mockOverlay, _) = makeCoordinator(
            overlay: MockOverlayPresenting(),
            notifCenter: MockNotificationCenter())
        defer { coordinator.stopFallbackTimers() }

        coordinator.handleNotification(for: .posture)
        coordinator.presentPendingOverlayIfNeeded()

        XCTAssertEqual(mockOverlay.showCallHapticsEnabled.first, true)
    }

    func test_presentPendingOverlayIfNeeded_withNoPending_doesNotCallShowOverlay() {
        let (coordinator, mockOverlay, _) = makeCoordinator(
            overlay: MockOverlayPresenting(),
            notifCenter: MockNotificationCenter())
        defer { coordinator.stopFallbackTimers() }

        coordinator.presentPendingOverlayIfNeeded()

        XCTAssertEqual(mockOverlay.showCallCount, 0)
    }

    func test_presentPendingOverlayIfNeeded_calledTwice_showsOnlyOnce() {
        let (coordinator, mockOverlay, _) = makeCoordinator(
            overlay: MockOverlayPresenting(),
            notifCenter: MockNotificationCenter())
        defer { coordinator.stopFallbackTimers() }

        coordinator.handleNotification(for: .eyes)
        coordinator.presentPendingOverlayIfNeeded()
        coordinator.presentPendingOverlayIfNeeded() // second call: no pending

        XCTAssertEqual(
            mockOverlay.showCallCount,
            1,
            "Second presentPendingOverlayIfNeeded with no pending must not show twice")
    }

    // MARK: - handleNotification resets snoozeCount

    func test_handleNotification_resetsSnoozeCount_toZero() {
        settings.snoozeCount = 2
        let (coordinator, _, _) = makeCoordinator(
            overlay: MockOverlayPresenting(),
            notifCenter: MockNotificationCenter())
        defer { coordinator.stopFallbackTimers() }

        coordinator.handleNotification(for: .posture)

        XCTAssertEqual(
            settings.snoozeCount,
            0,
            "handleNotification must reset snoozeCount=0 when a real reminder fires")
    }

    func test_handleNotification_resetsSnoozeCount_regardlessOfType() {
        settings.snoozeCount = 1
        let (coordinator, _, _) = makeCoordinator(
            overlay: MockOverlayPresenting(),
            notifCenter: MockNotificationCenter())
        defer { coordinator.stopFallbackTimers() }

        coordinator.handleNotification(for: .eyes)

        XCTAssertEqual(settings.snoozeCount, 0)
    }

    // MARK: - cancelAllReminders with active snooze

    func test_cancelAllReminders_withActiveSnooze_clearQueueStillCalled() {
        settings.snoozedUntil = Date().addingTimeInterval(300)
        let (coordinator, mockOverlay, _) = makeCoordinator(
            overlay: MockOverlayPresenting(),
            notifCenter: MockNotificationCenter())
        defer { coordinator.stopFallbackTimers() }

        coordinator.cancelAllReminders()

        XCTAssertEqual(
            mockOverlay.clearQueueCallCount,
            1,
            "clearQueue must always be called regardless of snooze state")
    }

    // MARK: - OverlayManager queue FIFO ordering

    /// Full FIFO ordering of the `OverlayManager.overlayQueue` requires a live
    /// `UIWindowScene` to set `isOverlayVisible = true` and trigger dequeue.
    /// This path is covered in the simulator integration test suite.
    ///
    /// At the AppCoordinator level we verify that when an overlay is requested
    /// while one is already showing (via `MockOverlayPresenting.isOverlayVisible`),
    /// the coordinator correctly delegates to the overlay manager which would
    /// internally queue the request.
    func test_overlayManager_showOverlay_receivesCorrectType_forEachRequest() {
        let (coordinator, mockOverlay, _) = makeCoordinator(
            overlay: MockOverlayPresenting(),
            notifCenter: MockNotificationCenter())
        defer { coordinator.stopFallbackTimers() }

        // First request: store as pending (no active scene in headless test).
        coordinator.handleNotification(for: .eyes)
        coordinator.presentPendingOverlayIfNeeded()   // → mock records .eyes

        // Second request: pending slot overwritten by new notification.
        coordinator.handleNotification(for: .posture)
        coordinator.presentPendingOverlayIfNeeded()   // → mock records .posture

        XCTAssertEqual(mockOverlay.showCallCount, 2)
        XCTAssertEqual(mockOverlay.showCallOrder, [.eyes, .posture])
    }

    // MARK: - Issue #13: PauseConditionProviding DI

    func test_init_withMockPauseConditionProvider_startMonitoringCalled() {
        let mockNotif = MockNotificationCenter()
        let mockPause = MockPauseConditionProvider()
        let coordinator = AppCoordinator(
            settings: settings,
            scheduler: ReminderScheduler(notificationCenter: mockNotif),
            notificationCenter: mockNotif,
            screenTimeTracker: MockScreenTimeTracker(),
            pauseConditionProvider: mockPause
        )
        defer { coordinator.stopFallbackTimers() }
        XCTAssertEqual(
            mockPause.startMonitoringCallCount,
            1,
            "AppCoordinator.init must call startMonitoring() on the injected PauseConditionProviding")
    }

    // MARK: - Issue #14: ScreenTimeTracking DI

    func test_stopFallbackTimers_callsStopMonitoringOnInjectedScreenTimeTracker() {
        let mockNotif = MockNotificationCenter()
        let mockTracker = MockScreenTimeTracker()
        let coordinator = AppCoordinator(
            settings: settings,
            scheduler: ReminderScheduler(notificationCenter: mockNotif),
            notificationCenter: mockNotif,
            screenTimeTracker: mockTracker,
            pauseConditionProvider: MockPauseConditionProvider()
        )
        coordinator.stopFallbackTimers()
        XCTAssertEqual(
            mockTracker.stopMonitoringCallCount,
            1,
            "stopFallbackTimers must call stopMonitoring() on the injected ScreenTimeTracking")
    }

    // MARK: - Issue #29: clearExpiredSnoozeIfNeeded + silent snooze-wake notification

    func test_clearExpiredSnoozeIfNeeded_clearsSnoozeWhenExpired() async {
        // Arrange: snooze ended in the past.
        settings.snoozedUntil = Date(timeIntervalSinceNow: -60)
        settings.snoozeCount  = 2

        // Act
        await sut.clearExpiredSnoozeIfNeeded()

        // Assert: stale snooze cleared.
        XCTAssertNil(
            settings.snoozedUntil,
            "clearExpiredSnoozeIfNeeded must nil out a past snoozedUntil")
        XCTAssertEqual(
            settings.snoozeCount,
            0,
            "clearExpiredSnoozeIfNeeded must reset snoozeCount to 0")
    }

    func test_clearExpiredSnoozeIfNeeded_preservesSnoozeWhenStillActive() async {
        // Arrange: snooze ends in the future.
        let futureDate = Date(timeIntervalSinceNow: 300)
        settings.snoozedUntil = futureDate
        settings.snoozeCount  = 1

        // Act
        await sut.clearExpiredSnoozeIfNeeded()

        // Assert: active snooze must NOT be touched.
        XCTAssertEqual(
            settings.snoozedUntil,
            futureDate,
            "clearExpiredSnoozeIfNeeded must not clear a future snoozedUntil")
        XCTAssertEqual(
            settings.snoozeCount,
            1,
            "clearExpiredSnoozeIfNeeded must not reset snoozeCount for an active snooze")
    }

    func test_clearExpiredSnoozeIfNeeded_noOp_whenSnoozedUntilIsNil() async {
        // Arrange: no active snooze.
        settings.snoozedUntil = nil

        // Act – must not crash or mutate anything.
        await sut.clearExpiredSnoozeIfNeeded()

        XCTAssertNil(settings.snoozedUntil)
    }

    func test_scheduleReminders_snoozeWakeNotification_isSilent() async {
        // Arrange: inject auth-authorized mock so the silent notification is actually scheduled.
        let mockNotif = MockNotificationCenter()
        mockNotif.authorizationGranted = true
        let (coordinator, _, _) = makeCoordinator(
            overlay: MockOverlayPresenting(),
            notifCenter: mockNotif)
        defer { coordinator.stopFallbackTimers() }

        // Force the coordinator to believe it is authorized.
        settings.snoozedUntil = Date(timeIntervalSinceNow: 300)

        // scheduleReminders reads notificationAuthStatus which is refreshed via
        // getAuthorizationStatus(). The mock returns .authorized when authorizationGranted == true.
        await coordinator.scheduleReminders()

        // Assert: exactly one snooze-wake notification was added.
        let wakeRequests = mockNotif.addedRequests.filter {
            $0.content.categoryIdentifier == AppCoordinator.snoozeWakeCategory
        }
        XCTAssertEqual(
            wakeRequests.count,
            1,
            "Exactly one snooze-wake notification should be scheduled")

        let content = wakeRequests[0].content
        XCTAssertEqual(
            content.title,
            "",
            "Snooze-wake notification title must be empty (silent)")
        XCTAssertEqual(
            content.body,
            "",
            "Snooze-wake notification body must be empty (silent)")
        XCTAssertNil(
            content.sound,
            "Snooze-wake notification must have no sound (silent)")
    }

    // MARK: - Background Scheduling Regression (P0)
    //
    // P0: background reminders were disabled — the app only reminded users while foregrounded
    // because `AppCoordinator.scheduleReminders()` called `scheduler.cancelAllReminders()`
    // instead of scheduling periodic UNNotification requests.
    //
    // These tests verify that `scheduleReminders()` with notification auth = .authorized
    // produces periodic UNNotificationRequest objects in the notification center for each
    // enabled reminder type. They fail until the scheduling path is restored in
    // `AppCoordinator.scheduleReminders()`.
    //
    // Non-reminder requests (snooze-wake, categoryIdentifier == snoozeWakeCategory) are
    // filtered out so these tests stay focused on the periodic-reminder contract.

    private func reminderRequests(from notifCenter: MockNotificationCenter) -> [UNNotificationRequest] {
        notifCenter.addedRequests.filter {
            $0.content.categoryIdentifier != AppCoordinator.snoozeWakeCategory
        }
    }

    func test_scheduleReminders_authorized_bothEnabled_addsEyesAndPostureRequests() async {
        let mockNotif = MockNotificationCenter()
        mockNotif.authorizationGranted = true
        settings.globalEnabled = true
        settings.eyesEnabled = true
        settings.postureEnabled = true
        let (coordinator, _, _) = makeCoordinator(
            overlay: MockOverlayPresenting(),
            notifCenter: mockNotif)
        defer { coordinator.stopFallbackTimers() }

        await coordinator.scheduleReminders()

        let periodic = reminderRequests(from: mockNotif)
        XCTAssertEqual(
            periodic.count,
            2,
            "scheduleReminders() with auth=authorized and both types enabled must add 2 periodic reminder requests")
    }

    func test_scheduleReminders_authorized_eyesOnly_addsExactlyOneEyesRequest() async {
        let mockNotif = MockNotificationCenter()
        mockNotif.authorizationGranted = true
        settings.globalEnabled = true
        settings.eyesEnabled = true
        settings.postureEnabled = false
        let (coordinator, _, _) = makeCoordinator(
            overlay: MockOverlayPresenting(),
            notifCenter: mockNotif)
        defer { coordinator.stopFallbackTimers() }

        await coordinator.scheduleReminders()

        let periodic = reminderRequests(from: mockNotif)
        XCTAssertEqual(periodic.count, 1)
        XCTAssertEqual(
            periodic.first?.content.categoryIdentifier,
            ReminderType.eyes.categoryIdentifier,
            "With only eyes enabled, the single periodic request must be for eye-break reminders")
    }

    func test_scheduleReminders_authorized_postureOnly_addsExactlyOnePostureRequest() async {
        let mockNotif = MockNotificationCenter()
        mockNotif.authorizationGranted = true
        settings.globalEnabled = true
        settings.eyesEnabled = false
        settings.postureEnabled = true
        let (coordinator, _, _) = makeCoordinator(
            overlay: MockOverlayPresenting(),
            notifCenter: mockNotif)
        defer { coordinator.stopFallbackTimers() }

        await coordinator.scheduleReminders()

        let periodic = reminderRequests(from: mockNotif)
        XCTAssertEqual(periodic.count, 1)
        XCTAssertEqual(
            periodic.first?.content.categoryIdentifier,
            ReminderType.posture.categoryIdentifier,
            "With only posture enabled, the single periodic request must be for posture-check reminders")
    }

    func test_scheduleReminders_authorized_noEnabledTypes_addsNoReminderRequests() async {
        let mockNotif = MockNotificationCenter()
        mockNotif.authorizationGranted = true
        settings.globalEnabled = true
        settings.eyesEnabled = false
        settings.postureEnabled = false
        let (coordinator, _, _) = makeCoordinator(
            overlay: MockOverlayPresenting(),
            notifCenter: mockNotif)
        defer { coordinator.stopFallbackTimers() }

        await coordinator.scheduleReminders()

        let periodic = reminderRequests(from: mockNotif)
        XCTAssertTrue(
            periodic.isEmpty,
            "scheduleReminders() with no reminder types enabled must not add any periodic requests")
    }

    func test_scheduleReminders_authorized_globalDisabled_addsNoReminderRequests() async {
        let mockNotif = MockNotificationCenter()
        mockNotif.authorizationGranted = true
        settings.globalEnabled = false
        settings.eyesEnabled = true
        settings.postureEnabled = true
        let (coordinator, _, _) = makeCoordinator(
            overlay: MockOverlayPresenting(),
            notifCenter: mockNotif)
        defer { coordinator.stopFallbackTimers() }

        await coordinator.scheduleReminders()

        let periodic = reminderRequests(from: mockNotif)
        XCTAssertTrue(
            periodic.isEmpty,
            "scheduleReminders() with master toggle off must not schedule any reminder requests")
    }

    func test_scheduleReminders_periodicRequests_useTimeIntervalTrigger() async {
        let mockNotif = MockNotificationCenter()
        mockNotif.authorizationGranted = true
        settings.globalEnabled = true
        settings.eyesEnabled = true
        settings.postureEnabled = true
        let (coordinator, _, _) = makeCoordinator(
            overlay: MockOverlayPresenting(),
            notifCenter: mockNotif)
        defer { coordinator.stopFallbackTimers() }

        await coordinator.scheduleReminders()

        for request in reminderRequests(from: mockNotif) {
            XCTAssertNotNil(
                request.trigger as? UNTimeIntervalNotificationTrigger,
                "Periodic reminder '\(request.identifier)' must use a time interval trigger.")
        }
    }

    func test_scheduleReminders_periodicRequests_repeatsIsTrue() async {
        let mockNotif = MockNotificationCenter()
        mockNotif.authorizationGranted = true
        settings.globalEnabled = true
        settings.eyesEnabled = true
        settings.postureEnabled = true
        settings.eyesInterval = 1200
        settings.postureInterval = 1800
        let (coordinator, _, _) = makeCoordinator(
            overlay: MockOverlayPresenting(),
            notifCenter: mockNotif)
        defer { coordinator.stopFallbackTimers() }

        await coordinator.scheduleReminders()

        for request in reminderRequests(from: mockNotif) {
            let trigger = request.trigger as? UNTimeIntervalNotificationTrigger
            XCTAssertEqual(
                trigger?.repeats,
                true,
                "Periodic reminder '\(request.identifier)' must have repeats=true so it fires in the background")
        }
    }

    func test_scheduleReminders_denied_addsNoReminderRequests() async {
        let mockNotif = MockNotificationCenter()
        mockNotif.authorizationGranted = false
        settings.globalEnabled = true
        settings.eyesEnabled = true
        settings.postureEnabled = true
        let (coordinator, _, _) = makeCoordinator(
            overlay: MockOverlayPresenting(),
            notifCenter: mockNotif)
        defer { coordinator.stopFallbackTimers() }

        await coordinator.scheduleReminders()

        let periodic = reminderRequests(from: mockNotif)
        XCTAssertTrue(
            periodic.isEmpty,
            "scheduleReminders() with auth=denied must not schedule any reminder notifications")
    }

    // MARK: - handleNotification: ScreenTimeTracker reset

    func test_handleNotification_eyes_resetsEyesCounter() {
        let mockNotif = MockNotificationCenter()
        let mockTracker = MockScreenTimeTracker()
        let (coordinator, _, _) = makeCoordinator(
            overlay: MockOverlayPresenting(),
            notifCenter: mockNotif,
            screenTimeTracker: mockTracker)
        defer { coordinator.stopFallbackTimers() }

        coordinator.handleNotification(for: .eyes)

        XCTAssertTrue(
            mockTracker.resetCalls.contains(.eyes),
            "handleNotification must reset the ScreenTimeTracker counter for the delivered type")
    }

    func test_handleNotification_posture_resetsPostureCounter() {
        let mockNotif = MockNotificationCenter()
        let mockTracker = MockScreenTimeTracker()
        let (coordinator, _, _) = makeCoordinator(
            overlay: MockOverlayPresenting(),
            notifCenter: mockNotif,
            screenTimeTracker: mockTracker)
        defer { coordinator.stopFallbackTimers() }

        coordinator.handleNotification(for: .posture)

        XCTAssertTrue(
            mockTracker.resetCalls.contains(.posture),
            "handleNotification must reset the ScreenTimeTracker counter for the delivered type")
    }

    func test_handleNotification_eyes_doesNotResetPostureCounter() {
        let mockNotif = MockNotificationCenter()
        let mockTracker = MockScreenTimeTracker()
        let (coordinator, _, _) = makeCoordinator(
            overlay: MockOverlayPresenting(),
            notifCenter: mockNotif,
            screenTimeTracker: mockTracker)
        defer { coordinator.stopFallbackTimers() }

        coordinator.handleNotification(for: .eyes)

        XCTAssertFalse(
            mockTracker.resetCalls.contains(.posture),
            "handleNotification for eyes must not reset the posture counter")
    }

    // MARK: - Foreground threshold: reschedules background notification

    func test_thresholdReached_whenAuthorized_reschedulesNotificationForType() async {
        let mockNotif = MockNotificationCenter()
        mockNotif.authorizationGranted = true
        settings.globalEnabled = true
        settings.eyesEnabled = true
        settings.postureEnabled = false
        settings.eyesInterval = 1200
        let mockTracker = MockScreenTimeTracker()
        let (coordinator, _, _) = makeCoordinator(
            overlay: MockOverlayPresenting(),
            notifCenter: mockNotif,
            screenTimeTracker: mockTracker)
        defer { coordinator.stopFallbackTimers() }

        await coordinator.scheduleReminders()
        let countAfterSchedule = reminderRequests(from: mockNotif).count

        // Fire the foreground threshold callback.
        mockTracker.simulateThresholdReached(for: .eyes)

        // Allow the internally-spawned Task to complete.
        try? await Task.sleep(nanoseconds: 50_000_000)

        let eyesCount = reminderRequests(from: mockNotif).filter {
            $0.content.categoryIdentifier == ReminderType.eyes.categoryIdentifier
        }.count
        XCTAssertGreaterThan(
            eyesCount,
            countAfterSchedule,
            "Foreground threshold fire must reschedule the background notification to reset its interval from now")
    }
}

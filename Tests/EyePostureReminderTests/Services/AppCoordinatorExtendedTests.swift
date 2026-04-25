@testable import EyePostureReminder
import XCTest

/// Extended unit tests for `AppCoordinator` focusing on the three highest-impact
/// coverage gaps: the `ScreenTimeTracker` threshold callback path, the
/// `PauseConditionManager` callback path, and the `scheduleReminders` flow.
///
/// Uses the same mock infrastructure as `AppCoordinatorTests`: injected
/// `MockScreenTimeTracker`, `MockPauseConditionProvider`, `MockOverlayPresenting`,
/// and `MockNotificationCenter`.
@MainActor
// swiftlint:disable:next type_body_length
final class AppCoordinatorExtendedTests: XCTestCase {

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
    //
    // Default parameter expressions for @MainActor types are not allowed in
    // nonisolated contexts, so we use nil defaults and construct inside the body.

    private func makeCoordinator(
        overlay overlayArg: MockOverlayPresenting? = nil,
        notifCenter: MockNotificationCenter = MockNotificationCenter(),
        screenTimeTracker: MockScreenTimeTracker = MockScreenTimeTracker(),
        pauseConditionProvider pauseArg: PauseConditionProviding? = nil
    ) -> (
        coordinator: AppCoordinator,
        overlay: MockOverlayPresenting,
        tracker: MockScreenTimeTracker,
        notif: MockNotificationCenter
    ) {
        let overlay = overlayArg ?? MockOverlayPresenting()
        let pause = pauseArg ?? MockPauseConditionProvider()
        let coordinator = AppCoordinator(
            settings: settings,
            scheduler: ReminderScheduler(notificationCenter: notifCenter),
            notificationCenter: notifCenter,
            overlayManager: overlay,
            screenTimeTracker: screenTimeTracker,
            pauseConditionProvider: pause
        )
        return (coordinator, overlay, screenTimeTracker, notifCenter)
    }

    // MARK: - ScreenTimeTracker Threshold Callback → Overlay

    func test_thresholdCallback_eyes_triggersShowOverlay() {
        let mockTracker = MockScreenTimeTracker()
        let mockOverlay = MockOverlayPresenting()
        let (coordinator, _, _, _) = makeCoordinator(overlay: mockOverlay, screenTimeTracker: mockTracker)
        defer { coordinator.stopFallbackTimers() }

        mockTracker.simulateThresholdReached(for: .eyes)

        XCTAssertEqual(
            mockOverlay.showCallCount,
            1,
            "A screen-time threshold for .eyes must trigger showOverlay exactly once")
        XCTAssertEqual(
            mockOverlay.showCallOrder.first,
            .eyes,
            "showOverlay must be called with .eyes when the eyes threshold is reached")
    }

    func test_thresholdCallback_posture_triggersShowOverlay() {
        let mockTracker = MockScreenTimeTracker()
        let mockOverlay = MockOverlayPresenting()
        let (coordinator, _, _, _) = makeCoordinator(overlay: mockOverlay, screenTimeTracker: mockTracker)
        defer { coordinator.stopFallbackTimers() }

        mockTracker.simulateThresholdReached(for: .posture)

        XCTAssertEqual(mockOverlay.showCallCount, 1)
        XCTAssertEqual(mockOverlay.showCallOrder.first, .posture)
    }

    func test_thresholdCallback_usesBreakDurationFromSettings() {
        settings.eyesBreakDuration = 45
        let mockTracker = MockScreenTimeTracker()
        let mockOverlay = MockOverlayPresenting()
        let (coordinator, _, _, _) = makeCoordinator(overlay: mockOverlay, screenTimeTracker: mockTracker)
        defer { coordinator.stopFallbackTimers() }

        mockTracker.simulateThresholdReached(for: .eyes)

        XCTAssertEqual(
            mockOverlay.showCallDurations.first,
            45,
            "showOverlay must use breakDuration from SettingsStore")
    }

    func test_thresholdCallback_passesHapticsEnabledTrue() {
        settings.hapticsEnabled = true
        let mockTracker = MockScreenTimeTracker()
        let mockOverlay = MockOverlayPresenting()
        let (coordinator, _, _, _) = makeCoordinator(overlay: mockOverlay, screenTimeTracker: mockTracker)
        defer { coordinator.stopFallbackTimers() }

        mockTracker.simulateThresholdReached(for: .eyes)

        XCTAssertEqual(mockOverlay.showCallHapticsEnabled.first, true)
    }

    func test_thresholdCallback_passesHapticsEnabledFalse() {
        settings.hapticsEnabled = false
        let mockTracker = MockScreenTimeTracker()
        let mockOverlay = MockOverlayPresenting()
        let (coordinator, _, _, _) = makeCoordinator(overlay: mockOverlay, screenTimeTracker: mockTracker)
        defer { coordinator.stopFallbackTimers() }

        mockTracker.simulateThresholdReached(for: .posture)

        XCTAssertEqual(mockOverlay.showCallHapticsEnabled.first, false)
    }

    // MARK: - ScreenTimeTracker Threshold Callback → snoozeCount Reset

    func test_thresholdCallback_resetsSnoozeCount_toZero() {
        settings.snoozeCount = 3
        let mockTracker = MockScreenTimeTracker()
        let (coordinator, _, _, _) = makeCoordinator(screenTimeTracker: mockTracker)
        defer { coordinator.stopFallbackTimers() }

        mockTracker.simulateThresholdReached(for: .eyes)

        XCTAssertEqual(
            settings.snoozeCount,
            0,
            "Screen-time threshold callback must reset snoozeCount to 0 (new reminder cycle)")
    }

    func test_thresholdCallback_resetsSnoozeCount_regardlessOfType() {
        settings.snoozeCount = 5
        let mockTracker = MockScreenTimeTracker()
        let (coordinator, _, _, _) = makeCoordinator(screenTimeTracker: mockTracker)
        defer { coordinator.stopFallbackTimers() }

        mockTracker.simulateThresholdReached(for: .posture)

        XCTAssertEqual(settings.snoozeCount, 0)
    }

    func test_thresholdCallback_whenSnoozeCountZero_remainsZero() {
        settings.snoozeCount = 0
        let mockTracker = MockScreenTimeTracker()
        let (coordinator, _, _, _) = makeCoordinator(screenTimeTracker: mockTracker)
        defer { coordinator.stopFallbackTimers() }

        mockTracker.simulateThresholdReached(for: .eyes)

        XCTAssertEqual(settings.snoozeCount, 0)
    }

    func test_thresholdCallback_multipleTypes_eachResetsSnoozeCount() {
        settings.snoozeCount = 2
        let mockTracker = MockScreenTimeTracker()
        let (coordinator, _, _, _) = makeCoordinator(screenTimeTracker: mockTracker)
        defer { coordinator.stopFallbackTimers() }

        mockTracker.simulateThresholdReached(for: .eyes)
        XCTAssertEqual(settings.snoozeCount, 0)

        settings.snoozeCount = 4
        mockTracker.simulateThresholdReached(for: .posture)
        XCTAssertEqual(settings.snoozeCount, 0)
    }

    // MARK: - PauseConditionManager Callback → pauseAll

    func test_pauseConditionActivated_callsPauseAll_onTracker() {
        let mockTracker = MockScreenTimeTracker()
        let mockPause = MockPauseConditionProvider()
        let (coordinator, _, _, _) = makeCoordinator(
            screenTimeTracker: mockTracker,
            pauseConditionProvider: mockPause)
        defer { coordinator.stopFallbackTimers() }

        mockPause.simulatePauseStateChange(true)

        XCTAssertEqual(
            mockTracker.pauseAllCallCount,
            1,
            "Pause condition activation must call pauseAll() on ScreenTimeTracker")
    }

    func test_pauseConditionActivated_callsClearQueueOnOverlay() {
        let mockOverlay = MockOverlayPresenting()
        let mockPause = MockPauseConditionProvider()
        let (coordinator, _, _, _) = makeCoordinator(
            overlay: mockOverlay,
            pauseConditionProvider: mockPause)
        defer { coordinator.stopFallbackTimers() }

        mockPause.simulatePauseStateChange(true)

        XCTAssertEqual(
            mockOverlay.clearQueueCallCount,
            1,
            "Pause condition activation must clear the overlay queue")
    }

    func test_pauseConditionActivated_whenOverlayVisible_dismissesOverlay() {
        let mockOverlay = MockOverlayPresenting()
        let mockPause = MockPauseConditionProvider()
        let (coordinator, _, _, _) = makeCoordinator(
            overlay: mockOverlay,
            pauseConditionProvider: mockPause)
        defer { coordinator.stopFallbackTimers() }

        mockOverlay.isOverlayVisible = true
        mockPause.simulatePauseStateChange(true)

        XCTAssertEqual(
            mockOverlay.dismissCallCount,
            1,
            "Pause condition activation must dismiss any currently-visible overlay")
    }

    func test_pauseConditionActivated_whenOverlayNotVisible_doesNotDismiss() {
        let mockOverlay = MockOverlayPresenting()
        let mockPause = MockPauseConditionProvider()
        let (coordinator, _, _, _) = makeCoordinator(
            overlay: mockOverlay,
            pauseConditionProvider: mockPause)
        defer { coordinator.stopFallbackTimers() }

        mockOverlay.isOverlayVisible = false
        mockPause.simulatePauseStateChange(true)

        XCTAssertEqual(
            mockOverlay.dismissCallCount,
            0,
            "Pause condition activation must not call dismissOverlay() when nothing is visible")
    }

    // MARK: - PauseConditionManager Callback → resumeAll

    func test_pauseConditionDeactivated_whenNoSnooze_callsResumeAll() {
        settings.snoozedUntil = nil
        let mockTracker = MockScreenTimeTracker()
        let mockPause = MockPauseConditionProvider()
        let (coordinator, _, _, _) = makeCoordinator(
            screenTimeTracker: mockTracker,
            pauseConditionProvider: mockPause)
        defer { coordinator.stopFallbackTimers() }

        mockPause.simulatePauseStateChange(true)   // pause
        mockPause.simulatePauseStateChange(false)  // unpause

        XCTAssertEqual(
            mockTracker.resumeAllCallCount,
            1,
            "Pause condition clearing with no active snooze must call resumeAll()")
    }

    func test_pauseConditionDeactivated_whenSnoozeStillActive_doesNotCallResumeAll() {
        settings.snoozedUntil = Date(timeIntervalSinceNow: 300)
        let mockTracker = MockScreenTimeTracker()
        let mockPause = MockPauseConditionProvider()
        let (coordinator, _, _, _) = makeCoordinator(
            screenTimeTracker: mockTracker,
            pauseConditionProvider: mockPause)
        defer { coordinator.stopFallbackTimers() }

        mockPause.simulatePauseStateChange(true)   // pause
        mockPause.simulatePauseStateChange(false)  // unpause — but snooze is still active

        XCTAssertEqual(
            mockTracker.resumeAllCallCount,
            0,
            "Pause condition clearing must NOT call resumeAll() while snooze is still active")
    }

    func test_pauseConditionDeactivated_whenSnoozeExpired_callsResumeAll() {
        settings.snoozedUntil = Date(timeIntervalSinceNow: -60) // in the past
        let mockTracker = MockScreenTimeTracker()
        let mockPause = MockPauseConditionProvider()
        let (coordinator, _, _, _) = makeCoordinator(
            screenTimeTracker: mockTracker,
            pauseConditionProvider: mockPause)
        defer { coordinator.stopFallbackTimers() }

        mockPause.simulatePauseStateChange(true)
        mockPause.simulatePauseStateChange(false)

        XCTAssertEqual(
            mockTracker.resumeAllCallCount,
            1,
            "Pause condition clearing with an expired snooze must call resumeAll()")
    }

    func test_multiplePauseActivations_eachCallsPauseAll() {
        let mockTracker = MockScreenTimeTracker()
        let mockPause = MockPauseConditionProvider()
        let (coordinator, _, _, _) = makeCoordinator(
            screenTimeTracker: mockTracker,
            pauseConditionProvider: mockPause)
        defer { coordinator.stopFallbackTimers() }

        mockPause.simulatePauseStateChange(true)
        mockPause.simulatePauseStateChange(false)
        mockPause.simulatePauseStateChange(true)

        XCTAssertEqual(mockTracker.pauseAllCallCount, 2)
    }

    // MARK: - scheduleReminders → configureScreenTimeTracker

    func test_scheduleReminders_whenEyesEnabled_setsThresholdForEyes() async {
        settings.eyesEnabled = true
        let mockTracker = MockScreenTimeTracker()
        let (coordinator, _, _, _) = makeCoordinator(screenTimeTracker: mockTracker)
        defer { coordinator.stopFallbackTimers() }

        await coordinator.scheduleReminders()

        XCTAssertTrue(
            mockTracker.setThresholdCalls.contains { $0.type == .eyes },
            "scheduleReminders must set the threshold for .eyes when it is enabled")
    }

    func test_scheduleReminders_whenPostureEnabled_setsThresholdForPosture() async {
        settings.postureEnabled = true
        let mockTracker = MockScreenTimeTracker()
        let (coordinator, _, _, _) = makeCoordinator(screenTimeTracker: mockTracker)
        defer { coordinator.stopFallbackTimers() }

        await coordinator.scheduleReminders()

        XCTAssertTrue(
            mockTracker.setThresholdCalls.contains { $0.type == .posture },
            "scheduleReminders must set the threshold for .posture when it is enabled")
    }

    func test_scheduleReminders_whenEyesDisabled_disablesTrackingForEyes() async {
        settings.eyesEnabled = false
        let mockTracker = MockScreenTimeTracker()
        let (coordinator, _, _, _) = makeCoordinator(screenTimeTracker: mockTracker)
        defer { coordinator.stopFallbackTimers() }

        await coordinator.scheduleReminders()

        XCTAssertTrue(
            mockTracker.disableTrackingCalls.contains(.eyes),
            "scheduleReminders must disable tracking for .eyes when it is disabled")
    }

    func test_scheduleReminders_whenPostureDisabled_disablesTrackingForPosture() async {
        settings.postureEnabled = false
        let mockTracker = MockScreenTimeTracker()
        let (coordinator, _, _, _) = makeCoordinator(screenTimeTracker: mockTracker)
        defer { coordinator.stopFallbackTimers() }

        await coordinator.scheduleReminders()

        XCTAssertTrue(
            mockTracker.disableTrackingCalls.contains(.posture),
            "scheduleReminders must disable tracking for .posture when it is disabled")
    }

    func test_scheduleReminders_whenSnoozeActive_callsPauseAll() async {
        settings.snoozedUntil = Date(timeIntervalSinceNow: 300)
        let mockTracker = MockScreenTimeTracker()
        let (coordinator, _, _, _) = makeCoordinator(screenTimeTracker: mockTracker)
        defer { coordinator.stopFallbackTimers() }

        await coordinator.scheduleReminders()

        XCTAssertGreaterThanOrEqual(
            mockTracker.pauseAllCallCount,
            1,
            "scheduleReminders with active snooze must call pauseAll() on the tracker")
    }

    func test_scheduleReminders_whenSnoozeExpired_clearsSnoozeState() async {
        settings.snoozedUntil = Date(timeIntervalSinceNow: -60)
        settings.snoozeCount = 2
        let (coordinator, _, _, _) = makeCoordinator()
        defer { coordinator.stopFallbackTimers() }

        await coordinator.scheduleReminders()

        XCTAssertNil(
            settings.snoozedUntil,
            "scheduleReminders must nil out an expired snoozedUntil")
        XCTAssertEqual(
            settings.snoozeCount,
            0,
            "scheduleReminders must reset snoozeCount when snooze has expired")
    }

    func test_scheduleReminders_withPauseConditionActive_skipsResumeAll() async {
        settings.eyesEnabled = true
        let mockTracker = MockScreenTimeTracker()
        let (coordinator, _, _, _) = makeCoordinator(
            screenTimeTracker: mockTracker,
            pauseConditionProvider: AlwaysPausedProvider())
        defer { coordinator.stopFallbackTimers() }

        await coordinator.scheduleReminders()

        XCTAssertEqual(
            mockTracker.resumeAllCallCount,
            0,
            "configureScreenTimeTracker must not call resumeAll() when a pause condition is active")
    }

    // MARK: - cancelAllReminders → screenTimeTracker.pauseAll

    func test_cancelAllReminders_callsPauseAllOnTracker() {
        let mockTracker = MockScreenTimeTracker()
        let (coordinator, _, _, _) = makeCoordinator(screenTimeTracker: mockTracker)
        defer { coordinator.stopFallbackTimers() }

        coordinator.cancelAllReminders()

        XCTAssertEqual(
            mockTracker.pauseAllCallCount,
            1,
            "cancelAllReminders must call pauseAll() on the ScreenTimeTracker")
    }

    func test_cancelAllReminders_withSnoozeActive_doesNotCrash() {
        settings.snoozedUntil = Date(timeIntervalSinceNow: 300)
        let (coordinator, _, _, _) = makeCoordinator()
        defer { coordinator.stopFallbackTimers() }

        coordinator.cancelAllReminders()
    }

    // MARK: - cancelReminder(for:) → disableTracking

    func test_cancelReminder_forEyes_callsDisableTrackingOnTracker() {
        let mockTracker = MockScreenTimeTracker()
        let (coordinator, _, _, _) = makeCoordinator(screenTimeTracker: mockTracker)
        defer { coordinator.stopFallbackTimers() }

        coordinator.cancelReminder(for: .eyes)

        XCTAssertTrue(
            mockTracker.disableTrackingCalls.contains(.eyes),
            "cancelReminder(for: .eyes) must call disableTracking(for: .eyes) on the tracker")
    }

    func test_cancelReminder_forPosture_callsDisableTrackingOnTracker() {
        let mockTracker = MockScreenTimeTracker()
        let (coordinator, _, _, _) = makeCoordinator(screenTimeTracker: mockTracker)
        defer { coordinator.stopFallbackTimers() }

        coordinator.cancelReminder(for: .posture)

        XCTAssertTrue(
            mockTracker.disableTrackingCalls.contains(.posture),
            "cancelReminder(for: .posture) must call disableTracking(for: .posture) on the tracker")
    }

    // MARK: - appWillResignActive

    func test_appWillResignActive_doesNotCrash() {
        let (coordinator, _, _, _) = makeCoordinator()
        defer { coordinator.stopFallbackTimers() }

        coordinator.appWillResignActive()
    }

    // MARK: - handleForegroundTransition

    func test_handleForegroundTransition_withExpiredSnooze_clearsSnoozeState() async {
        settings.snoozedUntil = Date(timeIntervalSinceNow: -120)
        settings.snoozeCount = 1
        let (coordinator, _, _, _) = makeCoordinator()
        defer { coordinator.stopFallbackTimers() }

        await coordinator.handleForegroundTransition()

        XCTAssertNil(
            settings.snoozedUntil,
            "handleForegroundTransition must clear an expired snoozedUntil")
        XCTAssertEqual(
            settings.snoozeCount,
            0,
            "handleForegroundTransition must reset snoozeCount when snooze has expired")
    }

    func test_handleForegroundTransition_withActiveSnooze_doesNotClearSnooze() async {
        let futureDate = Date(timeIntervalSinceNow: 600)
        settings.snoozedUntil = futureDate
        settings.snoozeCount = 1
        let (coordinator, _, _, _) = makeCoordinator()
        defer { coordinator.stopFallbackTimers() }

        await coordinator.handleForegroundTransition()

        XCTAssertEqual(
            settings.snoozedUntil,
            futureDate,
            "handleForegroundTransition must not clear an active snoozedUntil")
        XCTAssertEqual(settings.snoozeCount, 1)
    }

    func test_handleForegroundTransition_withNoSnooze_doesNotCrash() async {
        settings.snoozedUntil = nil
        let (coordinator, _, _, _) = makeCoordinator()
        defer { coordinator.stopFallbackTimers() }

        await coordinator.handleForegroundTransition()
    }

    // MARK: - startFallbackTimers

    func test_startFallbackTimers_doesNotCrash() {
        let mockTracker = MockScreenTimeTracker()
        let (coordinator, _, _, _) = makeCoordinator(screenTimeTracker: mockTracker)
        defer { coordinator.stopFallbackTimers() }

        coordinator.startFallbackTimers()
    }

    func test_startFallbackTimers_callsStartIfActiveOnTracker() {
        let mockTracker = MockScreenTimeTracker()
        let (coordinator, _, _, _) = makeCoordinator(screenTimeTracker: mockTracker)
        defer { coordinator.stopFallbackTimers() }

        coordinator.startFallbackTimers()

        XCTAssertEqual(
            mockTracker.startIfActiveCallCount,
            1,
            "startFallbackTimers must call startIfActive() on the ScreenTimeTracker")
    }
}

// MARK: - AlwaysPausedProvider

/// Minimal `PauseConditionProviding` stub whose `isPaused` is always `true`.
/// Used to test `configureScreenTimeTracker` guard path without a live system.
private final class AlwaysPausedProvider: PauseConditionProviding {
    var onPauseStateChanged: ((Bool) -> Void)?
    var isPaused: Bool { true }
    func startMonitoring() {}
    func stopMonitoring() {}
}

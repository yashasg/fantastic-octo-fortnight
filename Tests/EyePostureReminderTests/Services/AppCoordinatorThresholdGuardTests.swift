@testable import EyePostureReminder
import XCTest

/// Regression tests for issue #407:
/// `AppCoordinator.onThresholdReached` must guard on `settings.isEnabled(for:)`
/// before showing an overlay or resetting `snoozeCount`.
///
/// Scenario: the user disables a reminder type. `reschedule(for:)` debounces
/// `disableTracking(for:)` by 300 ms. During that window the tracker is still
/// active and may fire `onThresholdReached`. Without the guard, a spurious
/// overlay appears and `snoozeCount` is incorrectly reset.
@MainActor
final class AppCoordinatorThresholdGuardTests: XCTestCase {

    private var mockPersistence: MockSettingsPersisting!
    private var settings: SettingsStore!
    private var mockOverlay: MockOverlayPresenting!
    private var mockTracker: MockScreenTimeTracker!
    private var sut: AppCoordinator!

    override func setUp() async throws {
        try await super.setUp()
        mockPersistence = MockSettingsPersisting()
        settings = SettingsStore(store: mockPersistence)
        mockOverlay = MockOverlayPresenting()
        mockTracker = MockScreenTimeTracker()
        let mockNotif = MockNotificationCenter()
        sut = AppCoordinator(
            settings: settings,
            scheduler: ReminderScheduler(notificationCenter: mockNotif),
            notificationCenter: mockNotif,
            overlayManager: mockOverlay,
            screenTimeTracker: mockTracker,
            pauseConditionProvider: MockPauseConditionProvider(),
            ipcStore: MockAppGroupIPCRecorder()
        )
    }

    override func tearDown() async throws {
        sut.stopFallbackTimers()
        sut = nil
        mockTracker = nil
        mockOverlay = nil
        settings = nil
        mockPersistence = nil
        try await super.tearDown()
    }

    // MARK: - Disabled type: threshold must be suppressed

    func test_thresholdReached_whenTypeDisabled_doesNotShowOverlay() {
        // Disable eyes — simulates the 300 ms debounce window where the
        // tracker is still hot but the user has toggled the type off.
        settings.eyesEnabled = false

        mockTracker.simulateThresholdReached(for: .eyes)

        XCTAssertEqual(
            mockOverlay.showCallCount, 0,
            "No overlay should be shown for a disabled reminder type"
        )
    }

    func test_thresholdReached_whenTypeDisabled_doesNotResetSnoozeCount() {
        settings.eyesEnabled = false
        settings.snoozeCount = 3  // sentinel value

        mockTracker.simulateThresholdReached(for: .eyes)

        XCTAssertEqual(
            settings.snoozeCount, 3,
            "snoozeCount must not be reset when the threshold fires for a disabled type"
        )
    }

    func test_thresholdReached_posture_whenDisabled_doesNotShowOverlay() {
        settings.postureEnabled = false

        mockTracker.simulateThresholdReached(for: .posture)

        XCTAssertEqual(mockOverlay.showCallCount, 0)
    }

    func test_thresholdReached_posture_whenDisabled_doesNotResetSnoozeCount() {
        settings.postureEnabled = false
        settings.snoozeCount = 2

        mockTracker.simulateThresholdReached(for: .posture)

        XCTAssertEqual(settings.snoozeCount, 2)
    }

    // MARK: - Enabled type: threshold must still show overlay (regression guard)

    func test_thresholdReached_whenTypeEnabled_showsOverlay() {
        // Both types default to enabled; this test guards against regressions
        // where the new guard incorrectly suppresses enabled-type reminders.
        settings.eyesEnabled = true

        mockTracker.simulateThresholdReached(for: .eyes)

        XCTAssertEqual(
            mockOverlay.showCallCount, 1,
            "Overlay must be shown for an enabled reminder type"
        )
    }

    func test_thresholdReached_whenTypeEnabled_resetsSnoozeCount() {
        settings.eyesEnabled = true
        settings.snoozeCount = 5

        mockTracker.simulateThresholdReached(for: .eyes)

        XCTAssertEqual(
            settings.snoozeCount, 0,
            "snoozeCount must be reset to 0 when the threshold fires for an enabled type"
        )
    }

    func test_thresholdReached_posture_whenEnabled_showsOverlay() {
        settings.postureEnabled = true

        mockTracker.simulateThresholdReached(for: .posture)

        XCTAssertEqual(mockOverlay.showCallCount, 1)
    }

    // MARK: - Mixed: one enabled, one disabled

    func test_thresholdReached_eyesDisabled_postureEnabled_onlyPostureShowsOverlay() {
        settings.eyesEnabled = false
        settings.postureEnabled = true

        mockTracker.simulateThresholdReached(for: .eyes)
        mockTracker.simulateThresholdReached(for: .posture)

        XCTAssertEqual(mockOverlay.showCallCount, 1,
            "Only the enabled posture overlay should appear")
        XCTAssertEqual(mockOverlay.showCallOrder.first, .posture)
    }
}

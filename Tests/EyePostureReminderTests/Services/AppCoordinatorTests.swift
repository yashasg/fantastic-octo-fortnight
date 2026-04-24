import XCTest
@testable import EyePostureReminder

/// Unit tests for `AppCoordinator`.
///
/// Coverage is intentionally limited to logic that executes cleanly without a
/// live `UIWindowScene`. UIKit-dependent paths (`handleNotification`,
/// `startFallbackTimers`, `scheduleReminders`) are exercised in the simulator
/// integration suite, not here.
@MainActor
final class AppCoordinatorTests: XCTestCase {

    var mockPersistence: MockSettingsPersisting!
    var settings: SettingsStore!
    var sut: AppCoordinator!

    override func setUp() async throws {
        try await super.setUp()
        mockPersistence = MockSettingsPersisting()
        settings = SettingsStore(store: mockPersistence)
        sut = AppCoordinator(settings: settings, scheduler: ReminderScheduler())
    }

    override func tearDown() async throws {
        sut.stopFallbackTimers()
        sut = nil
        settings = nil
        mockPersistence = nil
        try await super.tearDown()
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

    func test_init_defaultParameterless_doesNotCrash() {
        let coordinator = AppCoordinator()
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

    /// When no notification-tap has queued an overlay, calling this on
    /// `.active` scene transition should be a no-op — no crash, no UIKit access.
    func test_presentPendingOverlayIfNeeded_withNoPendingOverlay_doesNotCrash() {
        sut.presentPendingOverlayIfNeeded()
    }

    func test_presentPendingOverlayIfNeeded_calledTwice_doesNotCrash() {
        sut.presentPendingOverlayIfNeeded()
        sut.presentPendingOverlayIfNeeded()
    }
}

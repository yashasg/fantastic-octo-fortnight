@testable import EyePostureReminder
import XCTest

@MainActor
final class AppCoordinatorUITestModeResolverTests: XCTestCase {

    func test_isUITestMode_withMatchingLaunchArgument_returnsTrue() {
        XCTAssertTrue(AppCoordinator.isUITestMode(launchArguments: ["--show-overlay-eyes"]))
    }

    func test_init_withUITestLaunchArgument_andNoTracker_resolvesNoopScreenTimeTracker() {
        let mockNotif = MockNotificationCenter()
        let coordinator = AppCoordinator(
            settings: SettingsStore(store: MockSettingsPersisting()),
            scheduler: ReminderScheduler(notificationCenter: mockNotif),
            notificationCenter: mockNotif,
            pauseConditionProvider: MockPauseConditionProvider(),
            launchArguments: ["--skip-onboarding"],
            ipcStore: MockAppGroupIPCRecorder()
        )
        defer { coordinator.stopFallbackTimers() }

        XCTAssertTrue(coordinator.screenTimeTracker is NoopScreenTimeTracker)
    }

    func test_init_withInjectedUITestModeTrue_andNoTracker_resolvesNoopScreenTimeTracker() {
        let mockNotif = MockNotificationCenter()
        let coordinator = AppCoordinator(
            settings: SettingsStore(store: MockSettingsPersisting()),
            scheduler: ReminderScheduler(notificationCenter: mockNotif),
            notificationCenter: mockNotif,
            pauseConditionProvider: MockPauseConditionProvider(),
            uiTestMode: true,
            ipcStore: MockAppGroupIPCRecorder()
        )
        defer { coordinator.stopFallbackTimers() }

        XCTAssertTrue(coordinator.screenTimeTracker is NoopScreenTimeTracker)
    }

    func test_init_withInjectedTracker_andUITestModeTrue_keepsInjectedTracker() {
        let mockNotif = MockNotificationCenter()
        let injectedTracker = MockScreenTimeTracker()
        let coordinator = AppCoordinator(
            settings: SettingsStore(store: MockSettingsPersisting()),
            scheduler: ReminderScheduler(notificationCenter: mockNotif),
            notificationCenter: mockNotif,
            screenTimeTracker: injectedTracker,
            pauseConditionProvider: MockPauseConditionProvider(),
            uiTestMode: true,
            ipcStore: MockAppGroupIPCRecorder()
        )
        defer { coordinator.stopFallbackTimers() }

        XCTAssertTrue(coordinator.screenTimeTracker === injectedTracker)
    }

    func test_init_withInjectedUITestModeTrue_andNoPauseProvider_resolvesNoopPauseConditionManager() {
        let mockNotif = MockNotificationCenter()
        let coordinator = AppCoordinator(
            settings: SettingsStore(store: MockSettingsPersisting()),
            scheduler: ReminderScheduler(notificationCenter: mockNotif),
            notificationCenter: mockNotif,
            uiTestMode: true,
            ipcStore: MockAppGroupIPCRecorder()
        )
        defer { coordinator.stopFallbackTimers() }

        XCTAssertTrue(coordinator.pauseConditionManager is NoopPauseConditionManager)
    }
}

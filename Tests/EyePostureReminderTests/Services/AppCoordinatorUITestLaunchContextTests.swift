@testable import EyePostureReminder
import XCTest

@MainActor
final class AppCoordinatorUITestLaunchContextTests: XCTestCase {

    func test_init_withInjectedProcessEnvironment_notDetermined_returnsStub() {
        let mockNotif = MockNotificationCenter()
        let coordinator = AppCoordinator(
            settings: SettingsStore(store: MockSettingsPersisting()),
            scheduler: ReminderScheduler(notificationCenter: mockNotif),
            notificationCenter: mockNotif,
            screenTimeTracker: MockScreenTimeTracker(),
            pauseConditionProvider: MockPauseConditionProvider(),
            uiTestStatusStore: isolatedDefaults(for: #function),
            processEnvironment: ["UITEST_SCREEN_TIME_STATUS": "notDetermined"],
            launchArguments: ["EyePostureReminderTests"],
            ipcStore: MockAppGroupIPCRecorder()
        )
        defer { coordinator.stopFallbackTimers() }

        let stub = coordinator.screenTimeAuthorization as? ScreenTimeAuthorizationStub
        XCTAssertEqual(stub?.authorizationStatus, .notDetermined)
    }

    func test_init_withInjectedLaunchArguments_simulateNotDetermined_returnsStub() {
        let mockNotif = MockNotificationCenter()
        let coordinator = AppCoordinator(
            settings: SettingsStore(store: MockSettingsPersisting()),
            scheduler: ReminderScheduler(notificationCenter: mockNotif),
            notificationCenter: mockNotif,
            screenTimeTracker: MockScreenTimeTracker(),
            pauseConditionProvider: MockPauseConditionProvider(),
            uiTestStatusStore: isolatedDefaults(for: #function),
            processEnvironment: [:],
            launchArguments: ["EyePostureReminderTests", "--simulate-screen-time-not-determined"],
            ipcStore: MockAppGroupIPCRecorder()
        )
        defer { coordinator.stopFallbackTimers() }

        let stub = coordinator.screenTimeAuthorization as? ScreenTimeAuthorizationStub
        XCTAssertEqual(stub?.authorizationStatus, .notDetermined)
    }

    private func isolatedDefaults(for function: StaticString) -> UserDefaults {
        let suiteName = "AppCoordinatorUITestLaunchContextTests.\(function)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Expected isolated UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock { defaults.removePersistentDomain(forName: suiteName) }
        return defaults
    }
}

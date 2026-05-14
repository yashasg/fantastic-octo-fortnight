import XCTest

@testable import EyePostureReminder

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

    func test_init_withoutLaunchArguments_usesInjectedLaunchArgumentsProvider() {
        let mockNotif = MockNotificationCenter()
        var providerCallCount = 0
        let coordinator = AppCoordinator(
            settings: SettingsStore(store: MockSettingsPersisting()),
            scheduler: ReminderScheduler(notificationCenter: mockNotif),
            notificationCenter: mockNotif,
            screenTimeTracker: MockScreenTimeTracker(),
            pauseConditionProvider: MockPauseConditionProvider(),
            uiTestStatusStore: isolatedDefaults(for: #function),
            processEnvironment: [:],
            launchArguments: nil,
            launchArgumentsProvider: {
                providerCallCount += 1
                return ["EyePostureReminderTests", "--simulate-screen-time-not-determined"]
            },
            ipcStore: MockAppGroupIPCRecorder()
        )
        defer { coordinator.stopFallbackTimers() }

        let stub = coordinator.screenTimeAuthorization as? ScreenTimeAuthorizationStub
        XCTAssertEqual(providerCallCount, 1)
        XCTAssertEqual(stub?.authorizationStatus, .notDetermined)
    }

    func test_init_withExplicitLaunchArguments_doesNotCallInjectedLaunchArgumentsProvider() {
        let mockNotif = MockNotificationCenter()
        var providerCallCount = 0
        let coordinator = AppCoordinator(
            settings: SettingsStore(store: MockSettingsPersisting()),
            scheduler: ReminderScheduler(notificationCenter: mockNotif),
            notificationCenter: mockNotif,
            screenTimeTracker: MockScreenTimeTracker(),
            pauseConditionProvider: MockPauseConditionProvider(),
            uiTestStatusStore: isolatedDefaults(for: #function),
            processEnvironment: [:],
            launchArguments: ["EyePostureReminderTests", "--simulate-screen-time-not-determined"],
            launchArgumentsProvider: {
                providerCallCount += 1
                return []
            },
            ipcStore: MockAppGroupIPCRecorder()
        )
        defer { coordinator.stopFallbackTimers() }

        let stub = coordinator.screenTimeAuthorization as? ScreenTimeAuthorizationStub
        XCTAssertEqual(providerCallCount, 0)
        XCTAssertEqual(stub?.authorizationStatus, .notDetermined)
    }

    func test_init_withoutProcessEnvironment_usesInjectedProcessEnvironmentProvider() {
        let mockNotif = MockNotificationCenter()
        var providerCallCount = 0
        let coordinator = AppCoordinator(
            settings: SettingsStore(store: MockSettingsPersisting()),
            scheduler: ReminderScheduler(notificationCenter: mockNotif),
            notificationCenter: mockNotif,
            screenTimeTracker: MockScreenTimeTracker(),
            pauseConditionProvider: MockPauseConditionProvider(),
            uiTestStatusStore: isolatedDefaults(for: #function),
            processEnvironment: nil,
            processEnvironmentProvider: {
                providerCallCount += 1
                return ["UITEST_SCREEN_TIME_STATUS": "notDetermined"]
            },
            launchArguments: ["EyePostureReminderTests"],
            ipcStore: MockAppGroupIPCRecorder()
        )
        defer { coordinator.stopFallbackTimers() }

        let stub = coordinator.screenTimeAuthorization as? ScreenTimeAuthorizationStub
        XCTAssertEqual(providerCallCount, 1)
        XCTAssertEqual(stub?.authorizationStatus, .notDetermined)
    }

    func test_init_withExplicitProcessEnvironment_doesNotCallInjectedProcessEnvironmentProvider() {
        let mockNotif = MockNotificationCenter()
        var providerCallCount = 0
        let coordinator = AppCoordinator(
            settings: SettingsStore(store: MockSettingsPersisting()),
            scheduler: ReminderScheduler(notificationCenter: mockNotif),
            notificationCenter: mockNotif,
            screenTimeTracker: MockScreenTimeTracker(),
            pauseConditionProvider: MockPauseConditionProvider(),
            uiTestStatusStore: isolatedDefaults(for: #function),
            processEnvironment: ["UITEST_SCREEN_TIME_STATUS": "notDetermined"],
            processEnvironmentProvider: {
                providerCallCount += 1
                return [:]
            },
            launchArguments: ["EyePostureReminderTests"],
            ipcStore: MockAppGroupIPCRecorder()
        )
        defer { coordinator.stopFallbackTimers() }

        let stub = coordinator.screenTimeAuthorization as? ScreenTimeAuthorizationStub
        XCTAssertEqual(providerCallCount, 0)
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

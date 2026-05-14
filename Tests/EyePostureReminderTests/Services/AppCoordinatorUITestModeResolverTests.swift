import XCTest

@testable import EyePostureReminder

@MainActor
final class AppCoordinatorUITestModeResolverTests: XCTestCase {

    func test_isUITestMode_withMatchingLaunchArgument_returnsTrue() {
        XCTAssertTrue(AppCoordinator.isUITestMode(launchArguments: ["--show-overlay-eyes"]))
    }

    func test_resolveIsUITestMode_withoutLaunchArguments_usesInjectedProvider() {
        var providerCallCount = 0

        let mode = AppCoordinator.resolveIsUITestMode(launchArgumentsProvider: {
            providerCallCount += 1
            return ["--show-overlay-posture"]
        })

        XCTAssertEqual(providerCallCount, 1)
        XCTAssertTrue(mode)
    }

    func test_resolveIsUITestMode_withExplicitLaunchArguments_bypassesProvider() {
        var providerCallCount = 0

        let mode = AppCoordinator.resolveIsUITestMode(
            launchArguments: ["--skip-onboarding"],
            launchArgumentsProvider: {
                providerCallCount += 1
                return []
            }
        )

        XCTAssertEqual(providerCallCount, 0)
        XCTAssertTrue(mode)
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

    func test_refreshAuthStatus_withInjectedUITestModeTrue_skipsAuthFetch() async {
        let mockNotif = MockNotificationCenter()
        mockNotif.authorizationGranted = false
        let coordinator = AppCoordinator(
            settings: SettingsStore(store: MockSettingsPersisting()),
            scheduler: ReminderScheduler(notificationCenter: mockNotif),
            notificationCenter: mockNotif,
            pauseConditionProvider: MockPauseConditionProvider(),
            uiTestMode: true,
            ipcStore: MockAppGroupIPCRecorder()
        )
        defer { coordinator.stopFallbackTimers() }

        await coordinator.refreshAuthStatus()

        XCTAssertEqual(coordinator.notificationAuthStatus, .notDetermined)
    }

    func test_refreshAuthStatus_withInjectedUITestModeFalse_fetchesAuthStatus() async {
        let mockNotif = MockNotificationCenter()
        mockNotif.authorizationGranted = false
        let coordinator = AppCoordinator(
            settings: SettingsStore(store: MockSettingsPersisting()),
            scheduler: ReminderScheduler(notificationCenter: mockNotif),
            notificationCenter: mockNotif,
            pauseConditionProvider: MockPauseConditionProvider(),
            uiTestMode: false,
            ipcStore: MockAppGroupIPCRecorder()
        )
        defer { coordinator.stopFallbackTimers() }

        await coordinator.refreshAuthStatus()

        XCTAssertEqual(coordinator.notificationAuthStatus, .denied)
    }

    func test_scheduleReminders_withInjectedUITestModeTrue_skipsPermissionPromptAndTrackerConfiguration() async {
        let mockNotif = MockNotificationCenter()
        let tracker = MockScreenTimeTracker()
        let coordinator = AppCoordinator(
            settings: SettingsStore(store: MockSettingsPersisting()),
            scheduler: ReminderScheduler(notificationCenter: mockNotif),
            notificationCenter: mockNotif,
            screenTimeTracker: tracker,
            pauseConditionProvider: MockPauseConditionProvider(),
            uiTestMode: true,
            ipcStore: MockAppGroupIPCRecorder()
        )
        defer { coordinator.stopFallbackTimers() }

        await coordinator.scheduleReminders()

        XCTAssertEqual(mockNotif.authorizationRequestCount, 0)
        XCTAssertTrue(tracker.setThresholdCalls.isEmpty)
        XCTAssertTrue(tracker.disableTrackingCalls.isEmpty)
    }
}

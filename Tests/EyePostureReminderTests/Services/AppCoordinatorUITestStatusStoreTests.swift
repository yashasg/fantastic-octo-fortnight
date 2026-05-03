@testable import EyePostureReminder
import XCTest

@MainActor
final class AppCoordinatorUITestStatusStoreTests: XCTestCase {

    func test_init_withInjectedUITestStatusStore_usesStoredStatusForStubResolution() {
        let suiteName = "AppCoordinatorUITestStatusStoreTests.\(#function)"
        guard let isolatedDefaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Expected isolated UserDefaults suite")
            return
        }
        isolatedDefaults.removePersistentDomain(forName: suiteName)
        defer { isolatedDefaults.removePersistentDomain(forName: suiteName) }

        isolatedDefaults.set(
            ScreenTimeAuthorizationStatus.notDetermined.rawValue,
            forKey: AppStorageKey.uiTestScreenTimeStatus
        )

        let mockNotif = MockNotificationCenter()
        let coordinator = AppCoordinator(
            settings: SettingsStore(store: MockSettingsPersisting()),
            scheduler: ReminderScheduler(notificationCenter: mockNotif),
            notificationCenter: mockNotif,
            screenTimeTracker: MockScreenTimeTracker(),
            pauseConditionProvider: MockPauseConditionProvider(),
            uiTestStatusStore: isolatedDefaults,
            ipcStore: MockAppGroupIPCRecorder()
        )
        defer { coordinator.stopFallbackTimers() }

        let stub = coordinator.screenTimeAuthorization as? ScreenTimeAuthorizationStub
        XCTAssertEqual(stub?.authorizationStatus, .notDetermined)
    }

    func test_init_withInjectedUITestStatusStore_invalidRawValue_fallsBackToNoop() {
        let suiteName = "AppCoordinatorUITestStatusStoreTests.\(#function)"
        guard let isolatedDefaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Expected isolated UserDefaults suite")
            return
        }
        isolatedDefaults.removePersistentDomain(forName: suiteName)
        defer { isolatedDefaults.removePersistentDomain(forName: suiteName) }

        isolatedDefaults.set("not-a-valid-status", forKey: AppStorageKey.uiTestScreenTimeStatus)

        let mockNotif = MockNotificationCenter()
        let coordinator = AppCoordinator(
            settings: SettingsStore(store: MockSettingsPersisting()),
            scheduler: ReminderScheduler(notificationCenter: mockNotif),
            notificationCenter: mockNotif,
            screenTimeTracker: MockScreenTimeTracker(),
            pauseConditionProvider: MockPauseConditionProvider(),
            uiTestStatusStore: isolatedDefaults,
            ipcStore: MockAppGroupIPCRecorder()
        )
        defer { coordinator.stopFallbackTimers() }

        XCTAssertTrue(coordinator.screenTimeAuthorization is ScreenTimeAuthorizationNoop)
    }
}

import XCTest

@testable import EyePostureReminder

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

    func test_init_withoutUITestStatusStore_usesInjectedUITestStatusStoreFactory() {
        let suiteName = "AppCoordinatorUITestStatusStoreTests.\(#function)"
        guard let factoryDefaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Expected isolated UserDefaults suite")
            return
        }
        factoryDefaults.removePersistentDomain(forName: suiteName)
        defer { factoryDefaults.removePersistentDomain(forName: suiteName) }
        factoryDefaults.set(
            ScreenTimeAuthorizationStatus.notDetermined.rawValue,
            forKey: AppStorageKey.uiTestScreenTimeStatus
        )

        var factoryCallCount = 0
        let mockNotif = MockNotificationCenter()
        let coordinator = AppCoordinator(
            settings: SettingsStore(store: MockSettingsPersisting()),
            scheduler: ReminderScheduler(notificationCenter: mockNotif),
            notificationCenter: mockNotif,
            screenTimeTracker: MockScreenTimeTracker(),
            pauseConditionProvider: MockPauseConditionProvider(),
            uiTestStatusStore: nil,
            makeUITestStatusStore: {
                factoryCallCount += 1
                return factoryDefaults
            },
            ipcStore: MockAppGroupIPCRecorder()
        )
        defer { coordinator.stopFallbackTimers() }

        let stub = coordinator.screenTimeAuthorization as? ScreenTimeAuthorizationStub
        XCTAssertEqual(factoryCallCount, 1)
        XCTAssertEqual(stub?.authorizationStatus, .notDetermined)
    }

    func test_init_withExplicitUITestStatusStore_doesNotCallInjectedUITestStatusStoreFactory() {
        let explicitSuiteName = "AppCoordinatorUITestStatusStoreTests.\(#function).explicit"
        guard let explicitDefaults = UserDefaults(suiteName: explicitSuiteName) else {
            XCTFail("Expected isolated explicit UserDefaults suite")
            return
        }
        explicitDefaults.removePersistentDomain(forName: explicitSuiteName)
        defer { explicitDefaults.removePersistentDomain(forName: explicitSuiteName) }
        explicitDefaults.set("not-a-valid-status", forKey: AppStorageKey.uiTestScreenTimeStatus)

        let factorySuiteName = "AppCoordinatorUITestStatusStoreTests.\(#function).factory"
        guard let factoryDefaults = UserDefaults(suiteName: factorySuiteName) else {
            XCTFail("Expected isolated factory UserDefaults suite")
            return
        }
        factoryDefaults.removePersistentDomain(forName: factorySuiteName)
        defer { factoryDefaults.removePersistentDomain(forName: factorySuiteName) }
        factoryDefaults.set(
            ScreenTimeAuthorizationStatus.notDetermined.rawValue,
            forKey: AppStorageKey.uiTestScreenTimeStatus
        )

        var factoryCallCount = 0
        let mockNotif = MockNotificationCenter()
        let coordinator = AppCoordinator(
            settings: SettingsStore(store: MockSettingsPersisting()),
            scheduler: ReminderScheduler(notificationCenter: mockNotif),
            notificationCenter: mockNotif,
            screenTimeTracker: MockScreenTimeTracker(),
            pauseConditionProvider: MockPauseConditionProvider(),
            uiTestStatusStore: explicitDefaults,
            makeUITestStatusStore: {
                factoryCallCount += 1
                return factoryDefaults
            },
            ipcStore: MockAppGroupIPCRecorder()
        )
        defer { coordinator.stopFallbackTimers() }

        XCTAssertEqual(factoryCallCount, 0)
        XCTAssertTrue(coordinator.screenTimeAuthorization is ScreenTimeAuthorizationNoop)
    }
}

@testable import EyePostureReminder
@testable import ScreenTimeExtensionShared
import XCTest

@MainActor
final class AppCoordinatorWatchdogHeartbeatTests: XCTestCase {
    private var settings: SettingsStore!
    private var notificationCenter: MockNotificationCenter!
    private var tracker: MockScreenTimeTracker!
    private var ipcStore: MockAppGroupIPCRecorder!
    private var coordinator: AppCoordinator!

    override func setUp() async throws {
        try await super.setUp()
        settings = SettingsStore(store: MockSettingsPersisting())
        notificationCenter = MockNotificationCenter()
        tracker = MockScreenTimeTracker()
        ipcStore = MockAppGroupIPCRecorder()
        coordinator = AppCoordinator(
            settings: settings,
            scheduler: ReminderScheduler(notificationCenter: notificationCenter),
            notificationCenter: notificationCenter,
            overlayManager: MockOverlayPresenting(),
            screenTimeTracker: tracker,
            pauseConditionProvider: MockPauseConditionProvider(),
            ipcStore: ipcStore
        )
    }

    override func tearDown() async throws {
        coordinator.stopFallbackTimers()
        coordinator = nil
        ipcStore = nil
        tracker = nil
        notificationCenter = nil
        settings = nil
        try await super.tearDown()
    }

    func test_init_recordsCoordinatorHeartbeat() {
        XCTAssertTrue(heartbeatDetails.contains(.coordinatorInitialized))
    }

    func test_scheduleReminders_recordsSchedulingHeartbeat() async {
        await coordinator.scheduleReminders()

        XCTAssertTrue(heartbeatDetails.contains(.scheduleReminders))
    }

    func test_foregroundAndBackgroundTransitions_recordLifecycleHeartbeats() async {
        await coordinator.handleForegroundTransition()
        coordinator.appWillResignActive()

        XCTAssertTrue(heartbeatDetails.contains(.appForeground))
        XCTAssertTrue(heartbeatDetails.contains(.appBackground))
    }

    private var heartbeatDetails: [WatchdogHeartbeatDetail] {
        ipcStore.events
            .filter { $0.kind == .watchdogHeartbeat }
            .compactMap { event in
                event.detail.flatMap(WatchdogHeartbeatDetail.init(rawValue:))
            }
    }
}

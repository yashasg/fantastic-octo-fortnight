@testable import EyePostureReminder
@testable import ScreenTimeExtensionShared
import XCTest

@MainActor
final class AppCoordinatorWatchdogHeartbeatTests: XCTestCase {
    private var settings: SettingsStore!
    private var notificationCenter: MockNotificationCenter!
    private var tracker: MockScreenTimeTracker!
    private var deviceActivityMonitor: MockDeviceActivityMonitorProviding!
    private var ipcStore: MockAppGroupIPCRecorder!
    private var coordinator: AppCoordinator!

    override func setUp() async throws {
        try await super.setUp()
        settings = SettingsStore(store: MockSettingsPersisting())
        notificationCenter = MockNotificationCenter()
        notificationCenter.authorizationGranted = true
        tracker = MockScreenTimeTracker()
        deviceActivityMonitor = MockDeviceActivityMonitorProviding()
        ipcStore = MockAppGroupIPCRecorder()
        coordinator = AppCoordinator(
            settings: settings,
            scheduler: ReminderScheduler(notificationCenter: notificationCenter),
            notificationCenter: notificationCenter,
            overlayManager: MockOverlayPresenting(),
            screenTimeTracker: tracker,
            pauseConditionProvider: MockPauseConditionProvider(),
            deviceActivityMonitor: deviceActivityMonitor,
            ipcStore: ipcStore
        )
    }

    override func tearDown() async throws {
        coordinator.stopFallbackTimers()
        coordinator = nil
        ipcStore = nil
        deviceActivityMonitor = nil
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

    func test_foregroundTransition_whenDeviceActivityHeartbeatStale_recoversShieldSession() async throws {
        deviceActivityMonitor.stubbedIsAvailable = true
        let sessionStart = Date(timeIntervalSince1970: 1)
        ipcStore.shieldSessionSnapshot = ShieldSessionSnapshot(
            reasonRaw: ReminderType.eyes.shieldReason.rawValue,
            durationSeconds: 20,
            triggeredAt: sessionStart
        )
        try ipcStore.recordEvent(
            WatchdogHeartbeat.event(.deviceActivityIntervalStarted, timestamp: sessionStart)
        )

        await coordinator.handleForegroundTransition()
        try await Task.sleep(nanoseconds: 100_000_000)

        let event = try XCTUnwrap(ipcStore.events.first { $0.kind == .watchdogRecoveryTriggered })
        XCTAssertEqual(event.reasonRaw, ReminderType.eyes.shieldReason.rawValue)
        XCTAssertEqual(
            event.detail,
            "watchdog_device_activity_heartbeat_stale:device_activity_interval_started"
        )
        XCTAssertEqual(ipcStore.clearShieldSessionCallCount, 1)
        XCTAssertEqual(deviceActivityMonitor.cancelCallCount, 1)
        XCTAssertEqual(notificationCenter.addedRequests.count, 1)
    }

    func test_foregroundTransition_whenDeviceActivityHeartbeatMissingAfterDeadline_recovers() async throws {
        deviceActivityMonitor.stubbedIsAvailable = true
        ipcStore.shieldSessionSnapshot = ShieldSessionSnapshot(
            reasonRaw: ReminderType.posture.shieldReason.rawValue,
            durationSeconds: 10,
            triggeredAt: Date(timeIntervalSince1970: 1)
        )

        await coordinator.handleForegroundTransition()
        try await Task.sleep(nanoseconds: 100_000_000)

        let event = try XCTUnwrap(ipcStore.events.first { $0.kind == .watchdogRecoveryTriggered })
        XCTAssertEqual(event.reasonRaw, ReminderType.posture.shieldReason.rawValue)
        XCTAssertEqual(event.detail, "watchdog_device_activity_heartbeat_missing")
        XCTAssertEqual(ipcStore.clearShieldSessionCallCount, 1)
        XCTAssertEqual(deviceActivityMonitor.cancelCallCount, 1)
    }

    func test_foregroundTransition_whenDeviceActivityHeartbeatFresh_doesNotRecover() async {
        deviceActivityMonitor.stubbedIsAvailable = true
        let now = Date()
        ipcStore.shieldSessionSnapshot = ShieldSessionSnapshot(
            reasonRaw: ReminderType.eyes.shieldReason.rawValue,
            durationSeconds: 20,
            triggeredAt: now
        )
        try? ipcStore.recordEvent(
            WatchdogHeartbeat.event(.deviceActivityIntervalStarted, timestamp: now)
        )

        await coordinator.handleForegroundTransition()
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertFalse(ipcStore.events.contains { $0.kind == .watchdogRecoveryTriggered })
        XCTAssertEqual(ipcStore.clearShieldSessionCallCount, 0)
        XCTAssertEqual(deviceActivityMonitor.cancelCallCount, 0)
    }

    private var heartbeatDetails: [WatchdogHeartbeatDetail] {
        ipcStore.events
            .filter { $0.kind == .watchdogHeartbeat }
            .compactMap { event in
                event.detail.flatMap(WatchdogHeartbeatDetail.init(rawValue:))
            }
    }
}

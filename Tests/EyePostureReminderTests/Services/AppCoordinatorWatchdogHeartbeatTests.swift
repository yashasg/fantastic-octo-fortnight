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
        await awaitCondition { deviceActivityMonitor.cancelCallCount >= 1 }

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
        await awaitCondition { deviceActivityMonitor.cancelCallCount >= 1 }

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
        // No recovery expected — yield to allow any spurious tasks to complete.
        await Task.yield()

        XCTAssertFalse(ipcStore.events.contains { $0.kind == .watchdogRecoveryTriggered })
        XCTAssertEqual(ipcStore.clearShieldSessionCallCount, 0)
        XCTAssertEqual(deviceActivityMonitor.cancelCallCount, 0)
    }

    func test_foregroundTransition_whenReadShieldSessionThrows_skipsRecovery() async {
        deviceActivityMonitor.stubbedIsAvailable = true
        ipcStore.shieldSessionSnapshot = ShieldSessionSnapshot(
            reasonRaw: ReminderType.eyes.shieldReason.rawValue,
            durationSeconds: 20,
            triggeredAt: Date(timeIntervalSince1970: 1)
        )
        ipcStore.readShieldSessionError = AppGroupIPCStore.StoreError.corruptShieldSession

        await coordinator.handleForegroundTransition()

        XCTAssertFalse(ipcStore.events.contains { $0.kind == .watchdogRecoveryTriggered })
        XCTAssertEqual(ipcStore.clearShieldSessionCallCount, 0)
        XCTAssertEqual(deviceActivityMonitor.cancelCallCount, 0)
        XCTAssertTrue(notificationCenter.addedRequests.isEmpty)
    }

    func test_watchdogRecovery_whenStaleAfterIsZero_doesNotRecover() async {
        let zeroGraceCoordinator = AppCoordinator(
            settings: settings,
            scheduler: ReminderScheduler(notificationCenter: notificationCenter),
            notificationCenter: notificationCenter,
            overlayManager: MockOverlayPresenting(),
            screenTimeTracker: tracker,
            pauseConditionProvider: MockPauseConditionProvider(),
            deviceActivityMonitor: deviceActivityMonitor,
            ipcStore: ipcStore,
            watchdogHeartbeatGraceInterval: 0
        )
        defer { zeroGraceCoordinator.stopFallbackTimers() }

        deviceActivityMonitor.stubbedIsAvailable = true
        ipcStore.shieldSessionSnapshot = ShieldSessionSnapshot(
            reasonRaw: ReminderType.eyes.shieldReason.rawValue,
            durationSeconds: 0,
            triggeredAt: Date(timeIntervalSince1970: 1)
        )

        await zeroGraceCoordinator.handleForegroundTransition()
        // No recovery expected with zero grace — yield to allow any spurious tasks to complete.
        await Task.yield()

        XCTAssertFalse(ipcStore.events.contains { $0.kind == .watchdogRecoveryTriggered })
        XCTAssertEqual(ipcStore.clearShieldSessionCallCount, 0)
        XCTAssertEqual(deviceActivityMonitor.cancelCallCount, 0)
        XCTAssertTrue(notificationCenter.addedRequests.isEmpty)
    }

    func test_foregroundTransition_whenReadEventsThrows_skipsRecovery() async {
        struct ReadEventsFailure: Error {}
        deviceActivityMonitor.stubbedIsAvailable = true
        ipcStore.shieldSessionSnapshot = ShieldSessionSnapshot(
            reasonRaw: ReminderType.posture.shieldReason.rawValue,
            durationSeconds: 10,
            triggeredAt: Date(timeIntervalSince1970: 1)
        )
        ipcStore.readEventsError = ReadEventsFailure()

        await coordinator.handleForegroundTransition()

        XCTAssertFalse(ipcStore.events.contains { $0.kind == .watchdogRecoveryTriggered })
        XCTAssertEqual(ipcStore.clearShieldSessionCallCount, 0)
        XCTAssertEqual(deviceActivityMonitor.cancelCallCount, 0)
        XCTAssertTrue(notificationCenter.addedRequests.isEmpty)
    }

    func test_watchdogRecovery_corruptLegacyEventLog_stillTriggersRecovery() async throws {
        // Regression test for issue #306: corrupt legacy eventLog key must not block
        // watchdog recovery when per-slot events are readable.
        // Part 1: prove real AppGroupIPCStore no longer throws on corrupt legacy data.
        let suiteName = "WatchdogCorruptLegacyTest"
        let testDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        testDefaults.removePersistentDomain(forName: suiteName)
        defer { testDefaults.removePersistentDomain(forName: suiteName) }

        let realIPCStore = AppGroupIPCStore(defaults: testDefaults, maxEventCount: 100)
        testDefaults.set(Data("not-json".utf8), forKey: AppGroupIPCKeys.eventLog)
        let events = try realIPCStore.readEvents()
        XCTAssertEqual(events, [], "No valid events expected — legacy is corrupt, no slot events written")

        // Part 2: verify watchdog recovery proceeds when readEvents succeeds (empty).
        deviceActivityMonitor.stubbedIsAvailable = true
        let sessionStart = Date(timeIntervalSince1970: 1)
        ipcStore.shieldSessionSnapshot = ShieldSessionSnapshot(
            reasonRaw: ReminderType.eyes.shieldReason.rawValue,
            durationSeconds: 20,
            triggeredAt: sessionStart
        )

        let recovered = await coordinator.recoverStaleDeviceActivityWatchdogIfNeeded()
        await awaitCondition { deviceActivityMonitor.cancelCallCount >= 1 }

        XCTAssertTrue(
            recovered,
            "Watchdog recovery must succeed when legacy eventLog is corrupt but per-slot events are intact")
        XCTAssertEqual(ipcStore.clearShieldSessionCallCount, 1)
        XCTAssertEqual(deviceActivityMonitor.cancelCallCount, 1)
    }

    func test_foregroundTransition_withOldSessionHeartbeatAndNewSessionMissingHeartbeat_recovers() async throws {
        // Regression test for issue #288: a fresh heartbeat from a prior session must not
        // suppress watchdog recovery for a newer session whose extension never heartbeat.
        deviceActivityMonitor.stubbedIsAvailable = true
        let sessionBStart = Date(timeIntervalSince1970: 105)
        ipcStore.shieldSessionSnapshot = ShieldSessionSnapshot(
            reasonRaw: ReminderType.eyes.shieldReason.rawValue,
            durationSeconds: 20,
            triggeredAt: sessionBStart
        )
        // Session A's heartbeat at T=100 — before session B start (T=105).
        try ipcStore.recordEvent(
            WatchdogHeartbeat.event(.deviceActivityIntervalEnded, timestamp: Date(timeIntervalSince1970: 100))
        )

        await coordinator.handleForegroundTransition()
        await awaitCondition { deviceActivityMonitor.cancelCallCount >= 1 }

        // Recovery must be triggered via the .missing path (not suppressed by prior-session heartbeat).
        let event = try XCTUnwrap(ipcStore.events.first { $0.kind == .watchdogRecoveryTriggered })
        XCTAssertEqual(event.reasonRaw, ReminderType.eyes.shieldReason.rawValue)
        XCTAssertEqual(event.detail, "watchdog_device_activity_heartbeat_missing")
        XCTAssertEqual(ipcStore.clearShieldSessionCallCount, 1)
        XCTAssertEqual(deviceActivityMonitor.cancelCallCount, 1)
    }

    // MARK: - #286: Snooze guard in watchdog recovery

    func test_watchdogRecovery_duringActiveSnooze_doesNotCallRescheduleReminder() async throws {
        // Regression test for issue #286: stale watchdog recovery must not schedule
        // a fallback notification while a snooze is still active.
        // Call recoverStaleDeviceActivityWatchdogIfNeeded directly with a MockReminderScheduler
        // so we can assert precisely that rescheduleReminder is never called.
        let mockScheduler = MockReminderScheduler()
        let snoozeCoordinator = AppCoordinator(
            settings: settings,
            scheduler: mockScheduler,
            notificationCenter: notificationCenter,
            overlayManager: MockOverlayPresenting(),
            screenTimeTracker: tracker,
            pauseConditionProvider: MockPauseConditionProvider(),
            deviceActivityMonitor: deviceActivityMonitor,
            ipcStore: ipcStore
        )
        defer { snoozeCoordinator.stopFallbackTimers() }

        deviceActivityMonitor.stubbedIsAvailable = true
        notificationCenter.authorizationGranted = true
        settings.notificationFallbackEnabled = true
        settings.snoozedUntil = Date(timeIntervalSinceNow: 300) // snooze active

        ipcStore.shieldSessionSnapshot = ShieldSessionSnapshot(
            reasonRaw: ReminderType.eyes.shieldReason.rawValue,
            durationSeconds: 20,
            triggeredAt: Date(timeIntervalSince1970: 1)
        )

        // Refresh auth status so notificationAuthStatus == .authorized before recovery check.
        await snoozeCoordinator.refreshAuthStatus()
        let recovered = await snoozeCoordinator.recoverStaleDeviceActivityWatchdogIfNeeded()
        await awaitCondition { deviceActivityMonitor.cancelCallCount >= 1 }

        // Recovery must still run and clean up the stale session and DA monitoring…
        XCTAssertTrue(recovered)
        XCTAssertEqual(ipcStore.clearShieldSessionCallCount, 1)
        XCTAssertEqual(deviceActivityMonitor.cancelCallCount, 1)
        // …but must not call rescheduleReminder while snooze is active.
        XCTAssertEqual(mockScheduler.rescheduleCallCount, 0,
            "watchdogRecovery must not call rescheduleReminder during an active snooze")
    }

    func test_watchdogRecovery_whenSnoozeExpired_callsRescheduleReminder() async throws {
        // Complement of the above: an expired snooze must not suppress fallback scheduling.
        let mockScheduler = MockReminderScheduler()
        let snoozeCoordinator = AppCoordinator(
            settings: settings,
            scheduler: mockScheduler,
            notificationCenter: notificationCenter,
            overlayManager: MockOverlayPresenting(),
            screenTimeTracker: tracker,
            pauseConditionProvider: MockPauseConditionProvider(),
            deviceActivityMonitor: deviceActivityMonitor,
            ipcStore: ipcStore
        )
        defer { snoozeCoordinator.stopFallbackTimers() }

        deviceActivityMonitor.stubbedIsAvailable = true
        notificationCenter.authorizationGranted = true
        settings.notificationFallbackEnabled = true
        settings.snoozedUntil = Date(timeIntervalSinceNow: -1) // already expired

        ipcStore.shieldSessionSnapshot = ShieldSessionSnapshot(
            reasonRaw: ReminderType.eyes.shieldReason.rawValue,
            durationSeconds: 20,
            triggeredAt: Date(timeIntervalSince1970: 1)
        )

        await snoozeCoordinator.refreshAuthStatus()
        let recovered = await snoozeCoordinator.recoverStaleDeviceActivityWatchdogIfNeeded()
        await awaitCondition { deviceActivityMonitor.cancelCallCount >= 1 }

        XCTAssertTrue(recovered)
        XCTAssertEqual(ipcStore.clearShieldSessionCallCount, 1)
        XCTAssertEqual(deviceActivityMonitor.cancelCallCount, 1)
        XCTAssertEqual(mockScheduler.rescheduleCallCount, 1,
            "watchdogRecovery must call rescheduleReminder when snooze has expired")
    }

    func test_watchdogRecovery_usesInjectedNowForSnoozeGuard() async throws {
        // Injected clock says snooze is still active, while wall clock says expired.
        // Recovery must use the injected time source and skip fallback scheduling.
        let mockScheduler = MockReminderScheduler()
        let snoozeCoordinator = AppCoordinator(
            settings: settings,
            scheduler: mockScheduler,
            notificationCenter: notificationCenter,
            overlayManager: MockOverlayPresenting(),
            screenTimeTracker: tracker,
            pauseConditionProvider: MockPauseConditionProvider(),
            deviceActivityMonitor: deviceActivityMonitor,
            ipcStore: ipcStore
        )
        defer { snoozeCoordinator.stopFallbackTimers() }

        deviceActivityMonitor.stubbedIsAvailable = true
        notificationCenter.authorizationGranted = true
        settings.notificationFallbackEnabled = true
        settings.snoozedUntil = Date(timeIntervalSince1970: 2_000)

        ipcStore.shieldSessionSnapshot = ShieldSessionSnapshot(
            reasonRaw: ReminderType.eyes.shieldReason.rawValue,
            durationSeconds: 20,
            triggeredAt: Date(timeIntervalSince1970: 100)
        )

        await snoozeCoordinator.refreshAuthStatus()
        let recovered = await snoozeCoordinator.recoverStaleDeviceActivityWatchdogIfNeeded(
            now: Date(timeIntervalSince1970: 1_000)
        )
        await awaitCondition { deviceActivityMonitor.cancelCallCount >= 1 }

        XCTAssertTrue(recovered)
        XCTAssertEqual(mockScheduler.rescheduleCallCount, 0,
            "watchdogRecovery must evaluate snooze using injected now, not wall clock")
    }

    private var heartbeatDetails: [WatchdogHeartbeatDetail] {
        ipcStore.events
            .filter { $0.kind == .watchdogHeartbeat }
            .compactMap { event in
                event.detail.flatMap(WatchdogHeartbeatDetail.init(rawValue:))
            }
    }
}

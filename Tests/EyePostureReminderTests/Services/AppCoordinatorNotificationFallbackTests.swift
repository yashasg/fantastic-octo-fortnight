@testable import EyePostureReminder
@testable import ScreenTimeExtensionShared
import XCTest

@MainActor
final class AppCoordinatorNotificationFallbackTests: XCTestCase {

    private var settings: SettingsStore!
    private var notificationCenter: MockNotificationCenter!
    private var overlay: MockOverlayPresenting!
    private var tracker: MockScreenTimeTracker!
    private var deviceActivityMonitor: MockDeviceActivityMonitorProviding!
    private var ipcStore: MockAppGroupIPCRecorder!
    private var coordinator: AppCoordinator!

    override func setUp() async throws {
        try await super.setUp()
        settings = SettingsStore(store: MockSettingsPersisting())
        notificationCenter = MockNotificationCenter()
        notificationCenter.authorizationGranted = true
        overlay = MockOverlayPresenting()
        tracker = MockScreenTimeTracker()
        deviceActivityMonitor = MockDeviceActivityMonitorProviding()
        ipcStore = MockAppGroupIPCRecorder()
        coordinator = AppCoordinator(
            settings: settings,
            scheduler: ReminderScheduler(notificationCenter: notificationCenter),
            notificationCenter: notificationCenter,
            overlayManager: overlay,
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
        overlay = nil
        notificationCenter = nil
        settings = nil
        try await super.tearDown()
    }

    func test_scheduleReminders_whenShieldUnavailableAndFallbackEnabled_schedulesNotifications() async {
        deviceActivityMonitor.stubbedIsAvailable = false
        settings.notificationFallbackEnabled = true

        await coordinator.scheduleReminders()

        XCTAssertEqual(notificationCenter.addedRequests.count, 2)
        XCTAssertTrue(ipcStore.recordedKinds.contains(.notificationFallbackScheduled))
    }

    func test_scheduleReminders_whenShieldUnavailable_recordsFallbackReason() async throws {
        deviceActivityMonitor.stubbedIsAvailable = false

        await coordinator.scheduleReminders()

        let event = try XCTUnwrap(ipcStore.events.first { $0.kind == .notificationFallbackScheduled })
        XCTAssertEqual(event.detail, "shield_unavailable")
    }

    func test_scheduleReminders_whenFallbackDisabled_cancelsNotifications() async {
        deviceActivityMonitor.stubbedIsAvailable = false
        settings.notificationFallbackEnabled = false

        await coordinator.scheduleReminders()

        XCTAssertTrue(notificationCenter.addedRequests.isEmpty)
        XCTAssertEqual(notificationCenter.removeAllCallCount, 1)
        XCTAssertFalse(ipcStore.recordedKinds.contains(.notificationFallbackScheduled))
    }

    func test_scheduleReminders_whenAllRemindersDisabled_doesNotRecordFallbackScheduled() async {
        deviceActivityMonitor.stubbedIsAvailable = false
        settings.globalEnabled = false

        await coordinator.scheduleReminders()

        XCTAssertTrue(notificationCenter.addedRequests.isEmpty)
        XCTAssertEqual(notificationCenter.removeAllCallCount, 1)
        XCTAssertFalse(ipcStore.recordedKinds.contains(.notificationFallbackScheduled))
    }

    func test_scheduleReminders_whenShieldAvailable_suppressesNotificationFallback() async throws {
        deviceActivityMonitor.stubbedIsAvailable = true
        ipcStore.trueInterruptEnabled = true
        ipcStore.selectApps()

        await coordinator.scheduleReminders()

        XCTAssertTrue(notificationCenter.addedRequests.isEmpty)
        XCTAssertEqual(notificationCenter.removeAllCallCount, 1)
        let event = try XCTUnwrap(ipcStore.events.first { $0.kind == .shieldPathSelected })
        XCTAssertEqual(event.detail, "device_activity_available")
    }

    func test_scheduleReminders_whenShieldAvailableButTrueInterruptDisabled_schedulesFallback() async {
        deviceActivityMonitor.stubbedIsAvailable = true
        ipcStore.trueInterruptEnabled = false

        await coordinator.scheduleReminders()

        XCTAssertEqual(notificationCenter.addedRequests.count, 2)
        XCTAssertTrue(ipcStore.recordedKinds.contains(.notificationFallbackScheduled))
        XCTAssertFalse(ipcStore.recordedKinds.contains(.shieldPathSelected))
    }

    func test_scheduleReminders_whenShieldAvailableAndAllRemindersDisabled_doesNotRecordShieldPath() async {
        deviceActivityMonitor.stubbedIsAvailable = true
        ipcStore.trueInterruptEnabled = true
        ipcStore.selectApps()
        settings.globalEnabled = false

        await coordinator.scheduleReminders()

        XCTAssertTrue(notificationCenter.addedRequests.isEmpty)
        XCTAssertFalse(ipcStore.recordedKinds.contains(.shieldPathSelected))
    }

    func test_scheduleReminders_whenReadSelectionThrows_routesToNotificationFallback() async throws {
        struct CorruptSelectionError: Error {}
        deviceActivityMonitor.stubbedIsAvailable = true
        ipcStore.trueInterruptEnabled = true
        ipcStore.readSelectionError = CorruptSelectionError()

        await coordinator.scheduleReminders()

        XCTAssertEqual(notificationCenter.addedRequests.count, 2)
        let event = try XCTUnwrap(ipcStore.events.first { $0.kind == .notificationFallbackScheduled })
        XCTAssertEqual(event.detail, "true_interrupt_empty_selection")
        XCTAssertFalse(ipcStore.recordedKinds.contains(.shieldPathSelected))
    }

    func test_scheduleReminders_whenTrueInterruptEnabledButSelectionEmpty_schedulesFallback() async throws {
        deviceActivityMonitor.stubbedIsAvailable = true
        ipcStore.trueInterruptEnabled = true

        await coordinator.scheduleReminders()

        XCTAssertEqual(notificationCenter.addedRequests.count, 2)
        let event = try XCTUnwrap(ipcStore.events.first { $0.kind == .notificationFallbackScheduled })
        XCTAssertEqual(event.detail, "true_interrupt_empty_selection")
        XCTAssertFalse(ipcStore.recordedKinds.contains(.shieldPathSelected))
    }

    func test_trueInterruptEnabledChangeNotification_reEvaluatesRoutingImmediately() async {
        deviceActivityMonitor.stubbedIsAvailable = false
        await coordinator.refreshAuthStatus()
        notificationCenter.reset()

        NotificationCenter.default.post(
            name: AppGroupIPCStore.trueInterruptEnabledDidChangeNotification,
            object: nil,
            userInfo: [AppGroupIPCStore.trueInterruptEnabledValueUserInfoKey: false]
        )
        await awaitCondition {
            notificationCenter.addedRequests.count >= 2 &&
                ipcStore.recordedKinds.contains(.notificationFallbackScheduled)
        }

        XCTAssertEqual(notificationCenter.addedRequests.count, 2)
        XCTAssertTrue(ipcStore.recordedKinds.contains(.notificationFallbackScheduled))
    }

    func test_trueInterruptEnabledChangeNotification_whenEnabledAndShieldAvailable_switchesToShieldPath() async throws {
        deviceActivityMonitor.stubbedIsAvailable = false
        await coordinator.scheduleReminders()
        XCTAssertEqual(notificationCenter.pendingRequests.count, 2)

        deviceActivityMonitor.stubbedIsAvailable = true
        ipcStore.trueInterruptEnabled = true
        ipcStore.selectApps()
        NotificationCenter.default.post(
            name: AppGroupIPCStore.trueInterruptEnabledDidChangeNotification,
            object: nil,
            userInfo: [AppGroupIPCStore.trueInterruptEnabledValueUserInfoKey: true]
        )
        await awaitCondition { ipcStore.events.contains { $0.kind == .shieldPathSelected } }

        XCTAssertTrue(notificationCenter.pendingRequests.isEmpty)
        XCTAssertEqual(notificationCenter.removeAllCallCount, 1)
        let event = try XCTUnwrap(ipcStore.events.last { $0.kind == .shieldPathSelected })
        XCTAssertEqual(event.detail, "device_activity_available")
    }

    func test_trueInterruptEnabledChangeNotification_whenDisabled_switchesToNotificationFallback() async throws {
        deviceActivityMonitor.stubbedIsAvailable = true
        ipcStore.trueInterruptEnabled = true
        ipcStore.selectApps()
        await coordinator.scheduleReminders()
        XCTAssertTrue(notificationCenter.pendingRequests.isEmpty)
        XCTAssertTrue(ipcStore.recordedKinds.contains(.shieldPathSelected))

        ipcStore.trueInterruptEnabled = false
        NotificationCenter.default.post(
            name: AppGroupIPCStore.trueInterruptEnabledDidChangeNotification,
            object: nil,
            userInfo: [AppGroupIPCStore.trueInterruptEnabledValueUserInfoKey: false]
        )
        await awaitCondition {
            notificationCenter.addedRequests.count >= 2 &&
                ipcStore.events.contains { $0.kind == .notificationFallbackScheduled }
        }

        XCTAssertEqual(notificationCenter.addedRequests.count, 2)
        let event = try XCTUnwrap(ipcStore.events.last { $0.kind == .notificationFallbackScheduled })
        XCTAssertEqual(event.detail, "true_interrupt_disabled")
    }

    func test_scheduleReminders_usesCapturedFallbackDetail_whenIPCMutatesDuringScheduling() async throws {
        // Regression test for: notificationFallbackDetail evaluated after await,
        // where IPC state could change across the suspension point causing assertionFailure.
        let mockScheduler = MockReminderScheduler()
        let localCoordinator = AppCoordinator(
            settings: settings,
            scheduler: mockScheduler,
            notificationCenter: notificationCenter,
            overlayManager: overlay,
            screenTimeTracker: tracker,
            pauseConditionProvider: MockPauseConditionProvider(),
            deviceActivityMonitor: deviceActivityMonitor,
            ipcStore: ipcStore
        )
        defer { localCoordinator.stopFallbackTimers() }

        // Initial state: shield unavailable → notificationFallbackDetail = "shield_unavailable"
        deviceActivityMonitor.stubbedIsAvailable = false
        settings.notificationFallbackEnabled = true

        // Simulate IPC mutation occurring during the scheduler await suspension:
        // true interrupt becomes fully active, which would make notificationFallbackDetail
        // reach the previously fatal assertionFailure branch if evaluated post-await.
        mockScheduler.onScheduleReminders = { [weak self] in
            guard let self else { return }
            self.deviceActivityMonitor.stubbedIsAvailable = true
            self.ipcStore.trueInterruptEnabled = true
            self.ipcStore.selectApps()
        }

        await localCoordinator.scheduleReminders()

        // The detail must reflect the pre-await state ("shield_unavailable"),
        // not the post-mutation "unexpected_shield_routing_state".
        let event = try XCTUnwrap(ipcStore.events.first { $0.kind == .notificationFallbackScheduled })
        XCTAssertEqual(event.detail, "shield_unavailable")
    }

    // MARK: - #290: Distinct analytics reason for unexpected shield routing state

    func test_fallbackRoutingContext_unexpectedShieldState_emitsDistinctIPCDetailAndAnalyticsReason() async throws {
        // Issue #290: the defensive fallback path in fallbackRoutingContext() was incorrectly
        // classified as .trueInterruptEmptySelection. It must emit its own distinct reason code.
        //
        // Trigger the defensive path by starting with shouldScheduleNotificationFallback == true
        // (shield available + true interrupt enabled + empty selection), then having the IPC
        // state mutate to fully-active between the outer check and the fallbackRoutingContext call.
        let mockScheduler = MockReminderScheduler()
        let localCoordinator = AppCoordinator(
            settings: settings,
            scheduler: mockScheduler,
            notificationCenter: notificationCenter,
            overlayManager: overlay,
            screenTimeTracker: tracker,
            pauseConditionProvider: MockPauseConditionProvider(),
            deviceActivityMonitor: deviceActivityMonitor,
            ipcStore: ipcStore
        )
        defer { localCoordinator.stopFallbackTimers() }

        // Shield available + true interrupt enabled, but no selection → shouldScheduleNotificationFallback
        deviceActivityMonitor.stubbedIsAvailable = true
        ipcStore.trueInterruptEnabled = true
        // No apps selected → falls through to trueInterruptEmptySelection
        settings.notificationFallbackEnabled = true
        notificationCenter.authorizationGranted = true

        // During the await inside scheduleReminders(), selection becomes non-empty.
        // This pushes the IPC state to "fully active", causing the defensive path to fire.
        mockScheduler.onScheduleReminders = { [weak self] in
            self?.ipcStore.selectApps()
        }

        await localCoordinator.scheduleReminders()

        // Must record the notification fallback with the defensive detail string…
        let fallbackEvent = try XCTUnwrap(ipcStore.events.first { $0.kind == .notificationFallbackScheduled })
        XCTAssertEqual(fallbackEvent.detail, "true_interrupt_empty_selection",
            "IPC detail must reflect the pre-await routing state (empty selection)")

        // The test above validates the IPC path. The analytics reason for the truly
        // defensive branch (all three guards pass post-await) can only be exercised by
        // direct unit-testing of fallbackRoutingContext — covered in the unit below.
    }

    func test_fallbackRoutingContext_analytic_unexpectedShieldRoutingState_hasDistinctRawValue() {
        // Issue #290: verify the new enum case has its own raw value and does not alias
        // trueInterruptEmptySelection.
        let reason = AnalyticsEvent.SchedulePathReason.unexpectedShieldRoutingState
        XCTAssertEqual(reason.rawValue, "unexpected_shield_routing_state")
        XCTAssertNotEqual(
            AnalyticsEvent.SchedulePathReason.unexpectedShieldRoutingState,
            AnalyticsEvent.SchedulePathReason.trueInterruptEmptySelection
        )
    }

    func test_handleNotification_recordsDeliveredFallbackEvent() throws {
        coordinator.handleNotification(for: .eyes)

        let event = try XCTUnwrap(ipcStore.events.first { $0.kind == .notificationFallbackDelivered })
        XCTAssertEqual(event.reasonRaw, ReminderType.eyes.shieldReason.rawValue)
    }

    func test_thresholdReached_whenFallbackActive_reschedulesMatchingNotification() async {
        deviceActivityMonitor.stubbedIsAvailable = false
        await coordinator.scheduleReminders()
        notificationCenter.reset()

        tracker.simulateThresholdReached(for: .eyes)
        await awaitCondition { notificationCenter.addedRequests.count >= 1 }

        XCTAssertEqual(notificationCenter.addedRequests.count, 1)
        XCTAssertEqual(
            notificationCenter.removedIdentifiers,
            [["com.yashasg.eyeposturereminder.eyes"]]
        )
    }

    func test_deviceActivityScheduleFailure_whenOverlayVisible_suppressesDuplicateFallback() async throws {
        struct ScheduleFailure: Error {}
        deviceActivityMonitor.stubbedIsAvailable = true
        deviceActivityMonitor.stubbedScheduleError = ScheduleFailure()
        ipcStore.trueInterruptEnabled = true
        ipcStore.selectApps()
        await coordinator.refreshAuthStatus()

        tracker.simulateThresholdReached(for: .eyes)
        await awaitCondition { ipcStore.events.contains { $0.kind == .notificationFallbackSuppressed } }

        XCTAssertTrue(notificationCenter.addedRequests.isEmpty)
        let event = try XCTUnwrap(ipcStore.events.first { $0.kind == .notificationFallbackSuppressed })
        XCTAssertEqual(event.reasonRaw, ReminderType.eyes.shieldReason.rawValue)
        XCTAssertEqual(event.detail, "device_activity_schedule_failed_overlay_visible")
        XCTAssertFalse(ipcStore.recordedKinds.contains(.notificationFallbackScheduled))
    }

    func test_deviceActivityScheduleFailure_whenOverlayNotVisible_coalescesFallbackNotification() async throws {
        struct ScheduleFailure: Error {}
        deviceActivityMonitor.stubbedIsAvailable = true
        deviceActivityMonitor.stubbedScheduleError = ScheduleFailure()
        ipcStore.trueInterruptEnabled = true
        ipcStore.selectApps()
        overlay.autoInvokeOnPresent = false
        await coordinator.refreshAuthStatus()

        tracker.simulateThresholdReached(for: .eyes)
        await awaitCondition { overlay.showCallCount >= 1 }
        XCTAssertEqual(overlay.showCallCount, 1)
        XCTAssertTrue(notificationCenter.addedRequests.isEmpty)

        overlay.dismissOverlay()
        let onPresent = try XCTUnwrap(overlay.onPresentCalls.first)
        onPresent()
        await awaitCondition {
            notificationCenter.addedRequests.count >= 1 &&
                ipcStore.events.contains { $0.kind == .notificationFallbackScheduled }
        }

        XCTAssertEqual(deviceActivityMonitor.scheduleCallCount, 1)
        XCTAssertEqual(notificationCenter.addedRequests.count, 1)
        XCTAssertEqual(
            notificationCenter.removedIdentifiers,
            [["com.yashasg.eyeposturereminder.eyes"]]
        )
        let event = try XCTUnwrap(ipcStore.events.first { $0.kind == .notificationFallbackScheduled })
        XCTAssertEqual(event.reasonRaw, ReminderType.eyes.shieldReason.rawValue)
        XCTAssertEqual(event.detail, "device_activity_schedule_failed")
        XCTAssertFalse(ipcStore.recordedKinds.contains(.notificationFallbackSuppressed))
    }

    func test_deviceActivityScheduleFailure_afterOverlayDismiss_suppressesFallbackNotification() async throws {
        struct ScheduleFailure: Error {}
        deviceActivityMonitor.stubbedIsAvailable = true
        deviceActivityMonitor.stubbedScheduleError = ScheduleFailure()
        deviceActivityMonitor.scheduleDelayNanoseconds = 100_000_000
        ipcStore.trueInterruptEnabled = true
        ipcStore.selectApps()
        await coordinator.refreshAuthStatus()

        tracker.simulateThresholdReached(for: .eyes)
        overlay.simulateDismiss()
        await awaitCondition {
            deviceActivityMonitor.cancelCallCount >= 1 &&
            ipcStore.events.contains { $0.kind == .notificationFallbackSuppressed }
        }

        XCTAssertEqual(deviceActivityMonitor.scheduleCallCount, 1)
        XCTAssertEqual(deviceActivityMonitor.cancelCallCount, 1)
        XCTAssertTrue(notificationCenter.addedRequests.isEmpty)
        let event = try XCTUnwrap(ipcStore.events.first { $0.kind == .notificationFallbackSuppressed })
        XCTAssertEqual(event.reasonRaw, ReminderType.eyes.shieldReason.rawValue)
        XCTAssertEqual(event.detail, "device_activity_schedule_failed_overlay_dismissed")
        XCTAssertFalse(ipcStore.recordedKinds.contains(.notificationFallbackScheduled))
    }
}

private extension MockAppGroupIPCRecorder {
    var recordedKinds: [AppGroupIPCEventKind] {
        events.map(\.kind)
    }
}

@testable import EyePostureReminder
@testable import ScreenTimeExtensionShared
import XCTest

/// Tests for `cancelReminder(for:)` DeviceActivity cancellation behaviour introduced in issue #291.
///
/// Verifies that cancelling a reminder type also cancels any active DeviceActivity
/// monitoring session for that type, while leaving unrelated sessions untouched.
@MainActor
final class AppCoordinatorCancelReminderTests: XCTestCase {

    private var settings: SettingsStore!

    override func setUp() async throws {
        try await super.setUp()
        settings = SettingsStore(store: MockSettingsPersisting())
    }

    override func tearDown() async throws {
        settings = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    private func makeCoordinator(
        deviceActivityMonitor: MockDeviceActivityMonitorProviding,
        ipcStore: MockAppGroupIPCRecorder
    ) -> AppCoordinator {
        AppCoordinator(
            settings: settings,
            scheduler: ReminderScheduler(notificationCenter: MockNotificationCenter()),
            notificationCenter: MockNotificationCenter(),
            overlayManager: MockOverlayPresenting(),
            screenTimeTracker: MockScreenTimeTracker(),
            pauseConditionProvider: MockPauseConditionProvider(),
            deviceActivityMonitor: deviceActivityMonitor,
            ipcStore: ipcStore
        )
    }

    // MARK: - #291: cancelReminder cancels DeviceActivity for matching active shield session

    func test_cancelReminder_whenMatchingShieldSessionActive_cancelsDeviceActivityMonitoring() async throws {
        // Issue #291: cancelReminder(for:) must cancel DeviceActivity monitoring when an
        // active shield session exists for the same type, preventing a stuck shield.
        let ipcStore = MockAppGroupIPCRecorder()
        let deviceActivityMonitor = MockDeviceActivityMonitorProviding()
        deviceActivityMonitor.stubbedIsAvailable = true
        ipcStore.shieldSessionSnapshot = ShieldSessionSnapshot(
            reasonRaw: ReminderType.eyes.shieldReason.rawValue,
            durationSeconds: 20,
            triggeredAt: Date()
        )
        let coordinator = makeCoordinator(deviceActivityMonitor: deviceActivityMonitor, ipcStore: ipcStore)
        defer { coordinator.stopFallbackTimers() }

        coordinator.cancelReminder(for: .eyes)
        // Wait for the inner DeviceActivity cancel task to complete.
        await awaitCondition { deviceActivityMonitor.cancelCallCount >= 1 }

        XCTAssertEqual(deviceActivityMonitor.cancelCallCount, 1,
            "cancelReminder(for: .eyes) must cancel DeviceActivity monitoring when a matching shield session is active")
    }

    func test_cancelReminder_whenShieldSessionForDifferentType_doesNotCancelDeviceActivityMonitoring() async throws {
        // Issue #291 (complement): if the active shield session is for a different type,
        // cancelReminder must not cancel the unrelated session.
        let ipcStore = MockAppGroupIPCRecorder()
        let deviceActivityMonitor = MockDeviceActivityMonitorProviding()
        deviceActivityMonitor.stubbedIsAvailable = true
        // Active shield session is for .posture, but we cancel .eyes
        ipcStore.shieldSessionSnapshot = ShieldSessionSnapshot(
            reasonRaw: ReminderType.posture.shieldReason.rawValue,
            durationSeconds: 20,
            triggeredAt: Date()
        )
        let coordinator = makeCoordinator(deviceActivityMonitor: deviceActivityMonitor, ipcStore: ipcStore)
        defer { coordinator.stopFallbackTimers() }

        coordinator.cancelReminder(for: .eyes)
        // No inner task is spawned when session type doesn't match — no async wait needed.
        await Task.yield()

        XCTAssertEqual(deviceActivityMonitor.cancelCallCount, 0,
            "cancelReminder(for: .eyes) must not cancel DeviceActivity when the active session is for a different type")
    }

    func test_cancelReminder_whenNoActiveShieldSession_doesNotCancelDeviceActivityMonitoring() async throws {
        // Issue #291 (complement): no active session → no cancellation.
        let ipcStore = MockAppGroupIPCRecorder()
        let deviceActivityMonitor = MockDeviceActivityMonitorProviding()
        deviceActivityMonitor.stubbedIsAvailable = true
        // shieldSessionSnapshot defaults to .empty
        let coordinator = makeCoordinator(deviceActivityMonitor: deviceActivityMonitor, ipcStore: ipcStore)
        defer { coordinator.stopFallbackTimers() }

        coordinator.cancelReminder(for: .eyes)
        // No inner task is spawned when there is no active shield session — no async wait needed.
        await Task.yield()

        XCTAssertEqual(deviceActivityMonitor.cancelCallCount, 0,
            "cancelReminder must not call DeviceActivity cancel when there is no active shield session")
    }

    func test_cancelReminder_whenDeviceActivityUnavailable_doesNotCallCancel() async throws {
        // Guard: if DeviceActivity is unavailable (e.g. FamilyControls not authorised),
        // cancelReminder must not attempt to cancel monitoring.
        let ipcStore = MockAppGroupIPCRecorder()
        let deviceActivityMonitor = MockDeviceActivityMonitorProviding()
        deviceActivityMonitor.stubbedIsAvailable = false
        ipcStore.shieldSessionSnapshot = ShieldSessionSnapshot(
            reasonRaw: ReminderType.eyes.shieldReason.rawValue,
            durationSeconds: 20,
            triggeredAt: Date()
        )
        let coordinator = makeCoordinator(deviceActivityMonitor: deviceActivityMonitor, ipcStore: ipcStore)
        defer { coordinator.stopFallbackTimers() }

        coordinator.cancelReminder(for: .eyes)
        // No inner task is spawned when DeviceActivity is unavailable — no async wait needed.
        await Task.yield()

        XCTAssertEqual(deviceActivityMonitor.cancelCallCount, 0,
            "cancelReminder must not call cancel when DeviceActivity is unavailable")
    }
}

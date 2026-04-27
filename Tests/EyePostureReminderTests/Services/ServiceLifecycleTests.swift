@testable import EyePostureReminder
import XCTest

/// Tests for `ServiceLifecycle` protocol conformance.
///
/// Verifies that all known implementors of `ServiceLifecycle` (and its
/// sub-protocols `ScreenTimeTracking` and `PauseConditionProviding`)
/// conform correctly and can be used polymorphically via the protocol.
final class ServiceLifecycleTests: XCTestCase {

    // MARK: - Mock Conformance (ScreenTimeTracking → ServiceLifecycle)

    /// MockScreenTimeTracker conforms to ScreenTimeTracking (which extends ServiceLifecycle).
    @MainActor
    func test_mockScreenTimeTracker_conformsToServiceLifecycle() {
        let tracker: any ServiceLifecycle = MockScreenTimeTracker()
        tracker.startMonitoring()
        tracker.stopMonitoring()
    }

    /// MockScreenTimeTracker records startMonitoring calls.
    @MainActor
    func test_mockScreenTimeTracker_startMonitoring_incrementsCallCount() {
        let tracker = MockScreenTimeTracker()
        XCTAssertEqual(tracker.startMonitoringCallCount, 0)
        tracker.startMonitoring()
        XCTAssertEqual(tracker.startMonitoringCallCount, 1)
        tracker.startMonitoring()
        XCTAssertEqual(tracker.startMonitoringCallCount, 2)
    }

    /// MockScreenTimeTracker records stopMonitoring calls.
    @MainActor
    func test_mockScreenTimeTracker_stopMonitoring_incrementsCallCount() {
        let tracker = MockScreenTimeTracker()
        XCTAssertEqual(tracker.stopMonitoringCallCount, 0)
        tracker.stopMonitoring()
        XCTAssertEqual(tracker.stopMonitoringCallCount, 1)
    }

    // MARK: - Mock Conformance (PauseConditionProviding → ServiceLifecycle)

    /// MockPauseConditionProvider conforms to PauseConditionProviding (which extends ServiceLifecycle).
    @MainActor
    func test_mockPauseConditionProvider_conformsToServiceLifecycle() {
        let provider: any ServiceLifecycle = MockPauseConditionProvider()
        provider.startMonitoring()
        provider.stopMonitoring()
    }

    /// MockPauseConditionProvider records startMonitoring calls.
    @MainActor
    func test_mockPauseConditionProvider_startMonitoring_incrementsCallCount() {
        let provider = MockPauseConditionProvider()
        XCTAssertEqual(provider.startMonitoringCallCount, 0)
        provider.startMonitoring()
        XCTAssertEqual(provider.startMonitoringCallCount, 1)
    }

    /// MockPauseConditionProvider records stopMonitoring calls.
    @MainActor
    func test_mockPauseConditionProvider_stopMonitoring_incrementsCallCount() {
        let provider = MockPauseConditionProvider()
        XCTAssertEqual(provider.stopMonitoringCallCount, 0)
        provider.stopMonitoring()
        XCTAssertEqual(provider.stopMonitoringCallCount, 1)
    }

    // MARK: - Noop Conformance (NoopScreenTimeTracker → ServiceLifecycle)

    /// NoopScreenTimeTracker conforms to ServiceLifecycle via ScreenTimeTracking.
    @MainActor
    func test_noopScreenTimeTracker_conformsToServiceLifecycle() {
        let tracker: any ServiceLifecycle = NoopScreenTimeTracker()
        tracker.startMonitoring()
        tracker.stopMonitoring()
    }

    /// NoopScreenTimeTracker start/stop are no-ops (don't crash).
    @MainActor
    func test_noopScreenTimeTracker_startStop_areNoOps() {
        let tracker = NoopScreenTimeTracker()
        tracker.startMonitoring()
        tracker.stopMonitoring()
        tracker.startMonitoring()
        tracker.stopMonitoring()
    }

    // MARK: - Noop Conformance (NoopPauseConditionManager → ServiceLifecycle)

    /// NoopPauseConditionManager conforms to ServiceLifecycle via PauseConditionProviding.
    @MainActor
    func test_noopPauseConditionManager_conformsToServiceLifecycle() {
        let manager: any ServiceLifecycle = NoopPauseConditionManager()
        manager.startMonitoring()
        manager.stopMonitoring()
    }

    /// NoopPauseConditionManager.isPaused is always false.
    @MainActor
    func test_noopPauseConditionManager_isPaused_isFalse() {
        let manager = NoopPauseConditionManager()
        XCTAssertFalse(manager.isPaused,
                       "NoopPauseConditionManager.isPaused must always be false")
    }

    /// NoopPauseConditionManager start/stop are no-ops (don't crash).
    @MainActor
    func test_noopPauseConditionManager_startStop_areNoOps() {
        let manager = NoopPauseConditionManager()
        manager.startMonitoring()
        manager.stopMonitoring()
    }

    // MARK: - Polymorphic Usage

    /// An array of ServiceLifecycle implementors can be uniformly started/stopped.
    @MainActor
    func test_serviceLifecycle_polymorphicArray_canBeUniformlyControlled() {
        let services: [any ServiceLifecycle] = [
            MockScreenTimeTracker(),
            MockPauseConditionProvider(),
            NoopScreenTimeTracker(),
            NoopPauseConditionManager()
        ]

        for service in services {
            service.startMonitoring()
        }

        for service in services {
            service.stopMonitoring()
        }
        // All services started and stopped without crash — polymorphism works.
    }
}

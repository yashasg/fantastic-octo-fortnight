import Foundation

@testable import EyePostureReminder

/// Mock implementation of `PauseConditionProviding` for use in
/// `SchedulingFeature*Tests`. Lets tests control pause-condition state
/// without real Focus mode, CarPlay, or driving-detection logic
/// (#755 Phase E).
@MainActor
final class MockPauseConditionProvider: PauseConditionProviding {

    var onPauseStateChanged: (@MainActor (Bool) -> Void)?

    private(set) var isPaused: Bool = false

    // MARK: - Recorded Calls

    private(set) var startMonitoringCallCount = 0
    private(set) var stopMonitoringCallCount = 0

    // MARK: - PauseConditionProviding

    func startMonitoring() {
        startMonitoringCallCount += 1
    }

    func stopMonitoring() {
        stopMonitoringCallCount += 1
    }

    // MARK: - Simulation Helpers

    /// Simulate a pause-state change from any condition.
    func simulatePauseStateChange(_ paused: Bool) {
        isPaused = paused
        onPauseStateChanged?(paused)
    }
}

@testable import EyePostureReminder
import Foundation

/// Mock implementation of `ScreenTimeTracking` for use in `AppCoordinatorTests`
/// and any test that needs to control or observe screen-time tracking behaviour
/// without spinning up real `Timer`s or UIApplication lifecycle observers.
final class MockScreenTimeTracker: ScreenTimeTracking {

    var onThresholdReached: ((ReminderType) -> Void)?

    // MARK: - Recorded Calls

    private(set) var setThresholdCalls: [(interval: TimeInterval, type: ReminderType)] = []
    private(set) var disableTrackingCalls: [ReminderType] = []
    private(set) var pauseCalls: [ReminderType] = []
    private(set) var resumeCalls: [ReminderType] = []
    private(set) var pauseAllCallCount = 0
    private(set) var resumeAllCallCount = 0
    private(set) var resetCalls: [ReminderType] = []
    private(set) var resetAllCallCount = 0
    private(set) var startIfActiveCallCount = 0
    private(set) var stopCallCount = 0

    // MARK: - ScreenTimeTracking

    func setThreshold(_ interval: TimeInterval, for type: ReminderType) {
        setThresholdCalls.append((interval, type))
    }

    func disableTracking(for type: ReminderType) {
        disableTrackingCalls.append(type)
    }

    func pause(for type: ReminderType) {
        pauseCalls.append(type)
    }

    func resume(for type: ReminderType) {
        resumeCalls.append(type)
    }

    func pauseAll() {
        pauseAllCallCount += 1
    }

    func resumeAll() {
        resumeAllCallCount += 1
    }

    func reset(for type: ReminderType) {
        resetCalls.append(type)
    }

    func resetAll() {
        resetAllCallCount += 1
    }

    func startIfActive() {
        startIfActiveCallCount += 1
    }

    func stop() {
        stopCallCount += 1
    }

    // MARK: - Simulation Helpers

    /// Simulate a threshold being reached for the given type.
    func simulateThresholdReached(for type: ReminderType) {
        onThresholdReached?(type)
    }
}

// Lightweight no-op stubs injected by AppCoordinator in UI test mode.
// They satisfy the ScreenTimeTracking / PauseConditionProviding protocols
// without registering UIKit lifecycle observers or starting repeating timers,
// which would otherwise fire on the main thread every second and prevent
// XCUITest from settling the accessibility tree between interactions.

import Foundation

// MARK: - NoopScreenTimeTracker

@MainActor
final class NoopScreenTimeTracker: ScreenTimeTracking {
    var onThresholdReached: (@MainActor (ReminderType) -> Void)?
    func setThreshold(_ interval: TimeInterval, for type: ReminderType) {}
    func disableTracking(for type: ReminderType) {}
    func pause(for type: ReminderType) {}
    func resume(for type: ReminderType) {}
    func pauseAll() {}
    func resumeAll() {}
    func reset(for type: ReminderType) {}
    func resetAll() {}
    func startIfActive() {}
    func stop() {}
    func startMonitoring() {}
    func stopMonitoring() {}
}

// MARK: - NoopPauseConditionManager

@MainActor
final class NoopPauseConditionManager: PauseConditionProviding {
    var isPaused: Bool { false }
    var onPauseStateChanged: (@MainActor (Bool) -> Void)?
    func startMonitoring() {}
    func stopMonitoring() {}
}

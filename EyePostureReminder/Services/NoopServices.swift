// Lightweight no-op stubs injected by AppCoordinator in UI test mode.
// They satisfy the ScreenTimeTracking / PauseConditionProviding protocols
// without registering UIKit lifecycle observers or starting repeating timers,
// which would otherwise fire on the main thread every second and prevent
// XCUITest from settling the accessibility tree between interactions.

import Foundation

// MARK: - NoopScreenTimeTracker

/// Inert `ScreenTimeTracking` used only when the app is launched in UI-test mode.
///
/// Replaces the live tracker so XCUITest runs do not spin up the per-second
/// timers and lifecycle observers used by `ScreenTimeTracker`, which would
/// otherwise prevent the accessibility tree from settling between interactions.
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

/// Inert `PauseConditionProviding` used only when the app is launched in UI-test mode.
///
/// Always reports `isPaused == false` and never invokes `onPauseStateChanged`,
/// so UI tests observe a deterministic, never-paused state regardless of
/// device focus modes, CarPlay, or other live pause sources.
@MainActor
final class NoopPauseConditionManager: PauseConditionProviding {
    var isPaused: Bool { false }
    var onPauseStateChanged: (@MainActor (Bool) -> Void)?
    func startMonitoring() {}
    func stopMonitoring() {}
}

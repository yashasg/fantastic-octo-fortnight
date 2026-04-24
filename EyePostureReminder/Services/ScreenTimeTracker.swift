import UIKit
import os

/// Tracks continuous screen-on time per `ReminderType` and fires a callback
/// when a type's threshold is reached.
///
/// **Screen-time semantics:** The elapsed counter for each type increments
/// only while the app is active. When the app resigns active (screen off,
/// backgrounded, or interrupted), all counters reset to zero so the user must
/// accumulate the full threshold of unbroken screen time before the next reminder.
///
/// **Lifecycle:**
/// - `UIApplication.didBecomeActiveNotification`  → starts the 1-second tick timer.
/// - `UIApplication.willResignActiveNotification` → stops the timer and resets all counters.
///
/// Call `startIfActive()` after configuring thresholds if the app is already in
/// the foreground (e.g., on `scheduleReminders()` with the app open) so the
/// tracker begins counting without waiting for the next lifecycle event.
///
/// All methods must be called on the main thread (owned by `@MainActor AppCoordinator`).
final class ScreenTimeTracker {

    typealias ThresholdCallback = (ReminderType) -> Void

    // MARK: - State

    private var elapsed: [ReminderType: TimeInterval] = [:]
    private var thresholds: [ReminderType: TimeInterval] = [:]
    private var paused: Set<ReminderType> = []
    private var tickTimer: Timer?

    // MARK: - Callback

    /// Called on the main thread when a type's elapsed screen time reaches its threshold.
    /// The counter is reset to 0 before the callback fires.
    var onThresholdReached: ThresholdCallback?

    // MARK: - Init

    init() {
        for type in ReminderType.allCases {
            elapsed[type] = 0
        }
        registerLifecycleObservers()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        tickTimer?.invalidate()
    }

    // MARK: - Configuration

    /// Set the threshold (seconds of continuous screen-on time) for a reminder type.
    /// Resets the elapsed counter for the type.
    func setThreshold(_ interval: TimeInterval, for type: ReminderType) {
        thresholds[type] = interval
        elapsed[type] = 0
    }

    /// Remove the threshold and reset the elapsed counter for a type.
    /// The type will no longer fire callbacks until a new threshold is set.
    func disableTracking(for type: ReminderType) {
        thresholds.removeValue(forKey: type)
        elapsed[type] = 0
    }

    // MARK: - Snooze Support

    /// Pause a type's tracking. Resets its elapsed counter to 0.
    /// The tick timer keeps running but this type's counter is not incremented.
    func pause(for type: ReminderType) {
        paused.insert(type)
        elapsed[type] = 0
    }

    /// Resume tracking for a previously paused type.
    func resume(for type: ReminderType) {
        paused.remove(type)
    }

    /// Pause all reminder types.
    func pauseAll() {
        for type in ReminderType.allCases {
            pause(for: type)
        }
    }

    /// Resume tracking for all reminder types.
    func resumeAll() {
        paused.removeAll()
    }

    // MARK: - Manual Reset

    func reset(for type: ReminderType) {
        elapsed[type] = 0
    }

    func resetAll() {
        for type in ReminderType.allCases {
            elapsed[type] = 0
        }
    }

    // MARK: - Start / Stop

    /// Start the tick timer if the app is currently active.
    ///
    /// Call this after configuring thresholds when the app is already in the
    /// foreground — `didBecomeActiveNotification` won't fire again until the
    /// next lifecycle cycle, so this ensures counting begins immediately.
    func startIfActive() {
        if UIApplication.shared.applicationState == .active {
            startTicking()
        }
    }

    /// Stop the tick timer and reset all elapsed counters.
    /// Use for cleanup (e.g., test `tearDown`) or when reminders are permanently disabled.
    func stop() {
        stopTicking()
        resetAll()
        Logger.scheduling.debug("ScreenTimeTracker: stopped and reset")
    }

    // MARK: - Private: Lifecycle Observers

    private func registerLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }

    @objc private func handleDidBecomeActive() {
        startTicking()
    }

    @objc private func handleWillResignActive() {
        stopTicking()
        resetAll()
        Logger.scheduling.debug("ScreenTimeTracker: screen off — all counters reset to 0")
    }

    // MARK: - Private: Tick Timer

    private func startTicking() {
        guard tickTimer == nil else { return }
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        Logger.scheduling.debug("ScreenTimeTracker: started ticking")
    }

    private func stopTicking() {
        tickTimer?.invalidate()
        tickTimer = nil
    }

    private func tick() {
        for type in ReminderType.allCases {
            guard !paused.contains(type), let threshold = thresholds[type], threshold > 0 else { continue }
            elapsed[type, default: 0] += 1.0
            if elapsed[type, default: 0] >= threshold {
                elapsed[type] = 0
                Logger.scheduling.info("ScreenTimeTracker: \(type.rawValue) threshold reached (\(threshold)s continuous screen-on time)")
                onThresholdReached?(type)
            }
        }
    }
}

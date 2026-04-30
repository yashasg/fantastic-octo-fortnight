import os
import UIKit

/// Tracks continuous screen-on time per `ReminderType` and fires a callback
/// when a type's threshold is reached.
///
/// **Screen-time semantics:** The elapsed counter for each type increments
/// only while the app is active. When the app resigns active (screen off,
/// backgrounded, or interrupted), the tick timer pauses immediately but counters
/// are NOT reset until a 5-second grace period elapses. If the app returns to
/// active within the grace period (e.g., a notification banner, incoming call,
/// or Control Center swipe), the grace timer is cancelled and counting resumes
/// from where it left off. Only after the grace period expires without a return
/// to active are all counters reset to zero.
///
/// **Lifecycle:**
/// - `UIApplication.didBecomeActiveNotification`  → starts the 1-second tick timer
///   (or resumes it if still within the grace period).
/// - `UIApplication.willResignActiveNotification` → pauses the timer and starts the
///   grace period; resets counters only if the grace period expires.
///
/// Call `startIfActive()` after configuring thresholds if the app is already in
/// the foreground (e.g., on `scheduleReminders()` with the app open) so the
/// tracker begins counting without waiting for the next lifecycle event.
///
/// All methods must be called on the main thread (owned by `@MainActor AppCoordinator`).
@MainActor
protocol ScreenTimeTracking: ServiceLifecycle {
    var onThresholdReached: ((ReminderType) -> Void)? { get set }
    func setThreshold(_ interval: TimeInterval, for type: ReminderType)
    func disableTracking(for type: ReminderType)
    func pause(for type: ReminderType)
    func resume(for type: ReminderType)
    func pauseAll()
    func resumeAll()
    func reset(for type: ReminderType)
    func resetAll()
    func startIfActive()
    func stop()
}

@MainActor
final class ScreenTimeTracker: ScreenTimeTracking {

    typealias ThresholdCallback = (ReminderType) -> Void

    // MARK: - Configuration Constants

    /// Seconds to wait after `willResignActive` before resetting counters to zero.
    /// Brief interruptions (notification banners, incoming calls, Control Center) that
    /// resolve within this window resume counting rather than nuking accumulated time.
    private let resetGracePeriod: TimeInterval

    // MARK: - State

    private var elapsed: [ReminderType: TimeInterval] = [:]
    private var thresholds: [ReminderType: TimeInterval] = [:]
    private var paused: Set<ReminderType> = []
    private var tickTimer: Timer?

    /// Records the `CACurrentMediaTime()` at each tick to compute the actual
    /// elapsed delta instead of assuming a constant 1.0 s per tick.
    /// `Timer` with `tolerance = 0.5` can fire significantly late; accumulating
    /// the real delta prevents drift over long sessions.
    private var lastTickTime: CFTimeInterval = 0

    /// Non-nil while we are within the grace period after `willResignActive`.
    /// Cancelled if the app returns to active before the grace period expires.
    private var resetTask: Task<Void, Never>?

    // MARK: - Callback

    /// Called on the main thread when a type's elapsed screen time reaches its threshold.
    /// The counter is reset to 0 before the callback fires.
    var onThresholdReached: ThresholdCallback?

    // MARK: - Init

    /// - Parameter resetGracePeriod: Seconds to wait after `willResignActive` before
    ///   clearing counters. Must be ≥ 0. Defaults to 5.0 s for production use; pass a
    ///   smaller value in tests to exercise grace-period behaviour without long sleeps.
    init(resetGracePeriod: TimeInterval = 5.0) {
        if resetGracePeriod < 0 {
            Logger.scheduling.warning(
                "ScreenTimeTracker: ignoring negative resetGracePeriod (\(resetGracePeriod)) — using 0"
            )
            self.resetGracePeriod = 0
        } else {
            self.resetGracePeriod = resetGracePeriod
        }
        for type in ReminderType.allCases {
            elapsed[type] = 0
        }
        registerLifecycleObservers()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        tickTimer?.invalidate()
        resetTask?.cancel()
    }

    // MARK: - Configuration

    /// Set the threshold (seconds of continuous screen-on time) for a reminder type.
    /// Resets the elapsed counter for the type.
    func setThreshold(_ interval: TimeInterval, for type: ReminderType) {
        guard interval > 0 else {
            Logger.scheduling.warning(
                "ScreenTimeTracker: ignoring zero/negative threshold for \(type.rawValue) — type will not fire"
            )
            return
        }
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
    /// Also cancels any pending grace-period reset.
    /// Use for cleanup (e.g., test `tearDown`) or when reminders are permanently disabled.
    func stop() {
        resetTask?.cancel()
        resetTask = nil
        stopTicking()
        resetAll()
        Logger.scheduling.debug("ScreenTimeTracker: stopped and reset")
    }

    // MARK: - ServiceLifecycle

    /// Satisfies `ServiceLifecycle` — delegates to `startIfActive()`.
    func startMonitoring() {
        startIfActive()
    }

    /// Satisfies `ServiceLifecycle` — delegates to `stop()`.
    func stopMonitoring() {
        stop()
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
        if let pendingReset = resetTask {
            // Returned within the grace period — cancel the reset and resume counting.
            pendingReset.cancel()
            resetTask = nil
            resumeTicking()
            Logger.scheduling.debug("ScreenTimeTracker: returned within grace period — resuming (no reset)")
        } else {
            // Grace period already expired or this is a cold start — begin fresh.
            startTicking()
        }
    }

    @objc private func handleWillResignActive() {
        // Pause the tick timer immediately so no time is accumulated during the gap.
        stopTicking()
        Logger.scheduling.debug("ScreenTimeTracker: resigned active — starting \(self.resetGracePeriod)s grace period")

        // Cancel any in-flight grace-period task before arming a new one.
        resetTask?.cancel()
        resetTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: UInt64(self.resetGracePeriod * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run { [weak self] in
                self?.resetTask = nil
                self?.resetAll()
                Logger.scheduling.debug("ScreenTimeTracker: grace period expired — all counters reset to 0")
            }
        }
    }

    // MARK: - Private: Tick Timer

    private func startTicking() {
        guard tickTimer == nil else { return }
        lastTickTime = 0  // reset so first tick uses default delta of 1.0
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
        tickTimer?.tolerance = 0.5
        Logger.scheduling.debug("ScreenTimeTracker: started ticking")
    }

    /// Resume the tick timer after a grace-period interruption.
    /// Identical to `startTicking()` — kept as a separate entry point for clarity.
    private func resumeTicking() {
        startTicking()
    }

    private func stopTicking() {
        tickTimer?.invalidate()
        tickTimer = nil
        lastTickTime = 0  // reset so the next tick after resume uses default delta
    }

    /// Advance all enabled, unpaused counters by one tick.
    ///
    /// The `now` parameter defaults to `CACurrentMediaTime()` for production use.
    /// Pass an explicit value in unit tests to exercise the 2 s delta-cap without
    /// running a real wall-clock timer.
    func tick(now: CFTimeInterval = CACurrentMediaTime()) {
        // Use real elapsed time since the last tick rather than the nominal 1.0 s.
        // Cap at 2.0 s to avoid large jumps after device sleep or backgrounding.
        let delta: TimeInterval = lastTickTime > 0 ? min(now - lastTickTime, 2.0) : 1.0
        lastTickTime = now

        for type in ReminderType.allCases {
            guard !paused.contains(type), let threshold = thresholds[type], threshold > 0 else { continue }
            elapsed[type, default: 0] += delta
            if elapsed[type, default: 0] >= threshold {
                elapsed[type] = 0
                Logger.scheduling.info("ScreenTimeTracker: \(type.rawValue) threshold reached (\(threshold)s continuous screen-on time)")
                onThresholdReached?(type)
            }
        }
    }
}

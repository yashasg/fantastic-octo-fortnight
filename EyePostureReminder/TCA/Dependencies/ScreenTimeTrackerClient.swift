import ComposableArchitecture
import Foundation

/// TCA dependency client wrapping `ScreenTimeTracker` for reducer consumption.
///
/// Phase 0 of the TCA migration (#665). The `liveValue` adapter installs
/// a single `onThresholdReached` closure on the underlying tracker that
/// multicasts to every active `thresholdReached` subscriber via per-subscriber
/// `AsyncStream` continuations.
@DependencyClient
struct ScreenTimeTrackerClient: Sendable {
    /// Sets the per-type continuous screen-on threshold, in seconds.
    var setThreshold: @Sendable (TimeInterval, ReminderType) async -> Void

    /// Enables tracking for the given type by re-arming its current threshold.
    var enableTracking: @Sendable (ReminderType) async -> Void

    /// Disables tracking for the given type and resets its counter.
    var disableTracking: @Sendable (ReminderType) async -> Void

    /// Pauses tracking for every reminder type.
    var pauseAll: @Sendable () async -> Void

    /// Resumes tracking for every reminder type.
    var resumeAll: @Sendable () async -> Void

    /// Resets the elapsed counter for the given reminder type.
    var reset: @Sendable (ReminderType) async -> Void

    /// Multicast stream of threshold-reached events keyed by reminder type.
    var thresholdReached: @Sendable () -> AsyncStream<ReminderType> = { .finished }
}

extension ScreenTimeTrackerClient: DependencyKey {
    static let liveValue: ScreenTimeTrackerClient = {
        Task { @MainActor in LiveScreenTimeTrackerBridge.shared.bootstrap() }
        return ScreenTimeTrackerClient(
            setThreshold: { interval, type in
                await MainActor.run {
                    LiveScreenTimeTrackerBridge.shared.setThreshold(interval, for: type)
                }
            },
            enableTracking: { type in
                await MainActor.run {
                    LiveScreenTimeTrackerBridge.shared.enableTracking(for: type)
                }
            },
            disableTracking: { type in
                await MainActor.run {
                    LiveScreenTimeTrackerBridge.shared.disableTracking(for: type)
                }
            },
            pauseAll: { await MainActor.run { LiveScreenTimeTrackerBridge.shared.pauseAll() } },
            resumeAll: { await MainActor.run { LiveScreenTimeTrackerBridge.shared.resumeAll() } },
            reset: { type in
                await MainActor.run { LiveScreenTimeTrackerBridge.shared.reset(for: type) }
            },
            thresholdReached: { makeScreenTimeThresholdStream() }
        )
    }()
}

extension DependencyValues {
    /// TCA accessor for the shared `ScreenTimeTrackerClient`.
    var screenTimeTrackerClient: ScreenTimeTrackerClient {
        get { self[ScreenTimeTrackerClient.self] }
        set { self[ScreenTimeTrackerClient.self] = newValue }
    }
}

/// Main-actor-isolated owner of the live `ScreenTimeTracker`. Tracks the most
/// recent per-type threshold so `enableTracking(_:)` can re-arm without the
/// caller needing to remember the value.
@MainActor
private final class LiveScreenTimeTrackerBridge {
    nonisolated static let shared = LiveScreenTimeTrackerBridge()

    private var tracker: ScreenTimeTracking?
    private var thresholds: [ReminderType: TimeInterval] = [:]
    private var hasBootstrapped = false

    private nonisolated init() {}

    func bootstrap() {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true

        let live = ScreenTimeTracker()
        live.onThresholdReached = { type in
            broadcastScreenTimeThreshold(type)
        }
        tracker = live
    }

    func setThreshold(_ interval: TimeInterval, for type: ReminderType) {
        thresholds[type] = interval
        tracker?.setThreshold(interval, for: type)
    }

    func enableTracking(for type: ReminderType) {
        guard let interval = thresholds[type] else { return }
        tracker?.setThreshold(interval, for: type)
    }

    func disableTracking(for type: ReminderType) {
        tracker?.disableTracking(for: type)
    }

    func pauseAll() { tracker?.pauseAll() }
    func resumeAll() { tracker?.resumeAll() }
    func reset(for type: ReminderType) { tracker?.reset(for: type) }
}

/// File-scoped multicast continuations for `ScreenTimeTrackerClient.thresholdReached`.
private let screenTimeThresholdContinuations =
    LockIsolated<[UUID: AsyncStream<ReminderType>.Continuation]>([:])

private func makeScreenTimeThresholdStream() -> AsyncStream<ReminderType> {
    let (stream, continuation) = AsyncStream<ReminderType>.makeStream()
    let id = UUID()
    screenTimeThresholdContinuations.withValue { $0[id] = continuation }
    continuation.onTermination = { _ in
        screenTimeThresholdContinuations.withValue { dict in
            dict[id] = nil
        }
    }
    return stream
}

private func broadcastScreenTimeThreshold(_ type: ReminderType) {
    screenTimeThresholdContinuations.withValue { dict in
        for continuation in dict.values { continuation.yield(type) }
    }
}

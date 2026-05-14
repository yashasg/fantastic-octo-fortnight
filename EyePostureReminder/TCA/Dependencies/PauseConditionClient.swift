import ComposableArchitecture
import Foundation

/// TCA dependency client wrapping `PauseConditionManager` for reducer
/// consumption.
///
/// Phase 0 of the MVVM → TCA migration (#665). The `liveValue` adapter
/// installs a single `onPauseStateChanged` closure on the underlying manager
/// that multicasts to every active `pauseChanges` subscriber via
/// per-subscriber `AsyncStream` continuations.
@DependencyClient
struct PauseConditionClient: Sendable {
    /// Whether the current aggregate pause state is active.
    var isPaused: @Sendable () async -> Bool = { false }

    /// Multicast stream of aggregate pause-state transitions.
    var pauseChanges: @Sendable () -> AsyncStream<Bool> = { .finished }

    /// Begins monitoring focus, CarPlay, and driving conditions.
    var startMonitoring: @Sendable () async -> Void

    /// Stops monitoring and clears the active condition set.
    var stopMonitoring: @Sendable () async -> Void
}

extension PauseConditionClient: DependencyKey {
    static let liveValue: PauseConditionClient = {
        Task { @MainActor in LivePauseConditionBridge.shared.bootstrap() }
        return PauseConditionClient(
            isPaused: { await LivePauseConditionBridge.shared.isPaused() },
            pauseChanges: { makePauseConditionStream() },
            startMonitoring: { await LivePauseConditionBridge.shared.startMonitoring() },
            stopMonitoring: { await LivePauseConditionBridge.shared.stopMonitoring() }
        )
    }()
}

extension DependencyValues {
    /// TCA accessor for the shared `PauseConditionClient`.
    var pauseConditionClient: PauseConditionClient {
        get { self[PauseConditionClient.self] }
        set { self[PauseConditionClient.self] = newValue }
    }
}

/// Main-actor-isolated owner of the live `PauseConditionManager`. Multicasts
/// `onPauseStateChanged` callbacks into file-scope continuations.
@MainActor
private final class LivePauseConditionBridge {
    nonisolated static let shared = LivePauseConditionBridge()

    private var manager: PauseConditionProviding?
    private var hasBootstrapped = false

    private nonisolated init() {}

    func bootstrap() {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true

        let settings = SettingsStore()
        let live = PauseConditionManager(
            settings: settings,
            focusDetector: LiveFocusStatusDetector(),
            carPlayDetector: LiveCarPlayDetector(),
            drivingDetector: LiveDrivingActivityDetector()
        )
        live.onPauseStateChanged = { paused in
            broadcastPauseChange(paused)
        }
        manager = live
    }

    func isPaused() -> Bool {
        manager?.isPaused ?? false
    }

    func startMonitoring() {
        manager?.startMonitoring()
    }

    func stopMonitoring() {
        manager?.stopMonitoring()
    }
}

/// File-scoped multicast continuations for `PauseConditionClient.pauseChanges`.
private let pauseConditionContinuations =
    LockIsolated<[UUID: AsyncStream<Bool>.Continuation]>([:])

private func makePauseConditionStream() -> AsyncStream<Bool> {
    let (stream, continuation) = AsyncStream<Bool>.makeStream()
    let id = UUID()
    pauseConditionContinuations.withValue { $0[id] = continuation }
    continuation.onTermination = { _ in
        pauseConditionContinuations.withValue { dict in
            dict[id] = nil
        }
    }
    return stream
}

private func broadcastPauseChange(_ paused: Bool) {
    pauseConditionContinuations.withValue { dict in
        for continuation in dict.values { continuation.yield(paused) }
    }
}

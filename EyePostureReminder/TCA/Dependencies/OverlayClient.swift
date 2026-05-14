import ComposableArchitecture
import Foundation

/// Lifecycle events emitted by the overlay layer for reducer consumption.
///
/// The Phase 0 adapter multicasts these events from the live `OverlayManager`'s
/// `OverlayLifecycleCallbacks` so multiple reducers can subscribe independently.
enum OverlayLifecycleEvent: Equatable, Sendable {
    /// The overlay for the given reminder type has been presented on screen.
    case presented(ReminderType)
    /// The overlay for the given reminder type has been dismissed.
    case dismissed(ReminderType)
    /// The user tapped the "Settings" affordance inside the overlay for the
    /// given reminder type.
    case settingsTapped(ReminderType)
}

/// TCA dependency client wrapping `OverlayManager` for reducer consumption.
///
/// Phase 0 of the MVVM → TCA migration (#665). The `liveValue` adapter
/// installs a single set of `OverlayLifecycleCallbacks` per `show` call that
/// multicasts to every active `lifecycleEvents` subscriber via per-subscriber
/// `AsyncStream` continuations.
@DependencyClient
struct OverlayClient: Sendable {
    /// Presents (or queues) the break overlay for the given reminder type.
    /// Parameters: type, duration in seconds, haptics enabled, pause-media
    /// enabled.
    var show: @Sendable (ReminderType, TimeInterval, Bool, Bool) async -> Void

    /// Dismisses the overlay if currently visible.
    var dismiss: @Sendable () async -> Void

    /// Drops every queued overlay request.
    var clearQueue: @Sendable () async -> Void

    /// Drops queued overlay requests for the given reminder type only.
    var clearQueueForType: @Sendable (ReminderType) async -> Void

    /// Whether the overlay window is currently on screen.
    var isVisible: @Sendable () async -> Bool = { false }

    /// Multicast stream of `OverlayLifecycleEvent`s. Each subscriber receives
    /// every event from the moment subscription begins.
    var lifecycleEvents: @Sendable () -> AsyncStream<OverlayLifecycleEvent> = { .finished }
}

extension OverlayClient: DependencyKey {
    static let liveValue: OverlayClient = {
        Task { @MainActor in _ = LiveOverlayBridge.shared }
        return OverlayClient(
            show: { type, duration, hapticsEnabled, pauseMediaEnabled in
                await LiveOverlayBridge.shared.show(
                    type: type,
                    duration: duration,
                    hapticsEnabled: hapticsEnabled,
                    pauseMediaEnabled: pauseMediaEnabled
                )
            },
            dismiss: { await LiveOverlayBridge.shared.dismiss() },
            clearQueue: { await LiveOverlayBridge.shared.clearQueue() },
            clearQueueForType: { type in
                await LiveOverlayBridge.shared.clearQueue(for: type)
            },
            isVisible: { await LiveOverlayBridge.shared.isVisible() },
            lifecycleEvents: { makeOverlayLifecycleStream() }
        )
    }()
}

extension DependencyValues {
    /// TCA accessor for the shared `OverlayClient`.
    var overlayClient: OverlayClient {
        get { self[OverlayClient.self] }
        set { self[OverlayClient.self] = newValue }
    }
}

/// Main-actor-isolated owner of the live `OverlayManager`. Each `show` call
/// installs callbacks that multicast lifecycle events to file-scope
/// continuations so any number of subscribers can observe the overlay.
@MainActor
private final class LiveOverlayBridge {
    nonisolated static let shared = LiveOverlayBridge()

    let manager: OverlayPresenting = OverlayManager()

    private nonisolated init() {}

    func show(
        type: ReminderType,
        duration: TimeInterval,
        hapticsEnabled: Bool,
        pauseMediaEnabled: Bool
    ) {
        let callbacks = OverlayLifecycleCallbacks(
            onPresent: { broadcastOverlayEvent(.presented(type)) },
            onDismiss: { broadcastOverlayEvent(.dismissed(type)) },
            onSettingsTap: { broadcastOverlayEvent(.settingsTapped(type)) }
        )
        manager.showOverlay(
            for: type,
            duration: duration,
            hapticsEnabled: hapticsEnabled,
            pauseMediaEnabled: pauseMediaEnabled,
            callbacks: callbacks
        )
    }

    func dismiss() { manager.dismissOverlay() }
    func clearQueue() { manager.clearQueue() }
    func clearQueue(for type: ReminderType) { manager.clearQueue(for: type) }
    func isVisible() -> Bool { manager.isOverlayVisible }
}

/// File-scoped multicast continuations for `OverlayClient.lifecycleEvents`.
private let overlayLifecycleContinuations =
    LockIsolated<[UUID: AsyncStream<OverlayLifecycleEvent>.Continuation]>([:])

private func makeOverlayLifecycleStream() -> AsyncStream<OverlayLifecycleEvent> {
    let (stream, continuation) = AsyncStream<OverlayLifecycleEvent>.makeStream()
    let id = UUID()
    overlayLifecycleContinuations.withValue { $0[id] = continuation }
    continuation.onTermination = { _ in
        overlayLifecycleContinuations.withValue { dict in
            dict[id] = nil
        }
    }
    return stream
}

private func broadcastOverlayEvent(_ event: OverlayLifecycleEvent) {
    overlayLifecycleContinuations.withValue { dict in
        for continuation in dict.values { continuation.yield(event) }
    }
}

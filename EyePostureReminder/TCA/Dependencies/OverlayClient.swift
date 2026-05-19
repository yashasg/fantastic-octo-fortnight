import ComposableArchitecture
import Foundation
import UIKit

/// Lifecycle events emitted by `OverlayFeature` for reducer consumption.
///
/// `OverlayFeature` calls `OverlayClient.broadcast(_:)` from its presentation,
/// settings-tap, and dismissal effects; every active `lifecycleEvents`
/// subscriber observes the event via the multicast `AsyncStream` infrastructure
/// owned by this file. `AppFeature` (settings handoff, #786) and
/// `SchedulingFeature` (session-timing + DeviceActivity hooks, #901/#903)
/// subscribe at `.onAppear` / `.start` time respectively.
enum OverlayLifecycleEvent: Equatable, Sendable {
    /// The overlay for the given reminder type has been presented on screen.
    case presented(ReminderType)
    /// The overlay for the given reminder type has been dismissed.
    case dismissed(ReminderType)
    /// The user tapped the "Settings" affordance inside the overlay for the
    /// given reminder type.
    case settingsTapped(ReminderType)
}

/// TCA dependency client for overlay-adjacent side-effects that cannot live
/// inside `OverlayFeature` itself.
///
/// `#919` Phase 1 introduced the canonical `RootView.fullScreenCover` driven
/// by `state.overlay`. `#920` Phase 2 retires the `OverlayManager` UIWindow
/// path entirely; the client surface is now:
///
/// - `lifecycleEvents()` + `broadcast(_:)` — multicast event bus that lets
///   `AppFeature` (settings handoff #786) and `SchedulingFeature`
///   (session-timing #901, DeviceActivity-on-overlay #903) react to overlay
///   transitions without `OverlayFeature` knowing about them.
/// - `pauseExternalAudio()` / `resumeExternalAudio()` — `AVAudioSession`
///   interruption gated on `OverlayFeature.State.pauseMediaEnabled`, owned
///   here so the reducer does not import `AVFoundation`.
/// - `postScreenChanged()` — `UIAccessibility.screenChanged` notification
///   posted on present/dismiss so VoiceOver refocuses on the overlay enter
///   and back to underlying content on exit.
///
/// No `show` / `dismiss` / queue accessors live here anymore: presentation
/// state is the canonical TCA slot on `AppFeature.State.overlay`, and
/// queueing flows through `AppFeature.State.overlayQueue` writes (#289 FIFO
/// preserved by the reducer rather than the manager).
@DependencyClient
struct OverlayClient: Sendable {
    /// Multicast stream of `OverlayLifecycleEvent`s. Each subscriber receives
    /// every event from the moment subscription begins.
    var lifecycleEvents: @Sendable () -> AsyncStream<OverlayLifecycleEvent> = { .finished }

    /// Broadcasts `event` to every active `lifecycleEvents` subscriber.
    /// Invoked from `OverlayFeature` effects at presentation (`.onAppear`),
    /// settings-tap (`.settingsTapped`), and dismissal (`.dismissed`).
    var broadcast: @Sendable (OverlayLifecycleEvent) async -> Void

    /// Activates `AVAudioSession` (via `MediaControlling`) so other apps'
    /// audio is interrupted while the overlay is on screen. Called from
    /// `OverlayFeature.onAppear` when `state.pauseMediaEnabled == true`.
    var pauseExternalAudio: @Sendable () async -> Void

    /// Deactivates `AVAudioSession` and notifies other apps to resume.
    /// Called from `OverlayFeature.dismissed` when `state.pauseMediaEnabled
    /// == true` so the resume path runs exactly once per presentation.
    var resumeExternalAudio: @Sendable () async -> Void

    /// Posts `UIAccessibility.Notification.screenChanged` so VoiceOver
    /// refocuses when the overlay enters or exits. Called from
    /// `OverlayFeature.onAppear` and `.dismissed`.
    var postScreenChanged: @Sendable () async -> Void
}

extension OverlayClient: DependencyKey {
    static let liveValue = OverlayClient(
        lifecycleEvents: { makeOverlayLifecycleStream() },
        broadcast: { event in broadcastOverlayEvent(event) },
        pauseExternalAudio: {
            await MainActor.run { LiveOverlayClientBridge.shared.pauseExternalAudio() }
        },
        resumeExternalAudio: {
            await MainActor.run { LiveOverlayClientBridge.shared.resumeExternalAudio() }
        },
        postScreenChanged: {
            await MainActor.run { LiveOverlayClientBridge.shared.postScreenChanged() }
        }
    )
}

extension DependencyValues {
    /// TCA accessor for the shared `OverlayClient`.
    var overlayClient: OverlayClient {
        get { self[OverlayClient.self] }
        set { self[OverlayClient.self] = newValue }
    }
}

/// Main-actor-isolated owner of the audio + accessibility side-effect
/// implementations. Holds onto a long-lived `AudioInterruptionManager`
/// so successive pause/resume calls share one `AVAudioSession` activation
/// path; the accessibility poster is stateless and constructed once for
/// symmetry with `audioManager`.
@MainActor
private final class LiveOverlayClientBridge {
    nonisolated static let shared = LiveOverlayClientBridge()

    private let audioManager: MediaControlling
    private let accessibilityPoster: AccessibilityNotificationPosting

    private nonisolated init() {
        self.audioManager = AudioInterruptionManager()
        self.accessibilityPoster = LiveAccessibilityNotificationPoster()
    }

    func pauseExternalAudio() {
        audioManager.pauseExternalAudio()
    }

    func resumeExternalAudio() {
        audioManager.resumeExternalAudio()
    }

    func postScreenChanged() {
        accessibilityPoster.postScreenChanged(focusElement: nil)
    }
}

// File-scoped multicast continuations for `OverlayClient.lifecycleEvents`.
//
// `OverlayFeature` calls `overlayClient.broadcast(_:)` from its effects,
// which fans the event out to every active subscriber registered via
// `lifecycleEvents()`. The map is keyed on a per-subscriber `UUID` so a
// terminating stream removes its own slot without touching siblings.

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

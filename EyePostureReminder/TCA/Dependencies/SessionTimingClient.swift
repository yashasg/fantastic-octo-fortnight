import ComposableArchitecture
import Foundation

/// TCA dependency client surfacing the reminder-cycle session-timing
/// analytics pair (`sessionStarted` / `sessionEnded`) for `SchedulingFeature`.
///
/// Phase 2 of the TCA migration (#901, split out of #898). The reducer
/// consumes `OverlayClient.lifecycleEvents` (installed by #904) and routes
/// each `.presented(_:)` / `.dismissed(_:)` emission through this client so
/// the legacy `AppCoordinator` start↔stop analytics contract migrates to the
/// dependency boundary. The `liveValue` adapter forwards both calls to the
/// shared static `AnalyticsLogger.log` sink, mirroring `AnalyticsClient`'s
/// transport so every reducer that depends on this client writes through a
/// single `os.Logger` pipeline.
///
/// `launchReady` (#902) landed on this same client rather than a new
/// dependency so reducer code only holds one `@Dependency` for the
/// session-timing analytics surface. `SchedulingFeature.startEffect` calls
/// `launchReady(.streamsInstalled)` from the tail of the cold-launch
/// installation `.merge` once every long-running stream subscription is
/// in-flight, restoring the legacy `AppCoordinator` launch-readiness signal
/// at the dependency boundary instead of an ad-hoc `AnalyticsLogger.log`
/// site embedded in the reducer.
@DependencyClient
struct SessionTimingClient: Sendable {
    /// Records the start of a reminder cycle for the given `ReminderType` at
    /// the supplied wall-clock instant. Called from `SchedulingFeature`'s
    /// `.overlayLifecycleEvent(.presented(_:))` handler.
    var sessionStarted: @Sendable (ReminderType, Date) async -> Void

    /// Records the end of a reminder cycle for the given `ReminderType` at
    /// the supplied wall-clock instant. Called from `SchedulingFeature`'s
    /// `.overlayLifecycleEvent(.dismissed(_:))` handler.
    var sessionEnded: @Sendable (ReminderType, Date) async -> Void

    /// Emits the cold-launch readiness signal for `SchedulingFeature` once
    /// every long-running stream subscription installed by `startEffect`
    /// (settings, posture-settings, threshold, pause, IPC, overlay
    /// lifecycle) is in-flight (#902). The default `{ _ in }` keeps
    /// existing call sites that construct `SessionTimingClient` manually
    /// (silent test stubs, recorder fakes) byte-compatible without an
    /// explicit override.
    var launchReady: @Sendable (LaunchReadinessReason) async -> Void = { _ in }
}

extension SessionTimingClient {
    /// Typed launch-readiness reason carried by `launchReady` (#902). The
    /// `String` raw value is the wire format `AnalyticsLogger` writes to
    /// `os.Logger` so downstream readers can grep Console.app /
    /// Instruments without decoding a Swift enum.
    enum LaunchReadinessReason: String, Equatable, Sendable, CaseIterable {
        /// Cold-launch path: every long-running subscription installed by
        /// `SchedulingFeature.startEffect` is in-flight and the reducer is
        /// ready to serve reminders.
        case streamsInstalled = "streams_installed"
    }
}

extension SessionTimingClient: DependencyKey {
    static let liveValue = SessionTimingClient(
        sessionStarted: { type, date in
            AnalyticsLogger.log(.reminderSessionStarted(type: type, at: date))
        },
        sessionEnded: { type, date in
            AnalyticsLogger.log(.reminderSessionEnded(type: type, at: date))
        },
        launchReady: { reason in
            AnalyticsLogger.log(.reminderLaunchReady(reason: reason))
        }
    )
}

extension DependencyValues {
    /// TCA accessor for the shared `SessionTimingClient`.
    var sessionTimingClient: SessionTimingClient {
        get { self[SessionTimingClient.self] }
        set { self[SessionTimingClient.self] = newValue }
    }
}

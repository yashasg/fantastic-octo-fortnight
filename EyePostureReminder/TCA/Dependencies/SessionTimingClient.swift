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
/// Sibling `launchReady` analytics (#902) will land as an additional closure
/// on this same client rather than a new dependency, so reducer code only
/// holds one `@Dependency` for session-timing analytics surfaces.
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
}

extension SessionTimingClient: DependencyKey {
    static let liveValue = SessionTimingClient(
        sessionStarted: { type, date in
            AnalyticsLogger.log(.reminderSessionStarted(type: type, at: date))
        },
        sessionEnded: { type, date in
            AnalyticsLogger.log(.reminderSessionEnded(type: type, at: date))
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

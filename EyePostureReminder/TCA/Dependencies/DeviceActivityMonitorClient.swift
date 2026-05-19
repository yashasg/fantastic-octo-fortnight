import ComposableArchitecture
import Foundation

/// TCA dependency client wrapping `DeviceActivityMonitorProviding` for reducer
/// consumption.
///
/// Phase 0 of the TCA migration (#665). The pre-entitlement default
/// implementation is `DeviceActivityMonitorNoop`, so the `liveValue` adapter
/// effectively becomes a noop until the FamilyControls entitlement (#201) is
/// provisioned. The `UUID` argument carried by the closures is part of the
/// normative Phase 1 contract — Phase 1 will key sessions by that identifier.
///
/// Overlay-presented accessor (#903): `startScheduleForOverlay(_:)` signals
/// that an overlay for `type` has just transitioned to presented so the
/// extension can schedule its DeviceActivity monitoring window through the
/// dependency boundary instead of having `SchedulingFeature` synthesize a
/// `ShieldSession` itself. The live implementation routes through
/// `LiveDeviceActivityMonitorBridge.startScheduleForOverlay(_:)` and remains
/// a no-op until the FamilyControls entitlement (#201) lands and a real
/// per-type `ShieldSession` can be derived; the surface lets reducer paths
/// stay byte-stable across that future swap.
@DependencyClient
struct DeviceActivityMonitorClient: Sendable {
    /// Schedules a DeviceActivity monitoring window for the supplied break
    /// session. The `UUID` keys the session for later cancellation.
    var schedule: @Sendable (ShieldSession, UUID) async -> Void

    /// Cancels the active DeviceActivity monitoring window. When `nil`, every
    /// active session is cancelled.
    var cancel: @Sendable (UUID?) async -> Void

    /// Starts the DeviceActivity monitoring window that pairs with an
    /// overlay transitioning to presented for `type` (#903). Default closure
    /// is a no-op so call sites that don't override it stay byte-compatible
    /// with the pre-#903 silent baseline; the live implementation routes to
    /// `LiveDeviceActivityMonitorBridge.startScheduleForOverlay(_:)` and is
    /// itself a no-op until #201 promotes the bridge off
    /// `DeviceActivityMonitorNoop`.
    var startScheduleForOverlay: @Sendable (ReminderType) async -> Void = { _ in }
}

extension DeviceActivityMonitorClient: DependencyKey {
    static let liveValue: DeviceActivityMonitorClient = {
        Task { @MainActor in _ = LiveDeviceActivityMonitorBridge.shared }
        return DeviceActivityMonitorClient(
            schedule: { session, _ in
                await LiveDeviceActivityMonitorBridge.shared.schedule(session)
            },
            cancel: { _ in
                await LiveDeviceActivityMonitorBridge.shared.cancel()
            },
            startScheduleForOverlay: { type in
                await LiveDeviceActivityMonitorBridge.shared.startScheduleForOverlay(for: type)
            }
        )
    }()
}

extension DependencyValues {
    /// TCA accessor for the shared `DeviceActivityMonitorClient`.
    var deviceActivityMonitorClient: DeviceActivityMonitorClient {
        get { self[DeviceActivityMonitorClient.self] }
        set { self[DeviceActivityMonitorClient.self] = newValue }
    }
}

/// Main-actor-isolated owner of the live `DeviceActivityMonitorProviding`
/// implementation. Defaults to the pre-entitlement noop until #201 lands.
@MainActor
private final class LiveDeviceActivityMonitorBridge {
    static let shared = LiveDeviceActivityMonitorBridge()

    let monitor: DeviceActivityMonitorProviding = DeviceActivityMonitorNoop()

    private init() {}

    func schedule(_ session: ShieldSession) async {
        try? await monitor.scheduleBreakMonitoring(for: session)
    }

    func cancel() async {
        try? await monitor.cancelBreakMonitoring()
    }

    /// Overlay-presented entry point (#903). Today's `monitor` is the
    /// `DeviceActivityMonitorNoop` fallback so this routes to a no-op; once
    /// #201 promotes the bridge to the real `FamilyControls` provider, this
    /// will derive a per-type `ShieldSession` from the active break
    /// duration and forward to `scheduleBreakMonitoring(for:)`.
    func startScheduleForOverlay(for type: ReminderType) async {
        _ = type
    }
}

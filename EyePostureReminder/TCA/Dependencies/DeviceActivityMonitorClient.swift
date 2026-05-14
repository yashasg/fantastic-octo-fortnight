import ComposableArchitecture
import Foundation

/// TCA dependency client wrapping `DeviceActivityMonitorProviding` for reducer
/// consumption.
///
/// Phase 0 of the MVVM → TCA migration (#665). The pre-entitlement default
/// implementation is `DeviceActivityMonitorNoop`, so the `liveValue` adapter
/// effectively becomes a noop until the FamilyControls entitlement (#201) is
/// provisioned. The `UUID` argument carried by the closures is part of the
/// normative Phase 1 contract — Phase 1 will key sessions by that identifier.
@DependencyClient
struct DeviceActivityMonitorClient: Sendable {
    /// Schedules a DeviceActivity monitoring window for the supplied break
    /// session. The `UUID` keys the session for later cancellation.
    var schedule: @Sendable (ShieldSession, UUID) async -> Void

    /// Cancels the active DeviceActivity monitoring window. When `nil`, every
    /// active session is cancelled.
    var cancel: @Sendable (UUID?) async -> Void
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
}

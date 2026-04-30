/// Compile-safe no-op implementation of `DeviceActivityMonitorProviding`.
///
/// Injected by `AppCoordinator` until:
///   1. The `com.apple.developer.family-controls` entitlement is provisioned (#201), AND
///   2. A real `DeviceActivityCenter`-backed scheduler is wired into the coordinator.
///
/// `isAvailable` is always `false`, ensuring `AppCoordinator` never calls
/// `scheduleBreakMonitoring(for:)` with this stub (callers guard on `isAvailable`).
/// No `DeviceActivity`, `ManagedSettings`, or `FamilyControls` frameworks are imported.

import Foundation

@MainActor
final class DeviceActivityMonitorNoop: DeviceActivityMonitorProviding {

    /// Always `false` — FamilyControls entitlement not yet provisioned (#201).
    var isAvailable: Bool { false }

    /// Always `nil` — no session is ever scheduled in the noop path.
    private(set) var activeSession: ShieldSession?

    // MARK: - DeviceActivityMonitorProviding

    /// No-op. Pre-entitlement: returns immediately.
    ///
    /// Real implementation (post-#201):
    /// ```swift
    /// // 1. Write session to App Group UserDefaults
    /// AppGroupIPCStore().writeShieldSession(
    ///     reasonRaw: session.reason.rawValue,
    ///     durationSeconds: session.durationSeconds,
    ///     triggeredAt: session.triggeredAt
    /// )
    /// // 2. Schedule the monitoring window
    /// try DeviceActivityCenter.shared.startMonitoring(
    ///     activity: .breakActivity(for: session.reason),
    ///     events: [],
    ///     schedule: .break(session: session))
    /// activeSession = session
    /// ```
    func scheduleBreakMonitoring(for session: ShieldSession) async throws {
        // Pre-entitlement: nothing to schedule.
        // Requires FamilyControls entitlement (#201) and user authorization.
    }

    /// No-op. Pre-entitlement: returns immediately.
    ///
    /// Real implementation (post-#201):
    /// ```swift
    /// DeviceActivityCenter.shared.stopMonitoring([.breakActivity(for: activeSession?.reason)])
    /// activeSession = nil
    /// ```
    func cancelBreakMonitoring() async throws {
        // Pre-entitlement: nothing to cancel.
    }

    // MARK: - ServiceLifecycle

    func startMonitoring() {}
    func stopMonitoring() {}
}

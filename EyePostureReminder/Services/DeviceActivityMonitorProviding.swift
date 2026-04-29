/// Protocol abstraction for DeviceActivity scheduling in the main app.
///
/// In the target architecture (post-#201), the main app calls
/// `DeviceActivityCenter.shared.startMonitoring(activity:events:schedule:)` here.
/// The registered `DeviceActivityMonitorExtension` receives `intervalDidStart(for:)`
/// and applies `ManagedSettingsStore` shield restrictions so the user cannot switch
/// apps during a break.
///
/// This protocol is **compile-safe**: it imports only `Foundation` — no
/// `FamilyControls`, `DeviceActivity`, or `ManagedSettings` references.
/// The concrete implementation will add those imports once #201 is resolved.
///
/// **Default injection:** `AppCoordinator` holds `DeviceActivityMonitorNoop` until:
///   1. FamilyControls entitlement is provisioned (#201).
///   2. The user grants `AuthorizationCenter.shared.requestAuthorization(for: .individual)`.
///   3. `DeviceActivityMonitorScheduler` (real impl) is passed to the coordinator init.
///
/// **Session lifecycle:**
///   - Call `scheduleBreakMonitoring(for:)` when the break overlay is actually visible.
///   - Call `cancelBreakMonitoring()` on every break-end path (overlay dismiss, snooze,
///     pause conditions) — a stuck shield is worse than a spurious cancel.

import Foundation

// MARK: - DeviceActivityMonitorProviding

/// Schedules and cancels OS-level DeviceActivity monitoring windows for break sessions.
///
/// All methods are `@MainActor`-isolated via the `ServiceLifecycle` inheritance.
@MainActor
protocol DeviceActivityMonitorProviding: ServiceLifecycle {

    /// Whether DeviceActivity monitoring is authorized and available on this device.
    ///
    /// Returns `false` when:
    /// - The FamilyControls entitlement is not provisioned (#201 blocker).
    /// - The user has not granted FamilyControls authorization.
    /// - The device is a simulator (DeviceActivity does not function in Simulator).
    ///
    /// `AppCoordinator` guards on `isAvailable` before scheduling monitor operations.
    var isAvailable: Bool { get }

    /// The currently active break monitoring session, or `nil` when no window is running.
    ///
    /// Updated by `scheduleBreakMonitoring(for:)` and cleared by `cancelBreakMonitoring()`.
    /// Consumers can display "Shield active — N seconds remaining" using this value.
    var activeSession: ShieldSession? { get }

    /// Schedule a DeviceActivity monitoring window for the given break session.
    ///
    /// Writes an encoded `session` payload to the shared App Group `UserDefaults` so the
    /// `DeviceActivityMonitorExtension` can read break context in its `intervalDidStart`
    /// callback. Then starts a `DeviceActivityCenter` monitoring window scoped to
    /// `session.durationSeconds`.
    ///
    /// - Pre-entitlement noop: returns immediately without side effects.
    /// - Post-#201 real implementation:
    ///   1. Writes `session` through `AppGroupIPCStore.writeShieldSession`.
    ///   2. Calls `DeviceActivityCenter.shared.startMonitoring(activity:events:schedule:)`
    ///      with a `DeviceActivitySchedule` from `triggeredAt` to `triggeredAt + durationSeconds`.
    ///   3. Sets `activeSession = session`.
    ///
    /// - Parameter session: Describes the break reason, duration, and trigger time.
    /// - Throws: If `DeviceActivityCenter.startMonitoring` fails (e.g., authorization
    ///   revoked between check and call). Callers should log and fall back gracefully —
    ///   the notification + overlay reminder path continues independently.
    func scheduleBreakMonitoring(for session: ShieldSession) async throws

    /// Cancel the currently active DeviceActivity monitoring window.
    ///
    /// Stops `DeviceActivityCenter` monitoring. The `DeviceActivityMonitorExtension`
    /// receives `intervalDidEnd(for:)` and clears `ManagedSettingsStore` restrictions.
    /// Clears `activeSession`.
    ///
    /// Must be called on every break-end path:
    ///   - Overlay dismissed (× button or auto-dismiss countdown).
    ///   - Snooze activated (`cancelAllReminders`).
    ///   - Active pause condition (driving, CarPlay, Focus mode).
    ///
    /// **Idempotent:** Safe to call when no session is active. Implementations must
    /// treat a no-active-session cancel as a no-op rather than throwing.
    func cancelBreakMonitoring() async throws
}

/// Protocol abstractions for the Screen Time shield integration.
///
/// The real implementation (`ScreenTimeShieldManager`) depends on
/// `FamilyControls`, `ManagedSettings`, and `DeviceActivity` — all of which
/// require the `com.apple.developer.family-controls` entitlement (#201) and
/// App Extension targets that cannot be expressed in SPM alone.
///
/// These protocols define the integration boundary so `AppCoordinator` can be
/// wired to the shield provider now, before the Xcode project migration and
/// entitlement approval unblock the concrete implementation.

import Foundation

// MARK: - ScreenTimeShieldProviding

/// Provides OS-level device shielding during break sessions.
///
/// Conforming types interact with `FamilyControls` / `ManagedSettings` to apply
/// and remove a system-enforced shield that prevents the user from using other
/// apps during a break. This is an opt-in "Hard Mode" layer on top of the
/// existing notification + overlay reminder system.
///
/// `isAvailable` returns `false` when:
/// - The `FamilyControls` entitlement has not been provisioned (#201 blocker).
/// - The user has not granted `AuthorizationCenter.shared.requestAuthorization(for: .individual)`.
/// - The framework is unavailable (Simulator; iOS < 16).
///
/// All methods are `@MainActor`-isolated via the `ServiceLifecycle` inheritance.
@MainActor
protocol ScreenTimeShieldProviding: ServiceLifecycle {

    /// Whether Screen Time shielding is authorized and available.
    ///
    /// When `false`, `beginShield(for:)` is a no-op and should not be called.
    /// `AppCoordinator` checks this before attempting to shield.
    var isAvailable: Bool { get }

    /// Begin a shielding session for the given break.
    ///
    /// Writes session metadata to the shared App Group `UserDefaults` so the
    /// `DeviceActivityMonitorExtension` can populate the shield UI, then schedules
    /// a `DeviceActivityCenter` monitoring window for `session.durationSeconds`.
    ///
    /// - Parameter session: Describes the break reason, duration, and trigger time.
    /// - Throws: If `FamilyControls` authorization is missing or the
    ///   `DeviceActivityCenter` call fails. Callers should surface this as a
    ///   non-fatal fallback (shield unavailable; reminder-only mode continues).
    func beginShield(for session: ShieldSession) async throws

    /// Terminate the active shielding session.
    ///
    /// Stops `DeviceActivityCenter` monitoring and clears `ManagedSettingsStore`
    /// restrictions. Must be called on every break dismiss path (× button,
    /// auto-dismiss, snooze) to avoid a stuck shield.
    ///
    /// - Throws: If the underlying `DeviceActivityCenter.stopMonitoring` call fails.
    ///   A stuck shield is worse than a thrown error — implementations should log
    ///   and not re-throw unrecoverable cases.
    func endShield() async throws
}

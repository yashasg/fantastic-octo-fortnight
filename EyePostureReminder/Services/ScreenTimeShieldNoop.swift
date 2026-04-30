/// Compile-safe no-op implementation of `ScreenTimeShieldProviding`.
///
/// Injected by `AppCoordinator` until:
/// 1. The FamilyControls entitlement is provisioned (#201), AND
/// 2. The project is migrated to an Xcode project with the required extension
///    targets (`ShieldConfigurationExtension`, `DeviceActivityMonitorExtension`).
///
/// The no-op ensures the `AppCoordinator` shield wiring point compiles and
/// tests pass unconditionally, with `isAvailable = false` accurately reflecting
/// the pre-entitlement state.

import Foundation

@MainActor
final class ScreenTimeShieldNoop: ScreenTimeShieldProviding {

    /// Always `false` — FamilyControls entitlement not yet provisioned.
    var isAvailable: Bool { false }

    /// No-op. The real implementation writes to shared App Group UserDefaults
    /// and schedules a DeviceActivityCenter monitoring window.
    func beginShield(for session: ShieldSession) async throws {
        // Pre-entitlement: nothing to do.
        // Real implementation: ManagedSettingsStore + DeviceActivityCenter.
    }

    /// No-op. The real implementation clears ManagedSettingsStore restrictions.
    func endShield() async throws {
        // Pre-entitlement: nothing to end.
    }

    func startMonitoring() {}
    func stopMonitoring() {}
}

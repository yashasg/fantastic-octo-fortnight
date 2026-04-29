/// Authorization abstraction for Screen Time access (FamilyControls).
///
/// This layer governs whether the user has granted kshana permission to use
/// FamilyControls for True Interrupt Mode. It sits above `ScreenTimeShieldProviding`
/// and is the first gate the user passes through during onboarding.
///
/// **Entitlement dependency:** The real implementation
/// (`ScreenTimeAuthorizationManager`) calls
/// `FamilyControls.AuthorizationCenter.shared.requestAuthorization(for: .individual)`.
/// That call requires the `com.apple.developer.family-controls` entitlement (#201)
/// and MUST NOT be instantiated in unit tests. Test code uses
/// `MockScreenTimeAuthorizationProviding`.
///
/// The noop (`ScreenTimeAuthorizationNoop`) is the default until the entitlement
/// is provisioned and the project is migrated to an Xcode project (#201).

import Foundation

// MARK: - ScreenTimeAuthorizationStatus

/// The authorization state of FamilyControls for True Interrupt Mode.
///
/// Mirrors `FamilyControls.AuthorizationStatus` without importing the framework,
/// so the type is unconditionally available in SPM targets and tests.
enum ScreenTimeAuthorizationStatus: String, Sendable, Equatable, CaseIterable {
    /// FamilyControls entitlement has not been provisioned. Feature is unavailable.
    /// This is the expected runtime state until #201 is resolved.
    case unavailable
    /// The user has not yet been asked for Screen Time access.
    case notDetermined
    /// The user has approved Screen Time access for True Interrupt Mode.
    case approved
    /// The user has denied Screen Time access.
    case denied

    /// User-visible description used in Settings status row.
    var localizedStatusKey: String {
        switch self {
        case .unavailable:    return "settings.trueInterrupt.statusRow.unavailable"
        case .notDetermined:  return "settings.trueInterrupt.statusRow.notDetermined"
        case .approved:       return "settings.trueInterrupt.statusRow.approved"
        case .denied:         return "settings.trueInterrupt.statusRow.denied"
        }
    }
}

// MARK: - ScreenTimeAuthorizationProviding

/// Provides FamilyControls authorization management for True Interrupt Mode.
///
/// Conforming types are `@MainActor`-isolated so SwiftUI can observe their
/// published state directly. In production the coordinator holds a reference to
/// `ScreenTimeAuthorizationNoop` until the entitlement is provisioned; then
/// `ScreenTimeAuthorizationManager` is injected.
@MainActor
protocol ScreenTimeAuthorizationProviding: AnyObject {
    /// Current authorization status. Changes are expected to be observable.
    var authorizationStatus: ScreenTimeAuthorizationStatus { get }

    /// Request FamilyControls authorization from the user.
    ///
    /// - Returns: The updated `ScreenTimeAuthorizationStatus` after the request.
    /// - Note: In the pre-entitlement state this always returns `.unavailable`.
    ///   The real implementation presents the system authorization sheet and maps
    ///   `FamilyControls.AuthorizationStatus` to `ScreenTimeAuthorizationStatus`.
    func requestAuthorization() async -> ScreenTimeAuthorizationStatus
}

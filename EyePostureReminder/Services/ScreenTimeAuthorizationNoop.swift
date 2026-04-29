/// Compile-safe no-op implementation of `ScreenTimeAuthorizationProviding`.
///
/// Injected by `AppCoordinator` until:
/// 1. The `com.apple.developer.family-controls` entitlement is provisioned (#201), AND
/// 2. A real FamilyControls-backed authorization manager is wired in.
///
/// Returns `.unavailable` for all state queries, accurately reflecting the
/// pre-entitlement condition. `AppCoordinator` and the onboarding / settings UI
/// check `authorizationStatus == .unavailable` to show appropriate copy.

import Foundation

@MainActor
final class ScreenTimeAuthorizationNoop: ScreenTimeAuthorizationProviding {

    /// Always `.unavailable` — entitlement not yet provisioned (#201).
    var authorizationStatus: ScreenTimeAuthorizationStatus { .unavailable }

    /// No-op. Returns `.unavailable` without presenting any system sheet.
    ///
    /// Real implementation:
    /// ```swift
    /// try await FamilyControls.AuthorizationCenter.shared
    ///     .requestAuthorization(for: .individual)
    /// return .approved
    /// ```
    func requestAuthorization() async -> ScreenTimeAuthorizationStatus {
        .unavailable
    }
}

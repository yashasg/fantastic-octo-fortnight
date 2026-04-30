/// Test-only stub implementation of `ScreenTimeAuthorizationProviding`.
///
/// Injected by `AppCoordinator` when the `--simulate-screen-time-not-determined`
/// launch argument is present. Allows UITests to reach `.notDetermined` authorization
/// state without requiring the `com.apple.developer.family-controls` entitlement
/// or real FamilyControls APIs (#399).
///
/// Only compiled in DEBUG builds — never ships in release.

import Foundation

#if DEBUG
@MainActor
final class ScreenTimeAuthorizationStub: ScreenTimeAuthorizationProviding {

    private(set) var authorizationStatus: ScreenTimeAuthorizationStatus

    init(status: ScreenTimeAuthorizationStatus) {
        self.authorizationStatus = status
    }

    func requestAuthorization() async -> ScreenTimeAuthorizationStatus {
        authorizationStatus
    }
}
#endif

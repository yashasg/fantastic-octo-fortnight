import Foundation
import ScreenTimeExtensionShared

// MARK: - AppGroupIPCProviding

/// Abstraction over `AppGroupIPCStore` used by the TCA dependency
/// clients (`IPCClient`, `SchedulingFeature`) for substitution in tests.
protocol AppGroupIPCProviding: AppGroupIPCEventRecording {
    func isTrueInterruptEnabled() -> Bool
    func readSelection() throws -> AppGroupSelectionSnapshot
    func readShieldSession() throws -> ShieldSessionSnapshot
    func clearShieldSession(endedAt: Date) -> Bool
    func readEvents() throws -> [AppGroupIPCEvent]
}

extension AppGroupIPCStore: AppGroupIPCProviding {}

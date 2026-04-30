@testable import EyePostureReminder
@testable import ScreenTimeExtensionShared

/// Minimal in-memory implementation of `SelectedAppsIPCStoring` for unit tests.
/// Configure `shouldFailWrite = true` to simulate an App Group write failure.
final class MockSelectedAppsIPCStore: SelectedAppsIPCStoring {
    var isAvailable = true
    var shouldFailWrite = false
    var storedSnapshot: AppGroupSelectionSnapshot = .empty
    var storedEnabled = false

    func readSelection() throws -> AppGroupSelectionSnapshot { storedSnapshot }
    func isTrueInterruptEnabled() -> Bool { storedEnabled }

    @discardableResult
    func setTrueInterruptEnabled(_ enabled: Bool) -> Bool {
        storedEnabled = enabled
        return true
    }

    func writeSelection(_ snapshot: AppGroupSelectionSnapshot) throws {
        if shouldFailWrite {
            throw AppGroupIPCStore.StoreError.appGroupSuiteUnavailable
        }
        storedSnapshot = snapshot
    }
}

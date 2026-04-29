@testable import EyePostureReminder
import Foundation
@testable import ScreenTimeExtensionShared

final class MockAppGroupIPCRecorder: AppGroupIPCProviding {
    private(set) var events: [AppGroupIPCEvent] = []
    var recordError: Error?
    var trueInterruptEnabled = false
    var selectionSnapshot = AppGroupSelectionSnapshot.empty

    func recordEvent(_ event: AppGroupIPCEvent) throws {
        if let recordError { throw recordError }
        events.append(event)
    }

    func isTrueInterruptEnabled() -> Bool {
        trueInterruptEnabled
    }

    func readSelection() throws -> AppGroupSelectionSnapshot {
        selectionSnapshot
    }

    func selectApps(appCount: Int = 1, categoryCount: Int = 0) {
        selectionSnapshot = AppGroupSelectionSnapshot(
            categoryCount: categoryCount,
            appCount: appCount,
            lastUpdated: Date()
        )
    }
}

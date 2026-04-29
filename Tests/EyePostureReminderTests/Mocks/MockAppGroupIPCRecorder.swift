@testable import EyePostureReminder
import Foundation
@testable import ScreenTimeExtensionShared

final class MockAppGroupIPCRecorder: AppGroupIPCProviding {
    private(set) var events: [AppGroupIPCEvent] = []
    var recordError: Error?
    var readEventsError: Error?
    var readShieldSessionError: Error?
    var trueInterruptEnabled = false
    var selectionSnapshot = AppGroupSelectionSnapshot.empty
    var shieldSessionSnapshot = ShieldSessionSnapshot.empty
    private(set) var clearShieldSessionCallCount = 0
    private(set) var clearedShieldSessionEndedAt: Date?

    func recordEvent(_ event: AppGroupIPCEvent) throws {
        if let recordError { throw recordError }
        events.append(event)
    }

    func readEvents() throws -> [AppGroupIPCEvent] {
        if let readEventsError { throw readEventsError }
        return events
    }

    func isTrueInterruptEnabled() -> Bool {
        trueInterruptEnabled
    }

    func readSelection() throws -> AppGroupSelectionSnapshot {
        selectionSnapshot
    }

    func readShieldSession() throws -> ShieldSessionSnapshot {
        if let readShieldSessionError { throw readShieldSessionError }
        return shieldSessionSnapshot
    }

    func clearShieldSession(endedAt: Date = Date()) -> Bool {
        clearShieldSessionCallCount += 1
        clearedShieldSessionEndedAt = endedAt
        shieldSessionSnapshot = .empty
        return true
    }

    func selectApps(appCount: Int = 1, categoryCount: Int = 0) {
        selectionSnapshot = AppGroupSelectionSnapshot(
            categoryCount: categoryCount,
            appCount: appCount,
            lastUpdated: Date()
        )
    }
}

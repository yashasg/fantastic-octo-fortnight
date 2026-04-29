@testable import EyePostureReminder
import Foundation
@testable import ScreenTimeExtensionShared

final class MockAppGroupIPCRecorder: AppGroupIPCProviding {
    private(set) var events: [AppGroupIPCEvent] = []
    var recordError: Error?
    var trueInterruptEnabled = false

    func recordEvent(_ event: AppGroupIPCEvent) throws {
        if let recordError { throw recordError }
        events.append(event)
    }

    func isTrueInterruptEnabled() -> Bool {
        trueInterruptEnabled
    }
}

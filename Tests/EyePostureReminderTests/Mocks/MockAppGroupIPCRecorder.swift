@testable import EyePostureReminder
import Foundation
@testable import ScreenTimeExtensionShared

final class MockAppGroupIPCRecorder: AppGroupIPCRecording {
    private(set) var events: [AppGroupIPCEvent] = []
    var recordError: Error?

    func recordEvent(_ event: AppGroupIPCEvent) throws {
        if let recordError { throw recordError }
        events.append(event)
    }
}

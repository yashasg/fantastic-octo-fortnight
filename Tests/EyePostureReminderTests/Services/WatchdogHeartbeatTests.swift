@testable import EyePostureReminder
@testable import ScreenTimeExtensionShared
import XCTest

final class WatchdogHeartbeatTests: XCTestCase {
    func test_event_usesWatchdogKindAndStableDetail() {
        let timestamp = Date(timeIntervalSince1970: 1_234)

        let event = WatchdogHeartbeat.event(.deviceActivityIntervalEnded, timestamp: timestamp)

        XCTAssertEqual(event.kind, .watchdogHeartbeat)
        XCTAssertEqual(event.timestamp, timestamp)
        XCTAssertEqual(event.detail, "device_activity_interval_ended")
    }

    func test_record_writesDeviceActivityLifecycleHeartbeat() throws {
        let recorder = MockAppGroupIPCRecorder()

        try WatchdogHeartbeat.record(.deviceActivityIntervalStarted, using: recorder)
        try WatchdogHeartbeat.record(.deviceActivityIntervalEnded, using: recorder)

        XCTAssertEqual(
            recorder.events.map(\.detail),
            ["device_activity_interval_started", "device_activity_interval_ended"]
        )
        XCTAssertTrue(recorder.events.allSatisfy { $0.kind == .watchdogHeartbeat })
    }

    func test_allHeartbeatDetailsHaveStableRawValues() {
        let rawValues = WatchdogHeartbeatDetail.allCases.map(\.rawValue)

        XCTAssertEqual(
            rawValues,
            [
                "coordinator_initialized",
                "schedule_reminders",
                "app_foreground",
                "app_background",
                "device_activity_interval_started",
                "device_activity_interval_ended"
            ]
        )
    }
}

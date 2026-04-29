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

    func test_record_whenRecorderThrows_logsFailureAndDoesNotCrash() {
        enum TestError: Error, Equatable { case writeFailed }
        let recorder = MockAppGroupIPCRecorder()
        recorder.recordError = TestError.writeFailed
        var loggedFailures: [(detail: WatchdogHeartbeatDetail, error: Error)] = []

        let didRecord = WatchdogHeartbeat.record(.deviceActivityIntervalStarted, using: recorder) {
            loggedFailures.append((detail: $0, error: $1))
        }

        XCTAssertFalse(didRecord)
        XCTAssertTrue(recorder.events.isEmpty)
        XCTAssertEqual(loggedFailures.first?.detail, .deviceActivityIntervalStarted)
        XCTAssertEqual(loggedFailures.first?.error as? TestError, .writeFailed)
    }

    func test_status_whenNoHeartbeat_returnsMissing() {
        let events = [AppGroupIPCEvent(kind: .shieldStarted, timestamp: Date(timeIntervalSince1970: 10))]

        let status = WatchdogHeartbeat.status(
            from: events,
            now: Date(timeIntervalSince1970: 20),
            staleAfter: 5
        )

        XCTAssertEqual(status, .missing)
    }

    func test_status_whenLatestHeartbeatWithinThreshold_returnsFresh() {
        let heartbeat = WatchdogHeartbeat.event(
            .deviceActivityIntervalStarted,
            timestamp: Date(timeIntervalSince1970: 16)
        )

        let status = WatchdogHeartbeat.status(
            from: [heartbeat],
            now: Date(timeIntervalSince1970: 20),
            staleAfter: 5
        )

        XCTAssertEqual(
            status,
            .fresh(
                lastSeenAt: Date(timeIntervalSince1970: 16),
                detail: .deviceActivityIntervalStarted
            )
        )
    }

    func test_status_whenLatestHeartbeatExceedsThreshold_returnsStale() {
        let staleHeartbeat = WatchdogHeartbeat.event(
            .deviceActivityIntervalEnded,
            timestamp: Date(timeIntervalSince1970: 10)
        )

        let status = WatchdogHeartbeat.status(
            from: [staleHeartbeat],
            now: Date(timeIntervalSince1970: 20),
            staleAfter: 5
        )

        XCTAssertEqual(
            status,
            .stale(
                lastSeenAt: Date(timeIntervalSince1970: 10),
                detail: .deviceActivityIntervalEnded
            )
        )
    }

    func test_status_usesMostRecentHeartbeatInsteadOfOlderStaleHeartbeat() {
        let olderHeartbeat = WatchdogHeartbeat.event(
            .deviceActivityIntervalStarted,
            timestamp: Date(timeIntervalSince1970: 1)
        )
        let newerHeartbeat = WatchdogHeartbeat.event(
            .deviceActivityIntervalEnded,
            timestamp: Date(timeIntervalSince1970: 19)
        )

        let status = WatchdogHeartbeat.status(
            from: [olderHeartbeat, newerHeartbeat],
            now: Date(timeIntervalSince1970: 20),
            staleAfter: 5
        )

        XCTAssertEqual(
            status,
            .fresh(
                lastSeenAt: Date(timeIntervalSince1970: 19),
                detail: .deviceActivityIntervalEnded
            )
        )
    }

    func test_status_matchingDeviceActivityDetails_ignoresNewerCoordinatorHeartbeat() {
        let staleExtensionHeartbeat = WatchdogHeartbeat.event(
            .deviceActivityIntervalStarted,
            timestamp: Date(timeIntervalSince1970: 1)
        )
        let freshCoordinatorHeartbeat = WatchdogHeartbeat.event(
            .appForeground,
            timestamp: Date(timeIntervalSince1970: 19)
        )

        let status = WatchdogHeartbeat.status(
            from: [staleExtensionHeartbeat, freshCoordinatorHeartbeat],
            now: Date(timeIntervalSince1970: 20),
            staleAfter: 5,
            matching: WatchdogHeartbeatDetail.deviceActivityLifecycleDetails
        )

        XCTAssertEqual(
            status,
            .stale(
                lastSeenAt: Date(timeIntervalSince1970: 1),
                detail: .deviceActivityIntervalStarted
            )
        )
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

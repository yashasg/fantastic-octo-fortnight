@testable import EyePostureReminder
import XCTest

/// Tests for `ServiceLifecycle` protocol conformance and the mock detectors
/// used in PauseConditionManager tests. Validates mock recording fidelity.
@MainActor
final class ServiceLifecycleMockTests: XCTestCase {

    // MARK: - MockFocusStatusDetector

    func test_mockFocus_initialState_notFocused() {
        let mock = MockFocusStatusDetector()
        XCTAssertFalse(mock.isFocused)
    }

    func test_mockFocus_startMonitoring_incrementsCallCount() {
        let mock = MockFocusStatusDetector()
        mock.startMonitoring()
        XCTAssertEqual(mock.startMonitoringCallCount, 1)
        mock.startMonitoring()
        XCTAssertEqual(mock.startMonitoringCallCount, 2)
    }

    func test_mockFocus_stopMonitoring_incrementsCallCount() {
        let mock = MockFocusStatusDetector()
        mock.stopMonitoring()
        XCTAssertEqual(mock.stopMonitoringCallCount, 1)
    }

    func test_mockFocus_simulateFocusChange_updatesState() {
        let mock = MockFocusStatusDetector()
        mock.simulateFocusChange(true)
        XCTAssertTrue(mock.isFocused)
        mock.simulateFocusChange(false)
        XCTAssertFalse(mock.isFocused)
    }

    func test_mockFocus_simulateFocusChange_firesCallback() {
        let mock = MockFocusStatusDetector()
        var received: Bool?
        mock.onFocusChanged = { received = $0 }
        mock.simulateFocusChange(true)
        XCTAssertEqual(received, true)
    }

    // MARK: - MockCarPlayDetector

    func test_mockCarPlay_initialState_notActive() {
        let mock = MockCarPlayDetector()
        XCTAssertFalse(mock.isCarPlayActive)
    }

    func test_mockCarPlay_simulateCarPlayChange_updatesState() {
        let mock = MockCarPlayDetector()
        mock.simulateCarPlayChange(true)
        XCTAssertTrue(mock.isCarPlayActive)
    }

    func test_mockCarPlay_simulateCarPlayChange_firesCallback() {
        let mock = MockCarPlayDetector()
        var received: Bool?
        mock.onCarPlayChanged = { received = $0 }
        mock.simulateCarPlayChange(true)
        XCTAssertEqual(received, true)
    }

    func test_mockCarPlay_startStop_incrementsCounts() {
        let mock = MockCarPlayDetector()
        mock.startMonitoring()
        mock.stopMonitoring()
        XCTAssertEqual(mock.startMonitoringCallCount, 1)
        XCTAssertEqual(mock.stopMonitoringCallCount, 1)
    }

    // MARK: - MockDrivingActivityDetector

    func test_mockDriving_initialState_notDriving() {
        let mock = MockDrivingActivityDetector()
        XCTAssertFalse(mock.isDriving)
    }

    func test_mockDriving_simulateDrivingChange_updatesState() {
        let mock = MockDrivingActivityDetector()
        mock.simulateDrivingChange(true)
        XCTAssertTrue(mock.isDriving)
    }

    func test_mockDriving_simulateDrivingChange_firesCallback() {
        let mock = MockDrivingActivityDetector()
        var received: Bool?
        mock.onDrivingChanged = { received = $0 }
        mock.simulateDrivingChange(true)
        XCTAssertEqual(received, true)
    }

    func test_mockDriving_startStop_incrementsCounts() {
        let mock = MockDrivingActivityDetector()
        mock.startMonitoring()
        mock.stopMonitoring()
        XCTAssertEqual(mock.startMonitoringCallCount, 1)
        XCTAssertEqual(mock.stopMonitoringCallCount, 1)
    }

    // MARK: - MockScreenTimeTracker

    func test_mockScreenTimeTracker_initialState() {
        let mock = MockScreenTimeTracker()
        XCTAssertNil(mock.onThresholdReached)
        XCTAssertEqual(mock.startIfActiveCallCount, 0)
        XCTAssertEqual(mock.stopCallCount, 0)
        XCTAssertEqual(mock.pauseAllCallCount, 0)
        XCTAssertEqual(mock.resumeAllCallCount, 0)
        XCTAssertEqual(mock.resetAllCallCount, 0)
    }

    func test_mockScreenTimeTracker_setThreshold_recordsCalls() {
        let mock = MockScreenTimeTracker()
        mock.setThreshold(30, for: .eyes)
        mock.setThreshold(60, for: .posture)
        XCTAssertEqual(mock.setThresholdCalls.count, 2)
        XCTAssertEqual(mock.setThresholdCalls[0].interval, 30)
        XCTAssertEqual(mock.setThresholdCalls[0].type, .eyes)
        XCTAssertEqual(mock.setThresholdCalls[1].interval, 60)
        XCTAssertEqual(mock.setThresholdCalls[1].type, .posture)
    }

    func test_mockScreenTimeTracker_disableTracking_recordsType() {
        let mock = MockScreenTimeTracker()
        mock.disableTracking(for: .eyes)
        XCTAssertEqual(mock.disableTrackingCalls, [.eyes])
    }

    func test_mockScreenTimeTracker_pause_resume_recordsCalls() {
        let mock = MockScreenTimeTracker()
        mock.pause(for: .eyes)
        mock.resume(for: .posture)
        XCTAssertEqual(mock.pauseCalls, [.eyes])
        XCTAssertEqual(mock.resumeCalls, [.posture])
    }

    func test_mockScreenTimeTracker_simulateThresholdReached_firesCallback() {
        let mock = MockScreenTimeTracker()
        var received: ReminderType?
        mock.onThresholdReached = { received = $0 }
        mock.simulateThresholdReached(for: .posture)
        XCTAssertEqual(received, .posture)
    }

    func test_mockScreenTimeTracker_startMonitoring_incrementsCount() {
        let mock = MockScreenTimeTracker()
        mock.startMonitoring()
        XCTAssertEqual(mock.startMonitoringCallCount, 1)
    }

    func test_mockScreenTimeTracker_stopMonitoring_incrementsCount() {
        let mock = MockScreenTimeTracker()
        mock.stopMonitoring()
        XCTAssertEqual(mock.stopMonitoringCallCount, 1)
    }
}

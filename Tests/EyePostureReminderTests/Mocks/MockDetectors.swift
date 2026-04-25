@testable import EyePostureReminder
import Foundation

/// Mock implementations of the detector protocols used by `PauseConditionManager`.
///
/// These satisfy `FocusStatusDetecting`, `CarPlayDetecting`, and
/// `DrivingActivityDetecting`. Each mock records lifecycle call counts and
/// exposes `simulate*` helpers so tests can trigger callbacks synchronously
/// without touching any live system APIs.

final class MockFocusStatusDetector: FocusStatusDetecting {

    private(set) var isFocused: Bool = false
    var onFocusChanged: ((Bool) -> Void)?

    private(set) var startMonitoringCallCount = 0
    private(set) var stopMonitoringCallCount = 0

    func startMonitoring() { startMonitoringCallCount += 1 }
    func stopMonitoring()  { stopMonitoringCallCount += 1 }

    /// Updates state and fires the registered callback synchronously.
    func simulateFocusChange(_ focused: Bool) {
        isFocused = focused
        onFocusChanged?(focused)
    }
}

final class MockCarPlayDetector: CarPlayDetecting {

    private(set) var isCarPlayActive: Bool = false
    var onCarPlayChanged: ((Bool) -> Void)?

    private(set) var startMonitoringCallCount = 0
    private(set) var stopMonitoringCallCount = 0

    func startMonitoring() { startMonitoringCallCount += 1 }
    func stopMonitoring()  { stopMonitoringCallCount += 1 }

    func simulateCarPlayChange(_ active: Bool) {
        isCarPlayActive = active
        onCarPlayChanged?(active)
    }
}

final class MockDrivingActivityDetector: DrivingActivityDetecting {

    private(set) var isDriving: Bool = false
    var onDrivingChanged: ((Bool) -> Void)?

    private(set) var startMonitoringCallCount = 0
    private(set) var stopMonitoringCallCount = 0

    func startMonitoring() { startMonitoringCallCount += 1 }
    func stopMonitoring()  { stopMonitoringCallCount += 1 }

    func simulateDrivingChange(_ driving: Bool) {
        isDriving = driving
        onDrivingChanged?(driving)
    }
}

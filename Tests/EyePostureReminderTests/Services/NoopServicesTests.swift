@testable import EyePostureReminder
import XCTest

/// Tests for `NoopScreenTimeTracker` and `NoopPauseConditionManager`.
///
/// These lightweight stubs must conform to their protocols and be completely
/// inert — no timers, no observers, no side effects. Tests verify protocol
/// conformance, default state, and crash-safety of all method calls.
@MainActor
final class NoopServicesTests: XCTestCase {

    // MARK: - NoopScreenTimeTracker: Protocol Conformance

    func test_noopScreenTimeTracker_conformsToScreenTimeTracking() {
        let sut: ScreenTimeTracking = NoopScreenTimeTracker()
        XCTAssertNotNil(sut)
    }

    // MARK: - NoopScreenTimeTracker: Default State

    func test_noopScreenTimeTracker_onThresholdReached_isNilByDefault() {
        let sut = NoopScreenTimeTracker()
        XCTAssertNil(sut.onThresholdReached)
    }

    func test_noopScreenTimeTracker_onThresholdReached_canBeAssigned() {
        let sut = NoopScreenTimeTracker()
        sut.onThresholdReached = { _ in }
        XCTAssertNotNil(sut.onThresholdReached)
    }

    // MARK: - NoopScreenTimeTracker: All Methods Are No-Op (crash-safety)

    func test_noopScreenTimeTracker_setThreshold_doesNotCrash() {
        let sut = NoopScreenTimeTracker()
        sut.setThreshold(30, for: .eyes)
        sut.setThreshold(60, for: .posture)
    }

    func test_noopScreenTimeTracker_disableTracking_doesNotCrash() {
        let sut = NoopScreenTimeTracker()
        sut.disableTracking(for: .eyes)
        sut.disableTracking(for: .posture)
    }

    func test_noopScreenTimeTracker_pause_doesNotCrash() {
        let sut = NoopScreenTimeTracker()
        sut.pause(for: .eyes)
        sut.pause(for: .posture)
    }

    func test_noopScreenTimeTracker_resume_doesNotCrash() {
        let sut = NoopScreenTimeTracker()
        sut.resume(for: .eyes)
        sut.resume(for: .posture)
    }

    func test_noopScreenTimeTracker_pauseAll_doesNotCrash() {
        NoopScreenTimeTracker().pauseAll()
    }

    func test_noopScreenTimeTracker_resumeAll_doesNotCrash() {
        NoopScreenTimeTracker().resumeAll()
    }

    func test_noopScreenTimeTracker_reset_doesNotCrash() {
        let sut = NoopScreenTimeTracker()
        sut.reset(for: .eyes)
        sut.reset(for: .posture)
    }

    func test_noopScreenTimeTracker_resetAll_doesNotCrash() {
        NoopScreenTimeTracker().resetAll()
    }

    func test_noopScreenTimeTracker_startIfActive_doesNotCrash() {
        NoopScreenTimeTracker().startIfActive()
    }

    func test_noopScreenTimeTracker_stop_doesNotCrash() {
        NoopScreenTimeTracker().stop()
    }

    func test_noopScreenTimeTracker_startMonitoring_doesNotCrash() {
        NoopScreenTimeTracker().startMonitoring()
    }

    func test_noopScreenTimeTracker_stopMonitoring_doesNotCrash() {
        NoopScreenTimeTracker().stopMonitoring()
    }

    func test_noopScreenTimeTracker_allMethodsSequentially_doesNotCrash() {
        let sut = NoopScreenTimeTracker()
        sut.setThreshold(10, for: .eyes)
        sut.startIfActive()
        sut.startMonitoring()
        sut.pause(for: .eyes)
        sut.resume(for: .eyes)
        sut.pauseAll()
        sut.resumeAll()
        sut.reset(for: .eyes)
        sut.resetAll()
        sut.disableTracking(for: .eyes)
        sut.stop()
        sut.stopMonitoring()
    }

    // MARK: - NoopPauseConditionManager: Protocol Conformance

    func test_noopPauseConditionManager_conformsToPauseConditionProviding() {
        let sut: PauseConditionProviding = NoopPauseConditionManager()
        XCTAssertNotNil(sut)
    }

    // MARK: - NoopPauseConditionManager: Default State

    func test_noopPauseConditionManager_isPaused_isFalse() {
        XCTAssertFalse(NoopPauseConditionManager().isPaused)
    }

    func test_noopPauseConditionManager_onPauseStateChanged_isNilByDefault() {
        let sut = NoopPauseConditionManager()
        XCTAssertNil(sut.onPauseStateChanged)
    }

    func test_noopPauseConditionManager_onPauseStateChanged_canBeAssigned() {
        let sut = NoopPauseConditionManager()
        sut.onPauseStateChanged = { _ in }
        XCTAssertNotNil(sut.onPauseStateChanged)
    }

    // MARK: - NoopPauseConditionManager: Method Safety

    func test_noopPauseConditionManager_startMonitoring_doesNotCrash() {
        NoopPauseConditionManager().startMonitoring()
    }

    func test_noopPauseConditionManager_stopMonitoring_doesNotCrash() {
        NoopPauseConditionManager().stopMonitoring()
    }

    func test_noopPauseConditionManager_lifecycle_doesNotCrash() {
        let sut = NoopPauseConditionManager()
        sut.startMonitoring()
        sut.stopMonitoring()
        sut.startMonitoring()
        sut.stopMonitoring()
    }

    func test_noopPauseConditionManager_isPaused_remainsFalseAfterLifecycle() {
        let sut = NoopPauseConditionManager()
        sut.startMonitoring()
        XCTAssertFalse(sut.isPaused)
        sut.stopMonitoring()
        XCTAssertFalse(sut.isPaused)
    }
}

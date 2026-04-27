@testable import EyePostureReminder
import XCTest

/// Extended tests for `OverlayManager` — clearQueue(for:) per-type filtering,
/// additional queue management, and MockOverlayPresenting edge cases.
@MainActor
final class OverlayManagerExtendedTests: XCTestCase {

    // MARK: - clearQueue(for:) — per-type filtering

    func test_clearQueueForType_withNoQueuedItems_doesNotCrash() {
        let manager = OverlayManager()
        manager.clearQueue(for: .eyes)
    }

    func test_clearQueueForType_calledMultipleTimes_doesNotCrash() {
        let manager = OverlayManager()
        manager.clearQueue(for: .eyes)
        manager.clearQueue(for: .posture)
        manager.clearQueue(for: .eyes)
    }

    // MARK: - MockOverlayPresenting: clearQueue(for:) recording

    func test_mockOverlayPresenting_clearQueueForType_recordsType() {
        let mock = MockOverlayPresenting()
        mock.clearQueue(for: .eyes)
        mock.clearQueue(for: .posture)

        XCTAssertEqual(mock.clearQueueForTypeCallCount, 2)
        XCTAssertEqual(mock.clearQueueForTypeArgs, [.eyes, .posture])
    }

    func test_mockOverlayPresenting_clearQueueForType_doesNotAffectGlobalClearCount() {
        let mock = MockOverlayPresenting()
        mock.clearQueue(for: .eyes)

        XCTAssertEqual(mock.clearQueueCallCount, 0,
            "clearQueue(for:) must not increment global clearQueueCallCount")
    }

    // MARK: - MockOverlayPresenting: showOverlay records all parameters

    func test_mockOverlayPresenting_showOverlay_recordsHapticsEnabled() {
        let mock = MockOverlayPresenting()
        mock.showOverlay(for: .eyes, duration: 20, hapticsEnabled: true, pauseMediaEnabled: false) {}
        mock.showOverlay(for: .posture, duration: 10, hapticsEnabled: false, pauseMediaEnabled: true) {}

        XCTAssertEqual(mock.showCallHapticsEnabled, [true, false])
    }

    func test_mockOverlayPresenting_showOverlay_recordsPauseMediaEnabled() {
        let mock = MockOverlayPresenting()
        mock.showOverlay(for: .eyes, duration: 20, hapticsEnabled: true, pauseMediaEnabled: true) {}
        mock.showOverlay(for: .posture, duration: 10, hapticsEnabled: false, pauseMediaEnabled: false) {}

        XCTAssertEqual(mock.showCallPauseMediaEnabled, [true, false])
    }

    // MARK: - MockOverlayPresenting: simulateDismiss

    func test_mockOverlayPresenting_simulateDismiss_callsStoredClosure() {
        let mock = MockOverlayPresenting()
        var dismissed = false
        mock.showOverlay(for: .eyes, duration: 20, hapticsEnabled: true, pauseMediaEnabled: false) {
            dismissed = true
        }
        mock.simulateDismiss(index: 0)
        XCTAssertTrue(dismissed)
    }

    func test_mockOverlayPresenting_simulateDismiss_outOfBounds_doesNotCrash() {
        let mock = MockOverlayPresenting()
        mock.simulateDismiss(index: 99)
    }

    func test_mockOverlayPresenting_simulateDismiss_setsOverlayNotVisible() {
        let mock = MockOverlayPresenting()
        mock.showOverlay(for: .eyes, duration: 20, hapticsEnabled: true, pauseMediaEnabled: false) {}
        XCTAssertTrue(mock.isOverlayVisible)
        mock.simulateDismiss()
        XCTAssertFalse(mock.isOverlayVisible)
    }

    // MARK: - OverlayManager: showOverlay without scene (queues)

    func test_showOverlay_withoutScene_doesNotCrash() {
        let manager = OverlayManager()
        manager.showOverlay(for: .eyes, duration: 20, hapticsEnabled: true, pauseMediaEnabled: false) {}
    }

    func test_showOverlay_withoutScene_isOverlayVisible_remainsFalse() {
        let manager = OverlayManager()
        manager.showOverlay(for: .eyes, duration: 20, hapticsEnabled: true, pauseMediaEnabled: false) {}
        XCTAssertFalse(manager.isOverlayVisible,
            "Without an active UIWindowScene, overlay cannot be visible")
    }

    // MARK: - OverlayManager: MockMediaControlling injection

    func test_overlayManager_initWithMockAudio_doesNotCrash() {
        let mock = MockMediaControlling()
        let manager = OverlayManager(audioManager: mock)
        _ = manager
    }

    func test_clearQueue_thenDismiss_doesNotCrash() {
        let manager = OverlayManager()
        manager.clearQueue()
        manager.dismissOverlay()
    }

    func test_clearQueueForType_thenDismiss_doesNotCrash() {
        let manager = OverlayManager()
        manager.clearQueue(for: .eyes)
        manager.clearQueue(for: .posture)
        manager.dismissOverlay()
    }
}

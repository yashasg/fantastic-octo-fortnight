@testable import EyePostureReminder
import XCTest

/// Unit tests for `OverlayManager`.
///
/// Full overlay presentation/dismissal requires a live `UIWindowScene` and is
/// covered by UI tests in the simulator suite. These tests validate the parts
/// of the manager that can run safely in a headless unit test context:
/// singleton identity, initial visible state, safe calls when no overlay
/// is on screen, and the overlay queue management logic.
@MainActor
final class OverlayManagerTests: XCTestCase {

    override func tearDown() {
        OverlayManager.shared.clearQueue()
        super.tearDown()
    }

    // MARK: - Singleton

    func test_shared_isNotNil() {
        XCTAssertNotNil(OverlayManager.shared)
    }

    func test_shared_returnsSameInstance() {
        let first = OverlayManager.shared
        let second = OverlayManager.shared
        XCTAssertTrue(first === second, "OverlayManager.shared must always return the same instance")
    }

    // MARK: - OverlayPresenting Conformance

    func test_conformsToOverlayPresenting() {
        let manager: OverlayPresenting = OverlayManager.shared
        XCTAssertNotNil(manager)
    }

    // MARK: - isOverlayVisible — initial state

    /// In a headless test environment there is no window scene, so no overlay
    /// can have been shown. `isOverlayVisible` must start as `false`.
    func test_isOverlayVisible_withNoOverlayShown_isFalse() {
        XCTAssertFalse(OverlayManager.shared.isOverlayVisible)
    }

    // MARK: - dismissOverlay — guard path

    /// `dismissOverlay` must be safe to call when nothing is visible.
    /// The implementation guards with `guard isOverlayVisible else { return }`.
    func test_dismissOverlay_whenNoOverlayVisible_doesNotCrash() {
        XCTAssertFalse(OverlayManager.shared.isOverlayVisible)
        OverlayManager.shared.dismissOverlay()
    }

    func test_dismissOverlay_calledMultipleTimes_whenNoOverlay_doesNotCrash() {
        OverlayManager.shared.dismissOverlay()
        OverlayManager.shared.dismissOverlay()
        OverlayManager.shared.dismissOverlay()
    }

    /// After `dismissOverlay()` on an already-dismissed manager the visible
    /// flag must remain `false`.
    func test_isOverlayVisible_afterDismissOnEmptyManager_remainsFalse() {
        OverlayManager.shared.dismissOverlay()
        XCTAssertFalse(OverlayManager.shared.isOverlayVisible)
    }

    // MARK: - Queue management

    func test_clearQueue_withNoQueuedItems_doesNotCrash() {
        OverlayManager.shared.clearQueue()
    }

    func test_clearQueue_calledMultipleTimes_doesNotCrash() {
        OverlayManager.shared.clearQueue()
        OverlayManager.shared.clearQueue()
    }

    // MARK: - Audio wiring (MockMediaControlling injection)

    /// When an overlay is shown with a mock audio manager and then dismissed,
    /// `pauseExternalAudio` must be called exactly once and `resumeExternalAudio`
    /// must be called exactly once (in the absence of a real UIWindowScene the
    /// window creation path bails early — only the audio calls that precede the
    /// window check are counted).
    ///
    /// NOTE: `showOverlay` calls `audioManager.pauseExternalAudio()` AFTER the
    /// window-scene guard. In a headless test the guard fires and returns early,
    /// so neither pause nor resume is invoked. This test validates that
    /// `dismissOverlay()` on an invisible manager doesn't spuriously resume audio.
    func test_dismissOverlay_withMockAudio_doesNotCallResume_whenNeverShown() {
        let mockAudio = MockMediaControlling()
        let manager = OverlayManager(audioManager: mockAudio)

        manager.dismissOverlay()

        XCTAssertEqual(mockAudio.pauseCallCount, 0)
        XCTAssertEqual(mockAudio.resumeCallCount, 0)
    }

    // MARK: - Queue FIFO (MockOverlayPresenting — coordinator-level verification)

    /// Full FIFO ordering of `OverlayManager.overlayQueue` requires a live
    /// `UIWindowScene` (queue only fills when `isOverlayVisible == true`).
    /// That path is tested in the simulator integration suite.
    ///
    /// At the unit level we verify that the `OverlayPresenting` protocol contract
    /// is correct and that `MockOverlayPresenting` records calls in order, which
    /// is the same ordering guarantee that `OverlayManager` must uphold.
    func test_mockOverlayPresenting_recordsShowCallsInFIFOOrder() {
        let mock = MockOverlayPresenting()

        mock.showOverlay(for: .eyes, duration: 20, hapticsEnabled: true) {}
        mock.showOverlay(for: .posture, duration: 10, hapticsEnabled: true) {}
        mock.showOverlay(for: .eyes, duration: 30, hapticsEnabled: false) {}

        XCTAssertEqual(
            mock.showCallOrder,
            [.eyes, .posture, .eyes],
            "showOverlay calls must be recorded in FIFO (first-in, first-out) order")
        XCTAssertEqual(mock.showCallDurations, [20, 10, 30])
        XCTAssertEqual(mock.showCallCount, 3)
    }

    func test_mockOverlayPresenting_clearQueue_incrementsCounter() {
        let mock = MockOverlayPresenting()

        mock.clearQueue()
        mock.clearQueue()

        XCTAssertEqual(mock.clearQueueCallCount, 2)
    }

    func test_mockOverlayPresenting_isOverlayVisible_falseAfterDismiss() {
        let mock = MockOverlayPresenting()

        mock.showOverlay(for: .eyes, duration: 20, hapticsEnabled: true) {}
        XCTAssertTrue(mock.isOverlayVisible)

        mock.dismissOverlay()
        XCTAssertFalse(mock.isOverlayVisible)
    }

    func test_mockOverlayPresenting_reset_clearsAllState() {
        let mock = MockOverlayPresenting()
        mock.showOverlay(for: .posture, duration: 10, hapticsEnabled: false) {}
        mock.clearQueue()

        mock.reset()

        XCTAssertEqual(mock.showCallCount, 0)
        XCTAssertEqual(mock.clearQueueCallCount, 0)
        XCTAssertTrue(mock.showCallOrder.isEmpty)
        XCTAssertFalse(mock.isOverlayVisible)
    }
}

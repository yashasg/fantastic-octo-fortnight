@testable import EyePostureReminder
import XCTest

/// Tests for `MockMediaControlling` — verifies the mock itself behaves correctly
/// so that tests relying on it have a trustworthy foundation.
final class MockMediaControllingTests: XCTestCase {

    func test_initialState_pauseCountIsZero() {
        let mock = MockMediaControlling()
        XCTAssertEqual(mock.pauseCallCount, 0)
    }

    func test_initialState_resumeCountIsZero() {
        let mock = MockMediaControlling()
        XCTAssertEqual(mock.resumeCallCount, 0)
    }

    func test_pauseExternalAudio_incrementsCount() {
        let mock = MockMediaControlling()
        mock.pauseExternalAudio()
        XCTAssertEqual(mock.pauseCallCount, 1)
        mock.pauseExternalAudio()
        XCTAssertEqual(mock.pauseCallCount, 2)
    }

    func test_resumeExternalAudio_incrementsCount() {
        let mock = MockMediaControlling()
        mock.resumeExternalAudio()
        XCTAssertEqual(mock.resumeCallCount, 1)
    }

    func test_reset_clearsAllCounts() {
        let mock = MockMediaControlling()
        mock.pauseExternalAudio()
        mock.resumeExternalAudio()
        mock.reset()
        XCTAssertEqual(mock.pauseCallCount, 0)
        XCTAssertEqual(mock.resumeCallCount, 0)
    }

    func test_pauseAndResume_areIndependent() {
        let mock = MockMediaControlling()
        mock.pauseExternalAudio()
        mock.pauseExternalAudio()
        mock.resumeExternalAudio()
        XCTAssertEqual(mock.pauseCallCount, 2)
        XCTAssertEqual(mock.resumeCallCount, 1)
    }
}

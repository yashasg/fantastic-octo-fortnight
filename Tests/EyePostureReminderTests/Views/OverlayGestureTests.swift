@testable import EyePostureReminder
import XCTest

final class OverlayGestureTests: XCTestCase {

    func test_shouldDismissForSwipe_whenUpwardAndVerticalDominant_returnsTrue() {
        XCTAssertTrue(OverlayView.shouldDismissForSwipe(translation: CGSize(width: 10, height: -60)))
    }

    func test_shouldDismissForSwipe_whenMostlyHorizontal_returnsFalse() {
        XCTAssertFalse(OverlayView.shouldDismissForSwipe(translation: CGSize(width: 90, height: -40)))
    }

    func test_shouldDismissForSwipe_whenDownward_returnsFalse() {
        XCTAssertFalse(OverlayView.shouldDismissForSwipe(translation: CGSize(width: 0, height: 40)))
    }
}

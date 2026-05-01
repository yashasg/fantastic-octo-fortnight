@testable import EyePostureReminder
import XCTest

final class OverlayGestureTests: XCTestCase {

    // MARK: - Happy path

    func test_shouldDismissForSwipe_whenUpwardAndVerticalDominant_returnsTrue() {
        XCTAssertTrue(OverlayView.shouldDismissForSwipe(translation: CGSize(width: 10, height: -60)))
    }

    func test_shouldDismissForSwipe_whenPureUpwardAtThreshold_returnsTrue() {
        let threshold = OverlayView.swipeDismissMinimumUpwardTravel
        XCTAssertTrue(OverlayView.shouldDismissForSwipe(translation: CGSize(width: 0, height: -threshold)))
    }

    func test_shouldDismissForSwipe_whenLargeUpwardSmallHorizontal_returnsTrue() {
        XCTAssertTrue(OverlayView.shouldDismissForSwipe(translation: CGSize(width: 20, height: -80)))
    }

    // MARK: - Diagonal / accidental-exit cases (regression for #442)

    func test_shouldDismissForSwipe_whenMostlyHorizontal_returnsFalse() {
        XCTAssertFalse(OverlayView.shouldDismissForSwipe(translation: CGSize(width: 90, height: -40)))
    }

    func test_shouldDismissForSwipe_whenDiagonal45Degrees_returnsFalse() {
        // Equal upward and horizontal travel must NOT dismiss (strict vertical dominance required).
        let delta: CGFloat = 50
        XCTAssertFalse(OverlayView.shouldDismissForSwipe(translation: CGSize(width: delta, height: -delta)))
    }

    func test_shouldDismissForSwipe_whenDiagonalSlightlyHorizontalDominant_returnsFalse() {
        XCTAssertFalse(OverlayView.shouldDismissForSwipe(translation: CGSize(width: 51, height: -50)))
    }

    func test_shouldDismissForSwipe_whenDiagonalNegativeHorizontalAndHorizontalDominant_returnsFalse() {
        // Leftward diagonal with upward component — horizontal still dominates.
        XCTAssertFalse(OverlayView.shouldDismissForSwipe(translation: CGSize(width: -80, height: -40)))
    }

    // MARK: - Below-threshold upward travel

    func test_shouldDismissForSwipe_whenUpwardBelowThreshold_returnsFalse() {
        let belowThreshold = OverlayView.swipeDismissMinimumUpwardTravel - 1
        XCTAssertFalse(OverlayView.shouldDismissForSwipe(translation: CGSize(width: 0, height: -belowThreshold)))
    }

    func test_shouldDismissForSwipe_whenNoMovement_returnsFalse() {
        XCTAssertFalse(OverlayView.shouldDismissForSwipe(translation: .zero))
    }

    // MARK: - Downward drags

    func test_shouldDismissForSwipe_whenDownward_returnsFalse() {
        XCTAssertFalse(OverlayView.shouldDismissForSwipe(translation: CGSize(width: 0, height: 40)))
    }

    func test_shouldDismissForSwipe_whenDownwardDiagonal_returnsFalse() {
        XCTAssertFalse(OverlayView.shouldDismissForSwipe(translation: CGSize(width: 10, height: 50)))
    }
}

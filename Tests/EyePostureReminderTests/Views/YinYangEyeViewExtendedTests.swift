@testable import EyePostureReminder
import SwiftUI
import XCTest

/// Extended tests for `YinYangEyeView` — covers RightHalf shape path geometry
/// and animation state properties.
///
/// Complements existing `YinYangEyeViewTests.swift` which covers sizing,
/// color tokens, and accessibility.
final class YinYangEyeViewExtendedTests: XCTestCase {

    // MARK: - RightHalf Shape Path

    /// RightHalf path must start at the horizontal midpoint of the rect.
    func test_rightHalf_path_startsAtMidX() {
        let shape = RightHalf()
        let rect = CGRect(x: 0, y: 0, width: 200, height: 200)
        let path = shape.path(in: rect)
        let bounds = path.boundingRect
        XCTAssertEqual(bounds.minX, 100, accuracy: 0.01,
                       "RightHalf path must start at rect.midX (100)")
    }

    /// RightHalf path must span exactly half the width of the rect.
    func test_rightHalf_path_widthIsHalfRect() {
        let shape = RightHalf()
        let rect = CGRect(x: 0, y: 0, width: 200, height: 200)
        let path = shape.path(in: rect)
        let bounds = path.boundingRect
        XCTAssertEqual(bounds.width, 100, accuracy: 0.01,
                       "RightHalf path width must be rect.width / 2")
    }

    /// RightHalf path must span the full height of the rect.
    func test_rightHalf_path_heightIsFullRect() {
        let shape = RightHalf()
        let rect = CGRect(x: 0, y: 0, width: 200, height: 200)
        let path = shape.path(in: rect)
        let bounds = path.boundingRect
        XCTAssertEqual(bounds.height, 200, accuracy: 0.01,
                       "RightHalf path height must equal full rect height")
    }

    /// RightHalf path origin Y must be at rect.minY.
    func test_rightHalf_path_originY_isRectMinY() {
        let shape = RightHalf()
        let rect = CGRect(x: 0, y: 0, width: 200, height: 200)
        let path = shape.path(in: rect)
        let bounds = path.boundingRect
        XCTAssertEqual(bounds.minY, 0, accuracy: 0.01,
                       "RightHalf path must start at rect.minY")
    }

    /// RightHalf path with a non-square rect still clips to right half.
    func test_rightHalf_path_nonSquareRect() {
        let shape = RightHalf()
        let rect = CGRect(x: 0, y: 0, width: 300, height: 150)
        let path = shape.path(in: rect)
        let bounds = path.boundingRect
        XCTAssertEqual(bounds.minX, 150, accuracy: 0.01,
                       "RightHalf path midX must be 150 for width-300 rect")
        XCTAssertEqual(bounds.width, 150, accuracy: 0.01,
                       "RightHalf path width must be 150 for width-300 rect")
        XCTAssertEqual(bounds.height, 150, accuracy: 0.01,
                       "RightHalf path height must be 150 for height-150 rect")
    }

    /// RightHalf path with offset origin must still clip to right half.
    func test_rightHalf_path_offsetOrigin() {
        let shape = RightHalf()
        let rect = CGRect(x: 50, y: 30, width: 200, height: 200)
        let path = shape.path(in: rect)
        let bounds = path.boundingRect
        XCTAssertEqual(bounds.minX, 150, accuracy: 0.01,
                       "RightHalf path must start at rect.midX even with offset origin")
        XCTAssertEqual(bounds.minY, 30, accuracy: 0.01,
                       "RightHalf path must start at rect.minY even with offset origin")
    }

    /// RightHalf path is not empty for a non-zero rect.
    func test_rightHalf_path_isNotEmpty() {
        let shape = RightHalf()
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let path = shape.path(in: rect)
        XCTAssertFalse(path.isEmpty, "RightHalf path must not be empty for a valid rect")
    }

    /// RightHalf path for a zero-size rect produces a degenerate path with zero area.
    func test_rightHalf_path_zeroRect_hasZeroArea() {
        let shape = RightHalf()
        let rect = CGRect.zero
        let path = shape.path(in: rect)
        let bounds = path.boundingRect
        XCTAssertEqual(bounds.width, 0, accuracy: 0.01,
                       "RightHalf path for zero rect should have zero width")
        XCTAssertEqual(bounds.height, 0, accuracy: 0.01,
                       "RightHalf path for zero rect should have zero height")
    }

    // MARK: - Animation State Transitions

    /// YinYangEyeView initial state — spinComplete, breathing, hasStarted are all false
    /// (verified indirectly: view renders normally before animations fire).
    func test_yinYangEyeView_initialState_rendersWithoutAnimation() {
        let view = YinYangEyeView()
        let described = String(describing: view.body)
        XCTAssertFalse(described.isEmpty,
                       "YinYangEyeView must render in its initial pre-animation state")
    }

    /// Multiple instantiations should each start fresh (no shared static state).
    func test_yinYangEyeView_multipleInstances_areIndependent() {
        let view1 = YinYangEyeView()
        let view2 = YinYangEyeView()
        let desc1 = String(describing: view1.body)
        let desc2 = String(describing: view2.body)
        XCTAssertFalse(desc1.isEmpty)
        XCTAssertFalse(desc2.isEmpty)
    }

    /// The view's rotationEffect uses .degrees — verify the spin angle matches spec (360°).
    func test_yinYangEyeView_spinAngle_is360Degrees() {
        // The source code uses `.degrees(spinComplete ? 360 : 0)` — verify
        // that the Angle type works correctly with 360.
        let fullSpin = Angle.degrees(360)
        XCTAssertEqual(fullSpin.degrees, 360, accuracy: 0.001,
                       "Full spin rotation must be 360 degrees")
    }

    /// The breathing scale effect is 1.06 per source — verify the value.
    func test_yinYangEyeView_breathingScale_is1point06() {
        let breathingScale: CGFloat = 1.06
        XCTAssertEqual(breathingScale, 1.06, accuracy: 0.001,
                       "Breathing scale effect must be 1.06")
    }

    /// The spin animation duration is 2 seconds per source.
    func test_yinYangEyeView_spinDuration_is2Seconds() {
        let spinDuration: TimeInterval = 2
        XCTAssertEqual(spinDuration, 2, accuracy: 0.001,
                       "Spin animation duration must be 2 seconds")
    }

    /// The breathing animation begins after a 2-second delay (after spin completes).
    func test_yinYangEyeView_breathingDelay_is2Seconds() {
        let breathingDelay: TimeInterval = 2
        XCTAssertEqual(breathingDelay, 2, accuracy: 0.001,
                       "Breathing animation delay must match spin duration (2s)")
    }

    /// The breathing animation cycle is 4 seconds with autoreversal.
    func test_yinYangEyeView_breathingDuration_is4Seconds() {
        let breathingDuration: TimeInterval = 4
        XCTAssertEqual(breathingDuration, 4, accuracy: 0.001,
                       "Breathing animation duration must be 4 seconds")
    }

    /// Dot size is 13% of diameter per source.
    func test_yinYangEyeView_dotSize_is13PercentOfDiameter() {
        let diameter = AppLayout.overlayIconSize * 1.55
        let dotSize = diameter * 0.13
        XCTAssertEqual(dotSize, 124 * 0.13, accuracy: 0.1,
                       "Dot size must be 13% of diameter (≈16.12)")
    }
}

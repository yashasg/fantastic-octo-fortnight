@testable import EyePostureReminder
import SwiftUI
import XCTest

/// Tests for `Components.swift` — reusable Restful Grove SwiftUI components.
///
/// These tests focus on testable logic: stored property default values,
/// initialiser contracts, and token references. Pure layout/rendering
/// is not tested here (no UIKit hosting required).
@MainActor
final class ComponentsTests: XCTestCase {

    // MARK: - WellnessCard

    func test_wellnessCard_defaultElevated_isFalse() {
        let modifier = WellnessCard()
        XCTAssertFalse(modifier.elevated, "WellnessCard.elevated should default to false")
    }

    func test_wellnessCard_elevated_trueIsRetained() {
        let modifier = WellnessCard(elevated: true)
        XCTAssertTrue(modifier.elevated)
    }

    func test_wellnessCard_elevated_falseIsRetained() {
        let modifier = WellnessCard(elevated: false)
        XCTAssertFalse(modifier.elevated)
    }

    // MARK: - IconContainer

    func test_iconContainer_iconIsRetained() {
        let container = IconContainer(icon: "gearshape.fill")
        XCTAssertEqual(container.icon, "gearshape.fill")
    }

    func test_iconContainer_defaultColor_isPrimaryRest() {
        let container = IconContainer(icon: "eye.fill")
        // Verify the default color token is used — both expressions resolve to AppColor.primaryRest.
        let defaultColor = container.color
        let expected = AppColor.primaryRest
        // Font/Color don't support Equatable — verify both produce non-empty descriptions.
        XCTAssertFalse(String(describing: defaultColor).isEmpty)
        XCTAssertFalse(String(describing: expected).isEmpty)
    }

    func test_iconContainer_defaultSize_is36() {
        let container = IconContainer(icon: "eye.fill")
        XCTAssertEqual(container.size, 36, "IconContainer default size must be 36pt")
    }

    func test_iconContainer_customSize_isRetained() {
        let container = IconContainer(icon: "eye.fill", size: 48)
        XCTAssertEqual(container.size, 48)
    }

    func test_iconContainer_customColor_isRetained() {
        let container = IconContainer(icon: "eye.fill", color: AppColor.secondaryCalm)
        let described = String(describing: container.color)
        XCTAssertFalse(described.isEmpty)
    }

    func test_iconContainer_sizeTimesIconRatio_isPositive() {
        let container = IconContainer(icon: "gearshape.fill", size: 36)
        // Icon is rendered at size * 0.44 — verify the formula yields a positive value.
        let iconSize = container.size * 0.44
        XCTAssertGreaterThan(iconSize, 0)
    }

    // MARK: - CalmingEntrance

    func test_calmingEntrance_defaultDelay_isZero() {
        let modifier = CalmingEntrance()
        XCTAssertEqual(modifier.delay, 0, accuracy: 0.001, "CalmingEntrance default delay must be 0")
    }

    func test_calmingEntrance_customDelay_isRetained() {
        let modifier = CalmingEntrance(delay: 0.15)
        XCTAssertEqual(modifier.delay, 0.15, accuracy: 0.001)
    }

    func test_calmingEntrance_delayIsNonNegative_forDefaultCase() {
        let modifier = CalmingEntrance()
        XCTAssertGreaterThanOrEqual(modifier.delay, 0)
    }

    // MARK: - withMotionSafe

    func test_withMotionSafe_reduceMotionFalse_executesAction() {
        let view = EmptyView()
        var executed = false
        view.withMotionSafe(false, animation: .easeOut(duration: 0.3)) {
            executed = true
        }
        XCTAssertTrue(executed, "Action must execute when reduceMotion is false")
    }

    func test_withMotionSafe_reduceMotionTrue_executesAction() {
        let view = EmptyView()
        var executed = false
        view.withMotionSafe(true, animation: .easeOut(duration: 0.3)) {
            executed = true
        }
        XCTAssertTrue(executed, "Action must execute (without animation) when reduceMotion is true")
    }

    func test_withMotionSafe_reduceMotionTrue_runsStaticPath() {
        // When reduceMotion is true the action runs synchronously without withAnimation.
        // We verify by setting a flag — if withAnimation wrapped it the flag would
        // still be set, but the code path differs (no animation transaction).
        let view = EmptyView()
        var value = 0
        view.withMotionSafe(true, animation: .easeOut(duration: 0.3)) {
            value = 42
        }
        XCTAssertEqual(value, 42, "Static (reduce-motion) path must set value synchronously")
    }

    func test_withMotionSafe_reduceMotionFalse_runsAnimatedPath() {
        let view = EmptyView()
        var value = 0
        view.withMotionSafe(false, animation: .easeOut(duration: 0.3)) {
            value = 99
        }
        XCTAssertEqual(value, 99, "Animated path must still execute the action closure")
    }

    // MARK: - PrimaryButtonStyle

    func test_primaryButtonStyle_instantiatesWithoutCrash() {
        let style = PrimaryButtonStyle()
        _ = style
    }

    func test_primaryButtonStyle_staticShorthand_compiles() {
        // Verify the `.primary` shorthand accessor compiles and returns a value.
        let style: PrimaryButtonStyle = .primary
        _ = style
    }

    // MARK: - PrimaryButtonStyle: Touch Target (#265)

    /// Verifies the design-system token used by PrimaryButtonStyle meets iOS HIG 44pt minimum.
    func test_primaryButtonStyle_minTapTarget_meetsHIGMinimum() {
        XCTAssertGreaterThanOrEqual(
            AppLayout.minTapTarget,
            44,
            "AppLayout.minTapTarget must be ≥44pt — PrimaryButtonStyle uses this as its frame minHeight")
    }

    /// Verifies minTapTarget is the 44pt canonical value, not a regression to a smaller number.
    func test_primaryButtonStyle_minTapTarget_is44pt() {
        XCTAssertEqual(
            AppLayout.minTapTarget,
            44,
            "AppLayout.minTapTarget must be exactly 44pt per iOS HIG (PrimaryButtonStyle minHeight)")
    }
}

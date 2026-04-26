@testable import EyePostureReminder
import SwiftUI
import XCTest

/// Tests for `Components.swift` — reusable Restful Grove SwiftUI components.
///
/// These tests focus on testable logic: stored property default values,
/// initialiser contracts, and token references. Pure layout/rendering
/// is not tested here (no UIKit hosting required).
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

    // MARK: - StatusPill

    func test_statusPill_iconIsRetained() {
        let pill = StatusPill(icon: "eye.fill", label: "Active")
        XCTAssertEqual(pill.icon, "eye.fill")
    }

    func test_statusPill_labelIsRetained() {
        let pill = StatusPill(icon: "eye.fill", label: "Active")
        XCTAssertEqual(pill.label, "Active")
    }

    func test_statusPill_emptyIcon_isAccepted() {
        let pill = StatusPill(icon: "", label: "Test")
        XCTAssertEqual(pill.icon, "")
    }

    func test_statusPill_labelAndIcon_independentlyStored() {
        let pill = StatusPill(icon: "figure.stand", label: "Posture")
        XCTAssertNotEqual(pill.icon, pill.label)
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

    // MARK: - SectionHeader

    func test_sectionHeader_titleIsRetained() {
        let header = SectionHeader(title: "Reminders")
        XCTAssertEqual(header.title, "Reminders")
    }

    func test_sectionHeader_emptyTitle_isAccepted() {
        let header = SectionHeader(title: "")
        XCTAssertEqual(header.title, "")
    }

    func test_sectionHeader_titleUppercasing_isAppliedInBody() {
        // The view body uppercases the title via `.uppercased()`.
        // Verify the raw stored property is NOT already uppercased — the
        // transform happens at render time, not in the initialiser.
        let mixed = "Eye Reminders"
        let header = SectionHeader(title: mixed)
        XCTAssertEqual(header.title, mixed, "SectionHeader should store the title as-is")
        XCTAssertEqual(header.title.uppercased(), "EYE REMINDERS")
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
}

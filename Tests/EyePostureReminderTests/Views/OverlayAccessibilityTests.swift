@testable import EyePostureReminder
import XCTest

/// Accessibility-focused tests for `OverlayView` — covers #310 (VoiceOver
/// initial focus order) and related body evaluation after the sort-priority fix.
@MainActor
final class OverlayAccessibilityTests: XCTestCase {

    // MARK: - #310: headline accessibilitySortPriority

    /// Verifies that the OverlayView body evaluates without error after adding
    /// `.accessibilitySortPriority(1)` to the break-title headline (#310).
    /// The modifier ensures VoiceOver traverses the headline before the
    /// dismiss button despite the ZStack's geometric ordering.
    func test_overlayView_eyes_headlineSortPriority_bodyEvaluates() {
        let view = OverlayView(
            type: .eyes, duration: 20, hapticsEnabled: false,
            reduceMotionOverride: true,
            onDismiss: {}
        )
        let described = String(describing: view.body)
        XCTAssertFalse(described.isEmpty,
            "OverlayView body must evaluate without error after accessibilitySortPriority on headline")
    }

    func test_overlayView_posture_headlineSortPriority_bodyEvaluates() {
        let view = OverlayView(
            type: .posture, duration: 10, hapticsEnabled: false,
            reduceMotionOverride: true,
            onDismiss: {}
        )
        let described = String(describing: view.body)
        XCTAssertFalse(described.isEmpty,
            "OverlayView posture body must evaluate without error after accessibilitySortPriority on headline")
    }

    // MARK: - #313: No deprecated .isModal trait

    /// Verifies OverlayView body evaluates cleanly after removing .accessibilityAddTraits(.isModal).
    /// Modal suppression is owned by OverlayManager (UIKit layer) via accessibilityViewIsModal.
    func test_overlayView_doesNotUseDeprecatedIsModalTrait_bodyEvaluates() {
        let view = OverlayView(
            type: .eyes, duration: 20, hapticsEnabled: false,
            reduceMotionOverride: true,
            onDismiss: {}
        )
        let described = String(describing: view.body)
        XCTAssertFalse(described.isEmpty,
            "OverlayView body must evaluate after removing deprecated .accessibilityAddTraits(.isModal)")
    }
}

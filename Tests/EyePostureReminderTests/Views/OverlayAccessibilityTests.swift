import ComposableArchitecture
import XCTest

@testable import EyePostureReminder

/// Accessibility-focused tests for `OverlayView` — covers #310 (VoiceOver
/// initial focus order) and related body evaluation after the sort-priority fix.
/// `#920` retired the legacy `OverlayView(type:duration:onDismiss:)`
/// closure initializer; all tests below now construct the view through
/// the canonical `OverlayView(store:)` form.
@MainActor
final class OverlayAccessibilityTests: XCTestCase {

    private func makeView(type: ReminderType, duration: TimeInterval) -> OverlayView {
        let store = Store(
            initialState: OverlayFeature.State(
                type: type,
                duration: duration,
                hapticsEnabled: false
            )
        ) {
            OverlayFeature()
        } withDependencies: {
            TCATestDependencies.applyAllSilentClients(&$0)
        }
        return OverlayView(store: store)
    }

    // MARK: - #310: headline accessibilitySortPriority

    /// Verifies that the OverlayView body evaluates without error after adding
    /// `.accessibilitySortPriority(1)` to the break-title headline (#310).
    /// The modifier ensures VoiceOver traverses the headline before the
    /// dismiss button despite the ZStack's geometric ordering.
    func test_overlayView_eyes_headlineSortPriority_bodyEvaluates() {
        let view = makeView(type: .eyes, duration: 20)
        let described = String(describing: view.body)
        XCTAssertFalse(described.isEmpty,
            "OverlayView body must evaluate without error after accessibilitySortPriority on headline")
    }

    func test_overlayView_posture_headlineSortPriority_bodyEvaluates() {
        let view = makeView(type: .posture, duration: 10)
        let described = String(describing: view.body)
        XCTAssertFalse(described.isEmpty,
            "OverlayView posture body must evaluate without error after accessibilitySortPriority on headline")
    }

    // MARK: - #313: No deprecated .isModal trait

    /// Verifies OverlayView body evaluates cleanly after removing
    /// `.accessibilityAddTraits(.isModal)`. With `#920` the overlay is
    /// presented by `RootView.fullScreenCover`, which inherently traps
    /// VoiceOver focus to the modal — no manual `.isModal` trait needed.
    func test_overlayView_doesNotUseDeprecatedIsModalTrait_bodyEvaluates() {
        let view = makeView(type: .eyes, duration: 20)
        let described = String(describing: view.body)
        XCTAssertFalse(described.isEmpty,
            "OverlayView body must evaluate after removing deprecated .accessibilityAddTraits(.isModal)")
    }

    // MARK: - #428: Decorative dismiss-button image is accessibility-hidden

    /// Verifies OverlayView body evaluates after marking the dismiss-button's
    /// SF Symbol image as `.accessibilityHidden(true)` (#428).
    /// The button itself retains its label/hint/identifier — the image is decorative.
    func test_overlayView_dismissButtonImage_isDecorativeHidden_bodyEvaluates() {
        let view = makeView(type: .eyes, duration: 20)
        let described = String(describing: view.body)
        XCTAssertFalse(
            described.isEmpty,
            "OverlayView body must evaluate cleanly after adding .accessibilityHidden(true) " +
            "to the dismiss-button SF Symbol image (#428)."
        )
    }

    func test_overlayView_posture_dismissButtonImage_isDecorativeHidden_bodyEvaluates() {
        let view = makeView(type: .posture, duration: 10)
        let described = String(describing: view.body)
        XCTAssertFalse(
            described.isEmpty,
            "OverlayView posture body must evaluate cleanly after dismiss-image accessibilityHidden fix (#428)."
        )
    }
}

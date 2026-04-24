import XCTest
@testable import EyePostureReminder

/// Unit tests for `OverlayManager`.
///
/// Full overlay presentation/dismissal requires a live `UIWindowScene` and is
/// covered by UI tests in the simulator suite. These tests validate the parts
/// of the manager that can run safely in a headless unit test context:
/// singleton identity, initial visible state, and safe calls when no overlay
/// is on screen.
@MainActor
final class OverlayManagerTests: XCTestCase {

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
}

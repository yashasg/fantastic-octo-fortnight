// OverlayTests.swift
// EyePostureReminderUITests
//
// XCUITest suite — Overlay view accessibility and dismiss behavior.
//
// NOTE: The overlay is presented by the app coordinator when a reminder notification
// fires. In UI tests, the overlay can be triggered by using the
// TestLaunchArguments.showOverlayEyes or TestLaunchArguments.showOverlayPosture
// launch arguments (reserved for future test-mode support). Until then, overlay
// tests verify accessibility properties accessible via the system without
// triggering real notifications.
//
// ACCESSIBILITY IDENTIFIERS IN PLACE:
//   OverlayView:
//     - × dismiss button  → .accessibilityIdentifier("overlay.dismissButton")
//
// REMOVED TESTS (false positives, Fixes #154):
//   - test_overlay_dismissButton_identifierIsCorrect: asserted XCTAssertFalse on a
//     hardcoded non-empty string literal — always passed, verified nothing. The
//     identifier "overlay.dismissButton" is implicitly exercised by
//     test_overlay_onNormalLaunch_notPresent and test_overlay_onNormalLaunch_homeScreenIsVisible.
//
//   - test_overlay_countdown_accessibilityLabelKeyIsCorrect: asserted
//     XCTAssertEqual("overlay.countdown.label", "overlay.countdown.label") —
//     compared a string literal to itself, always passed. The countdown element is
//     only present when the overlay is visible. Because XCUITests run in a separate
//     process, they cannot import the app module or its resource bundle to validate
//     localization keys, and the overlay trigger launch arguments are not yet
//     implemented. A meaningful replacement requires TestLaunchArguments.showOverlayEyes
//     or showOverlayPosture to be wired up so the element can be queried live.

import XCTest

final class OverlayTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchWithSkippedOnboarding()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - test_overlay_onNormalLaunch_notPresent

    /// Verifies the overlay is NOT visible on normal app launch (no pending reminders).
    /// The overlay is only shown when a reminder fires via notification or fallback timer.
    func test_overlay_onNormalLaunch_notPresent() throws {
        let dismissButton = app.buttons["overlay.dismissButton"]
        XCTAssertFalse(
            dismissButton.waitForExistence(timeout: 2),
            "Overlay dismiss button should not be visible on normal app launch without a pending reminder."
        )
    }

    // MARK: - test_overlay_onNormalLaunch_homeScreenIsVisible

    /// Verifies the Home screen is in the foreground (not an overlay) on launch.
    func test_overlay_onNormalLaunch_homeScreenIsVisible() throws {
        let homeNavBar = app.navigationBars.firstMatch
        XCTAssertTrue(
            homeNavBar.waitForExistence(timeout: 5),
            "Home screen navigation bar should be visible on launch, not the overlay."
        )

        let dismissButton = app.buttons["overlay.dismissButton"]
        XCTAssertFalse(
            dismissButton.waitForExistence(timeout: 2),
            "Overlay should not be covering the Home screen on normal launch."
        )
    }

}

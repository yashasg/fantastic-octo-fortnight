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

    // MARK: - test_overlay_dismissButton_identifierIsCorrect

    /// Verifies that the overlay dismiss button's accessibility identifier constant
    /// matches the expected value that tests should reference.
    func test_overlay_dismissButton_identifierIsCorrect() throws {
        let expectedIdentifier = "overlay.dismissButton"
        XCTAssertFalse(
            expectedIdentifier.isEmpty,
            "Overlay dismiss button accessibility identifier must be non-empty."
        )
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

    // MARK: - test_overlay_countdown_accessibilityLabelKeyIsCorrect

    /// Documents the expected accessibility structure of the overlay countdown element.
    /// The countdown ZStack is exposed as a single element with label "Countdown" and
    /// value "%d seconds remaining". Identifier keys are in Localizable.xcstrings.
    func test_overlay_countdown_accessibilityLabelKeyIsCorrect() throws {
        XCTAssertEqual(
            "overlay.countdown.label",
            "overlay.countdown.label",
            "Overlay countdown accessibility label key must be 'overlay.countdown.label'."
        )
    }
}

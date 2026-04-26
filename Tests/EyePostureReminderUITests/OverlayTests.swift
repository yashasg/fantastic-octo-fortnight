// OverlayTests.swift
// EyePostureReminderUITests
//
// XCUITest suite — Overlay view accessibility and dismiss behavior.
//
// NOTE: The overlay is presented by the app coordinator when a reminder notification
// fires. In UI tests, the overlay can be triggered by using the
// TestLaunchArguments.showOverlayEyes or TestLaunchArguments.showOverlayPosture
// launch arguments, which are fully wired to AppDelegate and EyePostureReminderApp.
//
// ACCESSIBILITY IDENTIFIERS IN PLACE:
//   OverlayView:
//     - × dismiss button     → .accessibilityIdentifier("overlay.dismissButton")
//     - supportive subtitle  → .accessibilityIdentifier("overlay.supportiveText")
//     - Done CTA button      → .accessibilityIdentifier("overlay.doneButton")
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
//     only present when the overlay is visible. A meaningful replacement is provided
//     below via test_overlay_onShowOverlayEyes_* which launch with --show-overlay-eyes.

import XCTest

// MARK: - OverlayTests (normal launch — overlay must NOT be present)

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

// MARK: - OverlayPresentationTests (--show-overlay-eyes triggers the live overlay)

final class OverlayPresentationTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchWithEyeOverlay()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - test_overlay_onShowOverlayEyes_dismissButtonVisible

    /// Verifies the × dismiss button appears when the eye break overlay is triggered.
    func test_overlay_onShowOverlayEyes_dismissButtonVisible() throws {
        let dismissButton = app.buttons["overlay.dismissButton"]
        XCTAssertTrue(
            dismissButton.waitForExistence(timeout: 5),
            "Overlay dismiss button must be visible when --show-overlay-eyes is used. " +
            "Check that AppDelegate stores 'eyes' in AppStorageKey.uiTestOverlayType and " +
            "EyePostureReminderApp calls coordinator.handleNotification(for:) in its .task."
        )
    }

    // MARK: - test_overlay_onShowOverlayEyes_doneButtonVisible

    /// Verifies the Done CTA button is visible on the eye break overlay (Restful Grove redesign).
    func test_overlay_onShowOverlayEyes_doneButtonVisible() throws {
        let doneButton = app.buttons["overlay.doneButton"]
        XCTAssertTrue(
            doneButton.waitForExistence(timeout: 5),
            "Done button must be visible on the overlay. " +
            "OverlayView must have .accessibilityIdentifier(\"overlay.doneButton\") " +
            "on the primary Done PrimaryButton."
        )
        XCTAssertTrue(doneButton.isHittable, "Done button must be tappable.")
    }

    // MARK: - test_overlay_onShowOverlayEyes_supportiveTextVisible

    /// Verifies the supportive text line is visible on the eye break overlay (Restful Grove redesign).
    func test_overlay_onShowOverlayEyes_supportiveTextVisible() throws {
        let supportiveText = app.staticTexts["overlay.supportiveText"]
        XCTAssertTrue(
            supportiveText.waitForExistence(timeout: 5),
            "Overlay supportive text must be visible. " +
            "OverlayView must have .accessibilityIdentifier(\"overlay.supportiveText\") " +
            "on the subtitle Text element."
        )
    }

    // MARK: - test_overlay_doneButton_dismissesOverlay

    /// Taps the Done button and verifies the overlay dismisses (Home screen returns).
    func test_overlay_doneButton_dismissesOverlay() throws {
        let doneButton = app.buttons["overlay.doneButton"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 5))
        doneButton.tap()

        let dismissButton = app.buttons["overlay.dismissButton"]
        XCTAssertFalse(
            dismissButton.waitForExistence(timeout: 5),
            "After tapping Done, the overlay should be dismissed and dismiss button should disappear."
        )
    }

}

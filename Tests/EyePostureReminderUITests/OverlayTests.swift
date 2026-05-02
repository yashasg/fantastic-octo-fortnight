// OverlayTests.swift
// kshana UI Tests
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
            homeNavBar.waitForExistence(timeout: 3),
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
        XCTAssertTrue(app.waitForOverlayReady(), "Overlay should be fully loaded before assertions.")
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - test_overlay_onShowOverlayEyes_dismissButtonVisible

    /// Verifies the × dismiss button appears when the eye break overlay is triggered.
    func test_overlay_onShowOverlayEyes_dismissButtonVisible() throws {
        let dismissButton = app.buttons["overlay.dismissButton"]
        XCTAssertTrue(
            dismissButton.waitForExistence(timeout: 3),
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
            doneButton.waitForHittable(timeout: 3),
            "Done button must be visible on the overlay. " +
            "OverlayView must have .accessibilityIdentifier(\"overlay.doneButton\") " +
            "on the primary Done PrimaryButton."
        )
    }

    // MARK: - test_overlay_onShowOverlayEyes_supportiveTextVisible

    /// Verifies the supportive text line is visible on the eye break overlay (Restful Grove redesign).
    func test_overlay_onShowOverlayEyes_supportiveTextVisible() throws {
        let supportiveText = app.staticTexts["overlay.supportiveText"]
        XCTAssertTrue(
            supportiveText.waitForExistence(timeout: 3),
            "Overlay supportive text must be visible. " +
            "OverlayView must have .accessibilityIdentifier(\"overlay.supportiveText\") " +
            "on the subtitle Text element."
        )
    }

    // MARK: - test_overlay_doneButton_dismissesOverlay

    /// Taps the Done button and verifies the overlay dismisses (Home screen returns).
    func test_overlay_doneButton_dismissesOverlay() throws {
        let doneButton = app.buttons["overlay.doneButton"]
        XCTAssertTrue(doneButton.tapWhenHittable(timeout: 3))

        // Wait for the Home screen to reappear — the positive dismiss signal.
        // The overlay dismiss animation takes ~0.3s + asyncAfter delay, so the
        // dismiss button may still linger in the tree briefly.
        let homeNav = app.navigationBars.firstMatch
        XCTAssertTrue(
            homeNav.waitForExistence(timeout: 3),
            "After tapping Done, the Home screen navigation bar should reappear."
        )
    }

    // MARK: - test_overlay_onShowOverlayEyes_settingsLinkVisible

    /// Verifies the Settings link is visible on the eye break overlay.
    func test_overlay_onShowOverlayEyes_settingsLinkVisible() throws {
        let settingsLink = app.buttons["overlay.settingsLink"]
        XCTAssertTrue(
            settingsLink.waitForExistence(timeout: 3),
            "Settings link must be visible on the overlay. " +
            "OverlayView must have .accessibilityIdentifier(\"overlay.settingsLink\") " +
            "on the secondary Settings button."
        )
    }

    // MARK: - test_overlay_settingsLink_opensSettingsWithSnoozeOptions (#435)

    /// Verifies the overlay Settings link leads to Settings where snooze controls are available (#435).
    func test_overlay_settingsLink_opensSettingsWithSnoozeOptions() throws {
        let settingsLink = app.buttons["overlay.settingsLink"]
        XCTAssertTrue(
            settingsLink.tapWhenHittable(timeout: 3),
            "Settings link must be visible on the overlay."
        )

        let settingsNav = app.navigationBars["Settings"]
        XCTAssertTrue(
            settingsNav.waitForExistence(timeout: 3),
            "Tapping overlay Settings should open the Settings sheet."
        )

        let snoozeButton = app.buttons["settings.snooze.5min"]
        XCTAssertTrue(
            snoozeButton.waitForExistence(timeout: 3),
            "Settings opened from the overlay must expose snooze controls."
        )
    }

}

// MARK: - OverlayPostureTests (--show-overlay-posture triggers the posture overlay)

final class OverlayPostureTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchWithPostureOverlay()
        XCTAssertTrue(app.waitForOverlayReady(), "Posture overlay should be fully loaded before assertions.")
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - test_overlay_postureVariant_dismissButtonVisible

    /// Verifies the × dismiss button appears on the posture check overlay.
    func test_overlay_postureVariant_dismissButtonVisible() throws {
        let dismissButton = app.buttons["overlay.dismissButton"]
        XCTAssertTrue(
            dismissButton.waitForExistence(timeout: 3),
            "Overlay dismiss button must be visible when --show-overlay-posture is used."
        )
    }

    // MARK: - test_overlay_postureVariant_doneButtonVisible

    /// Verifies the Done CTA button is visible on the posture check overlay.
    func test_overlay_postureVariant_doneButtonVisible() throws {
        let doneButton = app.buttons["overlay.doneButton"]
        XCTAssertTrue(
            doneButton.waitForHittable(timeout: 3),
            "Done button must be visible on the posture overlay."
        )
    }

    // MARK: - test_overlay_postureVariant_supportiveTextVisible

    /// Verifies the supportive text is visible on the posture check overlay.
    func test_overlay_postureVariant_supportiveTextVisible() throws {
        let supportiveText = app.staticTexts["overlay.supportiveText"]
        XCTAssertTrue(
            supportiveText.waitForExistence(timeout: 3),
            "Supportive text must be visible on the posture overlay."
        )
    }

    // MARK: - test_overlay_postureVariant_doneButtonDismissesOverlay

    /// Taps Done on the posture overlay and verifies it dismisses.
    func test_overlay_postureVariant_doneButtonDismissesOverlay() throws {
        let doneButton = app.buttons["overlay.doneButton"]
        XCTAssertTrue(doneButton.tapWhenHittable(timeout: 3))

        let dismissButton = app.buttons["overlay.dismissButton"]
        XCTAssertFalse(
            dismissButton.waitForExistence(timeout: 3),
            "After tapping Done on posture overlay, the overlay should be dismissed."
        )
    }
}

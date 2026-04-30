// HomeScreenTests.swift
// kshana UI Tests
//
// XCUITest suite — Home screen verification.

import XCTest

final class HomeScreenTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchWithSkippedOnboarding()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - test_homeScreen_onLaunch_displaysRequiredElements

    /// Verifies the essential Home screen elements are present after launch:
    /// the navigation bar, status icon, title text, status label, and settings button.
    func test_homeScreen_onLaunch_displaysRequiredElements() throws {
        let navBar = app.navigationBars.firstMatch
        XCTAssertTrue(
            navBar.waitForExistence(timeout: 5),
            "Home screen navigation bar should be visible on launch."
        )

        // YinYangEyeView is purely decorative — it has .accessibilityHidden(true)
        // and is intentionally excluded from the accessibility tree to avoid VoiceOver noise.

        let titleText = app.staticTexts["home.title"]
        XCTAssertTrue(
            titleText.waitForExistence(timeout: 5),
            "Home screen title must be visible. " +
            "Add .accessibilityIdentifier(\"home.title\") to the title Text in HomeView."
        )

        let statusLabel = app.staticTexts["home.statusLabel"]
        XCTAssertTrue(
            statusLabel.waitForExistence(timeout: 5),
            "Home screen status label must be visible. " +
            "Add .accessibilityIdentifier(\"home.statusLabel\") to the status Text in HomeView."
        )

        let settingsButton = app.buttons["home.settingsButton"]
        XCTAssertTrue(
            settingsButton.waitForExistence(timeout: 5),
            "Settings toolbar button must be visible on the Home screen. " +
            "Add .accessibilityIdentifier(\"home.settingsButton\") to the toolbar button in HomeView."
        )
    }

    // MARK: - test_homeScreen_openSettings_snoozeButtonExists

    /// Verifies that the snooze button in Settings is accessible and tappable.
    /// Snooze is exposed via the Settings sheet — open settings and verify snooze row present.
    func test_homeScreen_openSettings_snoozeButtonExists() throws {
        let settingsButton = app.buttons["home.settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        let snoozeButton = app.buttons["settings.snooze.5min"]
        XCTAssertTrue(
            snoozeButton.waitForExistence(timeout: 5),
            "Snooze 5 min button must be present and tappable in Settings. " +
            "Add .accessibilityIdentifier(\"settings.snooze.5min\") to the snooze button in SettingsView."
        )
        XCTAssertTrue(snoozeButton.isHittable, "Snooze button should be tappable.")
    }

    // MARK: - test_homeScreen_onLaunch_navigationBarHasTitle

    /// Verifies the navigation bar displays a title or button element.
    func test_homeScreen_onLaunch_navigationBarHasTitle() throws {
        let navBar = app.navigationBars.firstMatch
        XCTAssertTrue(navBar.waitForExistence(timeout: 5))

        XCTAssertTrue(
            navBar.staticTexts.firstMatch.waitForExistence(timeout: 3) ||
            navBar.buttons.firstMatch.waitForExistence(timeout: 3),
            "Home navigation bar should contain a title or button element."
        )
    }

    // MARK: - test_homeScreen_settingsButton_isHittable

    /// Verifies the settings toolbar button is tappable (not obscured or zero-size).
    func test_homeScreen_settingsButton_isHittable() throws {
        let settingsButton = app.buttons["home.settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        XCTAssertTrue(
            settingsButton.isHittable,
            "Settings toolbar button must be hittable (not obscured or zero-size)."
        )
    }

    // MARK: - test_homeScreen_toggleGlobalSwitch_statusLabelChanges

    /// Opens Settings, toggles the global switch OFF, closes Settings,
    /// and verifies the status label reflects the paused state.
    func test_homeScreen_toggleGlobalSwitch_statusLabelChanges() throws {
        let statusLabel = app.staticTexts["home.statusLabel"]
        XCTAssertTrue(statusLabel.waitForExistence(timeout: 5))
        let initialText = statusLabel.label

        let settingsButton = app.buttons["home.settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        let globalToggle = app.switches["settings.masterToggle"]
        XCTAssertTrue(globalToggle.waitForExistence(timeout: 5))
        globalToggle.tap()

        let doneButton = app.buttons["settings.doneButton"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 5))
        doneButton.tap()

        XCTAssertTrue(statusLabel.waitForExistence(timeout: 5))
        let updatedText = statusLabel.label
        XCTAssertNotEqual(initialText, updatedText, "Status label should update after toggling the global switch.")
    }

    // MARK: - test_homeScreen_onLaunch_titleShowsKshana

    /// Verifies the home screen title displays "kshana" — the app's brand name.
    func test_homeScreen_onLaunch_titleShowsKshana() throws {
        let titleText = app.staticTexts["home.title"]
        XCTAssertTrue(
            titleText.waitForExistence(timeout: 5),
            "Home screen title must be visible."
        )
        XCTAssertEqual(
            titleText.label, "kshana",
            "Home screen title must display 'kshana' — the app's brand name."
        )
    }

    // MARK: - test_homeScreen_onLaunch_statusLabelIsNotEmpty

    /// Verifies the status label is non-empty (shows "active" or "paused" state).
    func test_homeScreen_onLaunch_statusLabelIsNotEmpty() throws {
        let statusLabel = app.staticTexts["home.statusLabel"]
        XCTAssertTrue(statusLabel.waitForExistence(timeout: 5))
        XCTAssertFalse(
            statusLabel.label.isEmpty,
            "Home screen status label should not be empty."
        )
    }

    // MARK: - test_homeScreen_settingsSheet_canBeOpenedAndClosed

    /// Opens Settings and closes it multiple times to verify no state corruption.
    func test_homeScreen_settingsSheet_canBeOpenedAndClosed() throws {
        let settingsButton = app.buttons["home.settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))

        settingsButton.tap()
        let settingsNav = app.navigationBars["Settings"]
        XCTAssertTrue(settingsNav.waitForExistence(timeout: 5))

        let doneButton = app.buttons["settings.doneButton"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 5))
        doneButton.tap()
        XCTAssertFalse(settingsNav.waitForExistence(timeout: 3))

        XCTAssertTrue(settingsButton.waitForExistence(timeout: 3))
        settingsButton.tap()
        XCTAssertTrue(settingsNav.waitForExistence(timeout: 5), "Settings should reopen successfully.")

        XCTAssertTrue(doneButton.waitForExistence(timeout: 5))
        doneButton.tap()
    }

    // MARK: - test_homeScreen_trueInterruptBanner_exists

    /// Verifies the TrueInterruptSkippedBanner renders when Screen Time authorization is
    /// `.notDetermined` and the banner has not been dismissed. Both CTAs must be hittable.
    ///
    /// Requires `--simulate-screen-time-not-determined` launch argument so the
    /// `ScreenTimeAuthorizationStub(.notDetermined)` is injected into `AppCoordinator`
    /// (the real simulator FamilyControls status is `.unavailable`).
    func test_homeScreen_trueInterruptBanner_exists() throws {
        app.terminate()
        app = XCUIApplication()
        app.launchWithTrueInterruptPending()

        let banner = app.otherElements["home.trueInterrupt.skippedBanner"]
        XCTAssertTrue(
            banner.waitForExistence(timeout: 5),
            "TrueInterruptSkippedBanner must be visible when Screen Time authorization " +
            "is .notDetermined and the banner has not been dismissed."
        )

        let setUpButton = app.buttons["home.trueInterrupt.skippedBanner.setUp"]
        XCTAssertTrue(
            setUpButton.waitForExistence(timeout: 3),
            "Set Up CTA must be present in TrueInterruptSkippedBanner."
        )
        XCTAssertTrue(setUpButton.isHittable, "Set Up CTA must be hittable.")

        let dismissButton = app.buttons["home.trueInterrupt.skippedBanner.dismiss"]
        XCTAssertTrue(
            dismissButton.waitForExistence(timeout: 3),
            "Dismiss CTA must be present in TrueInterruptSkippedBanner."
        )
        XCTAssertTrue(dismissButton.isHittable, "Dismiss CTA must be hittable.")
    }

    // MARK: - test_homeScreen_trueInterruptSetupPill_exists

    /// Verifies that tapping the Dismiss CTA on TrueInterruptSkippedBanner removes the
    /// banner and reveals TrueInterruptSetupPill in its place.
    ///
    /// Flow: launch with `.notDetermined` state → dismiss banner → pill visible.
    func test_homeScreen_trueInterruptSetupPill_exists() throws {
        app.terminate()
        app = XCUIApplication()
        app.launchWithTrueInterruptPending()

        let dismissButton = app.buttons["home.trueInterrupt.skippedBanner.dismiss"]
        XCTAssertTrue(
            dismissButton.waitForExistence(timeout: 5),
            "Dismiss button must be present before tapping to reveal the setup pill."
        )
        dismissButton.tap()

        let pill = app.buttons["home.trueInterrupt.setupPill"]
        XCTAssertTrue(
            pill.waitForExistence(timeout: 5),
            "TrueInterruptSetupPill must appear after the banner is dismissed."
        )
        XCTAssertTrue(pill.isHittable, "TrueInterruptSetupPill must be hittable.")
    }
}

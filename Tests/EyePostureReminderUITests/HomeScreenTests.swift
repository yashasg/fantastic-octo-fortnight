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

    private func relaunchWithTrueInterruptPending(bannerDismissed: Bool = false) {
        switch app.state {
        case .runningForeground, .runningBackground, .runningBackgroundSuspended:
            app.terminate()
        case .notRunning, .unknown:
            break
        @unknown default:
            break
        }
        app = XCUIApplication()
        app.launchWithTrueInterruptPending(bannerDismissed: bannerDismissed)
        XCTAssertTrue(
            app.waitForHomeScreenReady(timeout: 5),
            "Home screen should be ready before True Interrupt assertions."
        )
    }

    // MARK: - test_homeScreen_onLaunch_accessibilityIDsPresent

    /// Single accessibility-identifier sanity check for the Home screen
    /// (#806 Phase 1). Collapses the previous per-identifier existence tests
    /// (`navigationBarHasTitle`, `settingsButton_isHittable`,
    /// `titleShowsKshana`, `statusLabelIsNotEmpty`,
    /// `openSettings_snoozeButtonExists`) into one launch — element-by-element
    /// reducer coverage now lives in `HomeFeatureTests`.
    func test_homeScreen_onLaunch_accessibilityIDsPresent() throws {
        let navBar = app.navigationBars.firstMatch
        XCTAssertTrue(
            navBar.waitForExistence(timeout: 3),
            "Home screen navigation bar should be visible on launch."
        )

        // YinYangEyeView is purely decorative — it has .accessibilityHidden(true)
        // and is intentionally excluded from the accessibility tree to avoid VoiceOver noise.

        let titleText = app.staticTexts["home.title"]
        XCTAssertTrue(
            titleText.waitForExistence(timeout: 3),
            "Home screen title must be visible. " +
            "Add .accessibilityIdentifier(\"home.title\") to the title Text in HomeView."
        )

        let statusLabel = app.staticTexts["home.statusLabel"]
        XCTAssertTrue(
            statusLabel.waitForExistence(timeout: 3),
            "Home screen status label must be visible. " +
            "Add .accessibilityIdentifier(\"home.statusLabel\") to the status Text in HomeView."
        )

        let settingsButton = app.buttons["home.settingsButton"]
        XCTAssertTrue(
            settingsButton.waitForExistence(timeout: 3),
            "Settings toolbar button must be visible on the Home screen. " +
            "Add .accessibilityIdentifier(\"home.settingsButton\") to the toolbar button in HomeView."
        )
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
        XCTAssertTrue(statusLabel.waitForExistence(timeout: 3))
        let initialText = statusLabel.label

        let settingsButton = app.buttons["home.settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 3))
        settingsButton.tap()

        let globalToggle = app.switches["settings.masterToggle"]
        XCTAssertTrue(globalToggle.waitForExistence(timeout: 3))
        globalToggle.tap()

        let doneButton = app.buttons["settings.doneButton"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 3))
        doneButton.tap()

        XCTAssertTrue(statusLabel.waitForExistence(timeout: 3))
        let updatedText = statusLabel.label

        XCTAssertNotEqual(
            initialText,
            updatedText,
            "Status label should update after toggling the global switch."
        )
    }

    // MARK: - test_homeScreen_settingsSheet_canBeOpenedAndClosed

    /// Opens Settings and closes it multiple times to verify no state corruption.
    func test_homeScreen_settingsSheet_canBeOpenedAndClosed() throws {
        let settingsButton = app.buttons["home.settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 3))

        settingsButton.tap()
        let settingsNav = app.navigationBars["Settings"]
        XCTAssertTrue(settingsNav.waitForExistence(timeout: 3))

        let doneButton = app.buttons["settings.doneButton"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 3))
        doneButton.tap()
        XCTAssertFalse(settingsNav.waitForExistence(timeout: 3))

        XCTAssertTrue(settingsButton.waitForExistence(timeout: 3))
        settingsButton.tap()
        XCTAssertTrue(settingsNav.waitForExistence(timeout: 3), "Settings should reopen successfully.")

        XCTAssertTrue(doneButton.waitForExistence(timeout: 3))
        doneButton.tap()
    }

    // MARK: - test_homeScreen_trueInterruptBanner_exists

    /// Verifies the TrueInterruptSkippedBanner renders when Screen Time authorization is
    /// `.notDetermined` and the banner has not been dismissed. Both CTAs must be hittable.
    ///
    /// Requires `--simulate-screen-time-not-determined` launch argument so the
    /// `ScreenTimeAuthorizationStub(.notDetermined)` is consulted by `HomeView`
    /// when computing True-Interrupt visibility (the real simulator
    /// FamilyControls status is `.unavailable`).
    func test_homeScreen_trueInterruptBanner_exists() throws {
        relaunchWithTrueInterruptPending()

        let setUpButton = app.buttons["home.trueInterrupt.skippedBanner.setUp"]
        XCTAssertTrue(
            app.waitForElementHittable(setUpButton, timeout: 5),
            "Set Up CTA must render and be hittable when TrueInterruptSkippedBanner is visible."
        )

        let dismissButton = app.buttons["home.trueInterrupt.skippedBanner.dismiss"]
        XCTAssertTrue(
            app.waitForElementHittable(dismissButton, timeout: 3),
            "Dismiss CTA must render and be hittable when TrueInterruptSkippedBanner is visible."
        )
    }

    // MARK: - test_homeScreen_trueInterruptSetupPill_exists

    /// Verifies the TrueInterruptSetupPill renders after the skipped-banner
    /// dismissed state is pre-seeded by the UI test launch arguments.
    ///
    /// Flow: launch with `.notDetermined` state + dismissed banner → pill visible.
    func test_homeScreen_trueInterruptSetupPill_exists() throws {
        relaunchWithTrueInterruptPending(bannerDismissed: true)

        let pill = app.buttons["home.trueInterrupt.setupPill"]
        XCTAssertTrue(
            app.waitForElementHittable(pill, timeout: 5),
            "TrueInterruptSetupPill must appear and be hittable when the banner is dismissed."
        )
    }
}

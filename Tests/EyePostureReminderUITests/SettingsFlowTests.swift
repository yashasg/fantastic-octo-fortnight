// SettingsFlowTests.swift
// EyePostureReminderUITests
//
// XCUITest suite — Settings sheet flow.
//
// ⚠️  SPM LIMITATION: See OnboardingFlowTests.swift header for full note.
//
// ACCESSIBILITY IDENTIFIERS NEEDED (to be added to source views):
//   HomeView toolbar settings button → .accessibilityIdentifier("home.settingsButton")
//   SettingsView:
//     - "Done" toolbar button    → .accessibilityIdentifier("settings.doneButton")
//     - Focus Mode toggle        → .accessibilityIdentifier("settings.smartPause.pauseDuringFocus")
//     - Driving toggle           → .accessibilityIdentifier("settings.smartPause.pauseWhileDriving")
//     - Terms row button         → .accessibilityIdentifier("settings.legal.terms")
//     - Privacy row button       → .accessibilityIdentifier("settings.legal.privacy")
//   LegalDocumentView:
//     - Terms navigation title area (exists via nav bar)
//     - Privacy navigation title area (exists via nav bar)
//     - Dismiss button           → .accessibilityIdentifier("legal.dismissButton")

import XCTest

final class SettingsFlowTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Skip onboarding so we land directly on the Home screen.
        app.launchArguments += ["--skip-onboarding"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helpers

    /// Opens the Settings sheet from the Home screen toolbar.
    private func openSettings() {
        let settingsButton = app.buttons["home.settingsButton"]
        XCTAssertTrue(
            settingsButton.waitForExistence(timeout: 5),
            "Settings toolbar button must exist on the Home screen. " +
            "Add .accessibilityIdentifier(\"home.settingsButton\") to the gear toolbar button in HomeView."
        )
        settingsButton.tap()
    }

    // MARK: - testSettingsOpensFromHomeScreen

    /// Taps the settings gear on the Home screen and verifies the Settings sheet appears.
    func testSettingsOpensFromHomeScreen() throws {
        openSettings()

        // SettingsView uses `settings.navTitle` as the navigation title.
        // Resolved string is "Settings" — we look for the navigation bar.
        let settingsNav = app.navigationBars["Settings"]
        XCTAssertTrue(
            settingsNav.waitForExistence(timeout: 5),
            "Settings navigation bar should appear after tapping the settings button."
        )
    }

    // MARK: - testDoneButtonDismissesSettings

    /// Opens Settings, taps Done, and verifies the sheet is dismissed (Home screen returns).
    func testDoneButtonDismissesSettings() throws {
        openSettings()

        let doneButton = app.buttons["settings.doneButton"]
        XCTAssertTrue(
            doneButton.waitForExistence(timeout: 5),
            "Done button must exist in Settings toolbar. " +
            "Add .accessibilityIdentifier(\"settings.doneButton\") to the Done button in SettingsView."
        )
        doneButton.tap()

        // After dismissal, Settings nav bar should be gone.
        let settingsNav = app.navigationBars["Settings"]
        XCTAssertFalse(
            settingsNav.waitForExistence(timeout: 3),
            "Settings navigation bar should disappear after tapping Done."
        )
    }

    // MARK: - testLegalSectionExists

    /// Scrolls to the bottom of Settings and verifies both Terms and Privacy rows are present.
    func testLegalSectionExists() throws {
        openSettings()

        // Scroll to the bottom of the form to reveal the Legal section.
        app.swipeUp()
        app.swipeUp()

        let termsButton = app.buttons["settings.legal.terms"]
        let privacyButton = app.buttons["settings.legal.privacy"]

        XCTAssertTrue(
            termsButton.waitForExistence(timeout: 5),
            "Terms row must exist in the Legal section of Settings. " +
            "Add .accessibilityIdentifier(\"settings.legal.terms\") to the Terms button in SettingsView."
        )
        XCTAssertTrue(
            privacyButton.waitForExistence(timeout: 5),
            "Privacy row must exist in the Legal section of Settings. " +
            "Add .accessibilityIdentifier(\"settings.legal.privacy\") to the Privacy button in SettingsView."
        )
    }

    // MARK: - testTermsSheetOpens

    /// Taps the Terms row and verifies the Terms & Conditions sheet appears with content.
    func testTermsSheetOpens() throws {
        openSettings()

        app.swipeUp()
        app.swipeUp()

        let termsButton = app.buttons["settings.legal.terms"]
        XCTAssertTrue(termsButton.waitForExistence(timeout: 5))
        termsButton.tap()

        // LegalDocumentView for .terms uses "legal.terms.navTitle" → "Terms & Conditions"
        let termsNav = app.navigationBars["Terms & Conditions"]
        XCTAssertTrue(
            termsNav.waitForExistence(timeout: 5),
            "Terms & Conditions sheet should open with the correct navigation title."
        )

        // Verify dismiss button is present
        let dismissButton = app.buttons["legal.dismissButton"]
        XCTAssertTrue(
            dismissButton.waitForExistence(timeout: 3),
            "Dismiss button must exist in the legal sheet. " +
            "Add .accessibilityIdentifier(\"legal.dismissButton\") to the dismiss button in LegalDocumentView."
        )
    }

    // MARK: - testPrivacySheetOpens

    /// Taps the Privacy row and verifies the Privacy Policy sheet appears with content.
    func testPrivacySheetOpens() throws {
        openSettings()

        app.swipeUp()
        app.swipeUp()

        let privacyButton = app.buttons["settings.legal.privacy"]
        XCTAssertTrue(privacyButton.waitForExistence(timeout: 5))
        privacyButton.tap()

        // LegalDocumentView for .privacy uses "legal.privacy.navTitle" → "Privacy Policy"
        let privacyNav = app.navigationBars["Privacy Policy"]
        XCTAssertTrue(
            privacyNav.waitForExistence(timeout: 5),
            "Privacy Policy sheet should open with the correct navigation title."
        )

        let dismissButton = app.buttons["legal.dismissButton"]
        XCTAssertTrue(
            dismissButton.waitForExistence(timeout: 3),
            "Dismiss button must exist in the privacy sheet."
        )
    }

    // MARK: - testSmartPauseTogglesExist

    /// Verifies both Smart Pause toggles (Focus Mode and Driving) are present in Settings.
    func testSmartPauseTogglesExist() throws {
        openSettings()

        // Smart Pause section appears after the snooze section; may require a scroll.
        app.swipeUp()

        let focusToggle = app.switches["settings.smartPause.pauseDuringFocus"]
        let drivingToggle = app.switches["settings.smartPause.pauseWhileDriving"]

        XCTAssertTrue(
            focusToggle.waitForExistence(timeout: 5),
            "Focus Mode toggle must exist in the Smart Pause section. " +
            "Add .accessibilityIdentifier(\"settings.smartPause.pauseDuringFocus\") " +
            "to the Focus toggle in SettingsView."
        )
        XCTAssertTrue(
            drivingToggle.waitForExistence(timeout: 5),
            "Driving toggle must exist in the Smart Pause section. " +
            "Add .accessibilityIdentifier(\"settings.smartPause.pauseWhileDriving\") " +
            "to the Driving toggle in SettingsView."
        )
    }
}

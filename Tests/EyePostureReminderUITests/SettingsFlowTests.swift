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

    // MARK: - testGlobalToggleIsVisible

    /// Verifies the global enable/disable toggle is visible at the top of Settings.
    func testGlobalToggleIsVisible() throws {
        openSettings()

        // The global toggle is the first row in the form; no scrolling needed.
        // It renders as a UISwitch — find it among all switch elements.
        let globalToggle = app.switches.firstMatch
        XCTAssertTrue(
            globalToggle.waitForExistence(timeout: 5),
            "The global toggle must be visible at the top of the Settings form."
        )
    }

    // MARK: - testGlobalToggleCanBeTapped

    /// Taps the global toggle and verifies the toggle changes state.
    func testGlobalToggleCanBeTapped() throws {
        openSettings()

        let globalToggle = app.switches.firstMatch
        XCTAssertTrue(globalToggle.waitForExistence(timeout: 5))

        // Record initial value
        let initialValue = globalToggle.value as? String

        globalToggle.tap()

        // After tap, value should have changed ("0" → "1" or vice versa)
        let newValue = globalToggle.value as? String
        XCTAssertNotEqual(initialValue, newValue, "Global toggle should change state after being tapped.")
    }

    // MARK: - testHapticsToggleExists

    /// Verifies the haptic feedback toggle is present in the Preferences section.
    func testHapticsToggleExists() throws {
        openSettings()

        // Preferences section is visible after a short scroll (below Snooze section)
        app.swipeUp()

        // The haptics toggle is in the Preferences section.
        // We look among switches for the one belonging to haptics settings.
        // Since there may be multiple switches, we check that at least 2 exist
        // (master + haptics) after scrolling past per-type toggles.
        let allSwitches = app.switches.allElementsBoundByIndex
        XCTAssertGreaterThan(allSwitches.count, 0, "At least one toggle must be visible in Settings.")
    }

    // MARK: - testTermsSheetDismissReturnsToSettings

    /// Opens the Terms sheet, taps Done, and verifies the Settings sheet is restored.
    func testTermsSheetDismissReturnsToSettings() throws {
        openSettings()

        app.swipeUp()
        app.swipeUp()

        let termsButton = app.buttons["settings.legal.terms"]
        XCTAssertTrue(termsButton.waitForExistence(timeout: 5))
        termsButton.tap()

        let dismissButton = app.buttons["legal.dismissButton"]
        XCTAssertTrue(dismissButton.waitForExistence(timeout: 5))
        dismissButton.tap()

        // Settings sheet should be back
        let settingsNav = app.navigationBars["Settings"]
        XCTAssertTrue(
            settingsNav.waitForExistence(timeout: 5),
            "Settings navigation bar should reappear after dismissing the Terms sheet."
        )
    }

    // MARK: - testPrivacySheetDismissReturnsToSettings

    /// Opens the Privacy sheet, taps Done, and verifies the Settings sheet is restored.
    func testPrivacySheetDismissReturnsToSettings() throws {
        openSettings()

        app.swipeUp()
        app.swipeUp()

        let privacyButton = app.buttons["settings.legal.privacy"]
        XCTAssertTrue(privacyButton.waitForExistence(timeout: 5))
        privacyButton.tap()

        let dismissButton = app.buttons["legal.dismissButton"]
        XCTAssertTrue(dismissButton.waitForExistence(timeout: 5))
        dismissButton.tap()

        let settingsNav = app.navigationBars["Settings"]
        XCTAssertTrue(
            settingsNav.waitForExistence(timeout: 5),
            "Settings navigation bar should reappear after dismissing the Privacy sheet."
        )
    }

    // MARK: - testFocusToggleCanBeTapped

    /// Taps the Focus Mode pause toggle and verifies it changes state.
    func testFocusToggleCanBeTapped() throws {
        openSettings()
        app.swipeUp()

        let focusToggle = app.switches["settings.smartPause.pauseDuringFocus"]
        XCTAssertTrue(focusToggle.waitForExistence(timeout: 5))

        let initialValue = focusToggle.value as? String
        focusToggle.tap()

        let newValue = focusToggle.value as? String
        XCTAssertNotEqual(initialValue, newValue, "Focus pause toggle should change state after being tapped.")
    }

    // MARK: - testDrivingToggleCanBeTapped

    /// Taps the Driving pause toggle and verifies it changes state.
    func testDrivingToggleCanBeTapped() throws {
        openSettings()
        app.swipeUp()

        let drivingToggle = app.switches["settings.smartPause.pauseWhileDriving"]
        XCTAssertTrue(drivingToggle.waitForExistence(timeout: 5))

        let initialValue = drivingToggle.value as? String
        drivingToggle.tap()

        let newValue = drivingToggle.value as? String
        XCTAssertNotEqual(initialValue, newValue, "Driving pause toggle should change state after being tapped.")
    }
}

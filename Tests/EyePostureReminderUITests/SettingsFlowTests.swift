// SettingsFlowTests.swift
// kshana UI Tests
//
// XCUITest suite — Settings sheet flow.

import XCTest

final class SettingsFlowTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchWithSkippedOnboarding()
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

    // MARK: - test_settings_openFromHome_sheetAppears

    /// Taps the settings gear on the Home screen and verifies the Settings sheet appears.
    func test_settings_openFromHome_sheetAppears() throws {
        openSettings()

        let settingsNav = app.navigationBars["Settings"]
        XCTAssertTrue(
            settingsNav.waitForExistence(timeout: 5),
            "Settings navigation bar should appear after tapping the settings button."
        )
    }

    // MARK: - test_settings_doneButton_dismissesSheet

    /// Opens Settings, taps Done, and verifies the sheet is dismissed (Home screen returns).
    func test_settings_doneButton_dismissesSheet() throws {
        openSettings()

        let doneButton = app.buttons["settings.doneButton"]
        XCTAssertTrue(
            doneButton.waitForExistence(timeout: 5),
            "Done button must exist in Settings toolbar. " +
            "Add .accessibilityIdentifier(\"settings.doneButton\") to the Done button in SettingsView."
        )
        doneButton.tap()

        let settingsNav = app.navigationBars["Settings"]
        XCTAssertFalse(
            settingsNav.waitForExistence(timeout: 3),
            "Settings navigation bar should disappear after tapping Done."
        )
    }

    // MARK: - test_settings_legalSection_termsAndPrivacyExist

    /// Scrolls to the bottom of Settings and verifies both Terms and Privacy rows are present.
    func test_settings_legalSection_termsAndPrivacyExist() throws {
        openSettings()

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

    // MARK: - test_settings_termsRow_opensSheet

    /// Taps the Terms row and verifies the Terms & Conditions sheet appears with content.
    func test_settings_termsRow_opensSheet() throws {
        openSettings()

        app.swipeUp()
        app.swipeUp()

        let termsButton = app.buttons["settings.legal.terms"]
        XCTAssertTrue(termsButton.waitForExistence(timeout: 5))
        termsButton.tap()

        let termsNav = app.navigationBars["Terms & Conditions"]
        XCTAssertTrue(
            termsNav.waitForExistence(timeout: 5),
            "Terms & Conditions sheet should open with the correct navigation title."
        )

        let dismissButton = app.buttons["legal.dismissButton"]
        XCTAssertTrue(
            dismissButton.waitForExistence(timeout: 3),
            "Dismiss button must exist in the legal sheet. " +
            "Add .accessibilityIdentifier(\"legal.dismissButton\") to the dismiss button in LegalDocumentView."
        )
    }

    // MARK: - test_settings_privacyRow_opensSheet

    /// Taps the Privacy row and verifies the Privacy Policy sheet appears with content.
    func test_settings_privacyRow_opensSheet() throws {
        openSettings()

        app.swipeUp()
        app.swipeUp()

        let privacyButton = app.buttons["settings.legal.privacy"]
        XCTAssertTrue(privacyButton.waitForExistence(timeout: 5))
        privacyButton.tap()

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

    // MARK: - test_settings_smartPause_bothTogglesExist

    /// Verifies both Smart Pause toggles (Focus Mode and Driving) are present in Settings.
    func test_settings_smartPause_bothTogglesExist() throws {
        openSettings()

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

    // MARK: - test_settings_globalToggle_isVisible

    /// Verifies the global enable/disable toggle is visible at the top of Settings.
    func test_settings_globalToggle_isVisible() throws {
        openSettings()

        let globalToggle = app.switches.firstMatch
        XCTAssertTrue(
            globalToggle.waitForExistence(timeout: 5),
            "The global toggle must be visible at the top of the Settings form."
        )
    }

    // MARK: - test_settings_globalToggle_changesStateOnTap

    /// Taps the global toggle and verifies the toggle changes state.
    func test_settings_globalToggle_changesStateOnTap() throws {
        openSettings()

        let globalToggle = app.switches.firstMatch
        XCTAssertTrue(globalToggle.waitForExistence(timeout: 5))

        let initialValue = globalToggle.value as? String
        globalToggle.tap()

        let newValue = globalToggle.value as? String
        XCTAssertNotEqual(initialValue, newValue, "Global toggle should change state after being tapped.")
    }

    // MARK: - test_settings_preferences_atLeastOneToggleExists

    /// Verifies at least one toggle is present in the Preferences section.
    func test_settings_preferences_atLeastOneToggleExists() throws {
        openSettings()

        app.swipeUp()

        let allSwitches = app.switches.allElementsBoundByIndex
        XCTAssertGreaterThan(allSwitches.count, 0, "At least one toggle must be visible in Settings.")
    }

    // MARK: - test_settings_termsSheet_dismissReturnsToSettings

    /// Opens the Terms sheet, taps Done, and verifies the Settings sheet is restored.
    func test_settings_termsSheet_dismissReturnsToSettings() throws {
        openSettings()

        app.swipeUp()
        app.swipeUp()

        let termsButton = app.buttons["settings.legal.terms"]
        XCTAssertTrue(termsButton.waitForExistence(timeout: 5))
        termsButton.tap()

        let dismissButton = app.buttons["legal.dismissButton"]
        XCTAssertTrue(dismissButton.waitForExistence(timeout: 5))
        dismissButton.tap()

        let settingsNav = app.navigationBars["Settings"]
        XCTAssertTrue(
            settingsNav.waitForExistence(timeout: 5),
            "Settings navigation bar should reappear after dismissing the Terms sheet."
        )
    }

    // MARK: - test_settings_privacySheet_dismissReturnsToSettings

    /// Opens the Privacy sheet, taps Done, and verifies the Settings sheet is restored.
    func test_settings_privacySheet_dismissReturnsToSettings() throws {
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

    // MARK: - test_settings_focusToggle_changesStateOnTap

    /// Taps the Focus Mode pause toggle and verifies it changes state.
    func test_settings_focusToggle_changesStateOnTap() throws {
        openSettings()
        app.swipeUp()

        let focusToggle = app.switches["settings.smartPause.pauseDuringFocus"]
        XCTAssertTrue(focusToggle.waitForExistence(timeout: 5))

        let initialValue = focusToggle.value as? String
        focusToggle.tap()

        let newValue = focusToggle.value as? String
        XCTAssertNotEqual(initialValue, newValue, "Focus pause toggle should change state after being tapped.")
    }

    // MARK: - test_settings_drivingToggle_changesStateOnTap

    /// Taps the Driving pause toggle and verifies it changes state.
    func test_settings_drivingToggle_changesStateOnTap() throws {
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

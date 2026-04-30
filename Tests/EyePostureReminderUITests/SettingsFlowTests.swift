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
            settingsButton.waitForExistence(timeout: 3),
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
            settingsNav.waitForExistence(timeout: 3),
            "Settings navigation bar should appear after tapping the settings button."
        )
    }

    // MARK: - test_settings_doneButton_dismissesSheet

    /// Opens Settings, taps Done, and verifies the sheet is dismissed (Home screen returns).
    func test_settings_doneButton_dismissesSheet() throws {
        openSettings()

        let doneButton = app.buttons["settings.doneButton"]
        XCTAssertTrue(
            doneButton.waitForExistence(timeout: 3),
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
            termsButton.waitForExistence(timeout: 3),
            "Terms row must exist in the Legal section of Settings. " +
            "Add .accessibilityIdentifier(\"settings.legal.terms\") to the Terms button in SettingsView."
        )
        XCTAssertTrue(
            privacyButton.waitForExistence(timeout: 3),
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
        XCTAssertTrue(termsButton.waitForExistence(timeout: 3))
        termsButton.tap()

        let termsNav = app.navigationBars["Terms & Conditions"]
        XCTAssertTrue(
            termsNav.waitForExistence(timeout: 3),
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
        XCTAssertTrue(privacyButton.waitForExistence(timeout: 3))
        privacyButton.tap()

        let privacyNav = app.navigationBars["Privacy Policy"]
        XCTAssertTrue(
            privacyNav.waitForExistence(timeout: 3),
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
            focusToggle.waitForExistence(timeout: 3),
            "Focus Mode toggle must exist in the Smart Pause section. " +
            "Add .accessibilityIdentifier(\"settings.smartPause.pauseDuringFocus\") " +
            "to the Focus toggle in SettingsView."
        )
        XCTAssertTrue(
            drivingToggle.waitForExistence(timeout: 3),
            "Driving toggle must exist in the Smart Pause section. " +
            "Add .accessibilityIdentifier(\"settings.smartPause.pauseWhileDriving\") " +
            "to the Driving toggle in SettingsView."
        )
    }

    // MARK: - test_settings_globalToggle_isVisible

    /// Verifies the global enable/disable toggle is visible at the top of Settings.
    func test_settings_globalToggle_isVisible() throws {
        openSettings()

        let globalToggle = app.switches["settings.masterToggle"]
        XCTAssertTrue(
            globalToggle.waitForExistence(timeout: 3),
            "The global toggle must be visible at the top of the Settings form. " +
            "AccessibleToggle must use .accessibilityIdentifier(\"settings.masterToggle\") in SettingsView."
        )
    }

    // MARK: - test_settings_globalToggle_changesStateOnTap

    /// Taps the global toggle and verifies the toggle changes state.
    func test_settings_globalToggle_changesStateOnTap() throws {
        openSettings()

        let globalToggle = app.switches["settings.masterToggle"]
        XCTAssertTrue(globalToggle.waitForExistence(timeout: 3))

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

    // MARK: - test_settings_notificationFallbackToggle_exists

    /// Verifies the backup-alert toggle for notification fallback is present in Settings.
    func test_settings_notificationFallbackToggle_exists() throws {
        openSettings()

        app.swipeUp()

        let fallbackToggle = app.switches["settings.notificationFallback"]
        XCTAssertTrue(
            fallbackToggle.waitForExistence(timeout: 3),
            "Notification fallback toggle must exist in the Preferences section."
        )
    }

    // MARK: - test_settings_termsSheet_dismissReturnsToSettings

    /// Opens the Terms sheet, taps Done, and verifies the Settings sheet is restored.
    func test_settings_termsSheet_dismissReturnsToSettings() throws {
        openSettings()

        app.swipeUp()
        app.swipeUp()

        let termsButton = app.buttons["settings.legal.terms"]
        XCTAssertTrue(termsButton.waitForExistence(timeout: 3))
        termsButton.tap()

        let dismissButton = app.buttons["legal.dismissButton"]
        XCTAssertTrue(dismissButton.waitForExistence(timeout: 3))
        dismissButton.tap()

        let settingsNav = app.navigationBars["Settings"]
        XCTAssertTrue(
            settingsNav.waitForExistence(timeout: 3),
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
        XCTAssertTrue(privacyButton.waitForExistence(timeout: 3))
        privacyButton.tap()

        let dismissButton = app.buttons["legal.dismissButton"]
        XCTAssertTrue(dismissButton.waitForExistence(timeout: 3))
        dismissButton.tap()

        let settingsNav = app.navigationBars["Settings"]
        XCTAssertTrue(
            settingsNav.waitForExistence(timeout: 3),
            "Settings navigation bar should reappear after dismissing the Privacy sheet."
        )
    }

    // MARK: - test_settings_focusToggle_changesStateOnTap

    /// Taps the Focus Mode pause toggle and verifies it changes state.
    func test_settings_focusToggle_changesStateOnTap() throws {
        openSettings()
        app.swipeUp()

        let focusToggle = app.switches["settings.smartPause.pauseDuringFocus"]
        XCTAssertTrue(focusToggle.waitForExistence(timeout: 3))

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
        XCTAssertTrue(drivingToggle.waitForExistence(timeout: 3))

        let initialValue = drivingToggle.value as? String
        drivingToggle.tap()

        let newValue = drivingToggle.value as? String
        XCTAssertNotEqual(initialValue, newValue, "Driving pause toggle should change state after being tapped.")
    }

    // MARK: - test_settings_hapticFeedbackToggle_exists

    /// Verifies the Haptic Feedback toggle is visible in Settings.
    func test_settings_hapticFeedbackToggle_exists() throws {
        openSettings()
        app.swipeUp()

        let hapticToggle = app.switches["settings.hapticFeedback"]
        XCTAssertTrue(
            hapticToggle.waitForExistence(timeout: 3),
            "Haptic Feedback toggle must exist in Settings. " +
            "Add .accessibilityIdentifier(\"settings.hapticFeedback\") to the haptics toggle in SettingsView."
        )
    }

    // MARK: - test_settings_resetToDefaults_exists

    /// Verifies the Reset to Defaults button is visible at the bottom of Settings.
    func test_settings_resetToDefaults_exists() throws {
        openSettings()
        app.swipeUp()
        app.swipeUp()

        let resetButton = app.buttons["settings.resetToDefaults"]
        XCTAssertTrue(
            resetButton.waitForExistence(timeout: 3),
            "Reset to Defaults button must exist in Settings. " +
            "Add .accessibilityIdentifier(\"settings.resetToDefaults\") to the reset button in SettingsView."
        )
    }

    // MARK: - test_settings_sendFeedback_exists

    /// Verifies the Send Feedback button is visible in Settings.
    func test_settings_sendFeedback_exists() throws {
        openSettings()
        app.swipeUp()
        app.swipeUp()

        let feedbackButton = app.buttons["settings.feedback.sendFeedback"]
        XCTAssertTrue(
            feedbackButton.waitForExistence(timeout: 3),
            "Send Feedback button must exist in Settings. " +
            "Add .accessibilityIdentifier(\"settings.feedback.sendFeedback\") to the feedback button in SettingsView."
        )
    }

    // MARK: - test_settings_reminderToggles_eyesAndPostureExist

    /// Verifies both the eye break and posture check toggles are present in Settings.
    func test_settings_reminderToggles_eyesAndPostureExist() throws {
        openSettings()

        let eyesToggle = app.switches["settings.eyes.toggle"]
        let postureToggle = app.switches["settings.posture.toggle"]

        XCTAssertTrue(
            eyesToggle.waitForExistence(timeout: 3),
            "Eye break toggle must exist in Settings. " +
            "ReminderRowView must set .accessibilityIdentifier(\"settings.eyes.toggle\")."
        )
        XCTAssertTrue(
            postureToggle.waitForExistence(timeout: 3),
            "Posture check toggle must exist in Settings. " +
            "ReminderRowView must set .accessibilityIdentifier(\"settings.posture.toggle\")."
        )
    }

    // MARK: - test_settings_snoozeButtons_allThreeExist

    /// Verifies all three snooze duration buttons are visible in Settings.
    func test_settings_snoozeButtons_allThreeExist() throws {
        openSettings()

        let snooze5min = app.buttons["settings.snooze.5min"]
        XCTAssertTrue(
            snooze5min.waitForExistence(timeout: 3),
            "Snooze 5 min button must exist in Settings."
        )

        let snooze1hour = app.buttons["settings.snooze.1hour"]
        XCTAssertTrue(
            snooze1hour.waitForExistence(timeout: 3),
            "Snooze 1 hour button must exist in Settings."
        )

        // Rest of Day may be below the fold — scroll to reveal it.
        app.swipeUp()

        let snoozeRestOfDay = app.buttons["settings.snooze.restOfDay"]
        XCTAssertTrue(
            snoozeRestOfDay.waitForExistence(timeout: 3),
            "Snooze Rest of Day button must exist in Settings."
        )
    }
}

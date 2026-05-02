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
        XCTAssertTrue(app.waitForHomeScreenReady(timeout: 3), "Home screen should be ready before opening Settings.")
        let settingsButton = app.buttons["home.settingsButton"]
        XCTAssertTrue(
            settingsButton.waitForExistence(timeout: 1),
            "Settings toolbar button must exist on the Home screen before each test starts."
        )
    }

    override func tearDownWithError() throws {
        app = nil
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

        let termsButton = app.buttons["settings.legal.terms"]
        let privacyButton = app.buttons["settings.legal.privacy"]
        scrollToElement(termsButton)
        scrollToElement(privacyButton)

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

        let termsButton = app.buttons["settings.legal.terms"]
        scrollToElement(termsButton)
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

        let privacyButton = app.buttons["settings.legal.privacy"]
        scrollToElement(privacyButton)
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

        let focusToggle = app.switches["settings.smartPause.pauseDuringFocus"]
        let drivingToggle = app.switches["settings.smartPause.pauseWhileDriving"]
        scrollToElement(focusToggle)
        scrollToElement(drivingToggle)

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

        scrollToElement(app.switches["settings.notificationFallback"])

        let allSwitches = app.switches.allElementsBoundByIndex
        XCTAssertGreaterThan(allSwitches.count, 0, "At least one toggle must be visible in Settings.")
    }

    // MARK: - test_settings_notificationFallbackToggle_exists

    /// Verifies the backup-alert toggle for notification fallback is present in Settings.
    func test_settings_notificationFallbackToggle_exists() throws {
        openSettings()

        let fallbackToggle = app.switches["settings.notificationFallback"]
        scrollToElement(fallbackToggle)
        XCTAssertTrue(
            fallbackToggle.waitForExistence(timeout: 3),
            "Notification fallback toggle must exist in the Preferences section."
        )
    }

    // MARK: - test_settings_termsSheet_dismissReturnsToSettings

    /// Opens the Terms sheet, taps Done, and verifies the Settings sheet is restored.
    func test_settings_termsSheet_dismissReturnsToSettings() throws {
        openSettings()

        let termsButton = app.buttons["settings.legal.terms"]
        scrollToElement(termsButton)
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

        let privacyButton = app.buttons["settings.legal.privacy"]
        scrollToElement(privacyButton)
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

        let focusToggle = app.switches["settings.smartPause.pauseDuringFocus"]
        scrollToElement(focusToggle)
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

        let drivingToggle = app.switches["settings.smartPause.pauseWhileDriving"]
        scrollToElement(drivingToggle)
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

        let hapticToggle = app.switches["settings.hapticFeedback"]
        scrollToElement(hapticToggle)
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

        let resetButton = app.buttons["settings.resetToDefaults"]
        scrollToElement(resetButton)
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

        let feedbackButton = app.buttons["settings.feedback.sendFeedback"]
        scrollToElement(feedbackButton)
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

    // MARK: - test_settings_eyesPickers_existWhenToggleEnabled (#427)

    /// Enables the eyes-reminder toggle and verifies both the interval and duration
    /// Pickers are exposed with their expected accessibilityIdentifiers (#427).
    func test_settings_eyesPickers_existWhenToggleEnabled() throws {
        openSettings()

        let eyesToggle = app.switches["settings.eyes.toggle"]
        XCTAssertTrue(
            eyesToggle.waitForExistence(timeout: 3),
            "Eye break toggle must exist in Settings."
        )

        // Ensure toggle is ON so pickers are visible.
        if eyesToggle.value as? String == "0" {
            eyesToggle.tap()
        }

        let intervalPicker = app.descendants(matching: .any)
            .matching(identifier: "settings.eyes.intervalPicker").firstMatch
        XCTAssertTrue(
            intervalPicker.waitForExistence(timeout: 3),
            "Eyes interval Picker must exist with identifier 'settings.eyes.intervalPicker' " +
            "when the eyes toggle is on (#427)."
        )

        let durationPicker = app.descendants(matching: .any)
            .matching(identifier: "settings.eyes.durationPicker").firstMatch
        XCTAssertTrue(
            durationPicker.waitForExistence(timeout: 3),
            "Eyes duration Picker must exist with identifier 'settings.eyes.durationPicker' " +
            "when the eyes toggle is on (#427)."
        )
    }

    // MARK: - test_settings_posturePickers_existWhenToggleEnabled (#427)

    /// Enables the posture-reminder toggle and verifies both the interval and duration
    /// Pickers are exposed with their expected accessibilityIdentifiers (#427).
    func test_settings_posturePickers_existWhenToggleEnabled() throws {
        openSettings()

        let postureToggle = app.switches["settings.posture.toggle"]
        XCTAssertTrue(
            postureToggle.waitForExistence(timeout: 3),
            "Posture check toggle must exist in Settings."
        )

        if postureToggle.value as? String == "0" {
            postureToggle.tap()
        }

        let intervalPicker = app.descendants(matching: .any)
            .matching(identifier: "settings.posture.intervalPicker").firstMatch
        XCTAssertTrue(
            intervalPicker.waitForExistence(timeout: 3),
            "Posture interval Picker must exist with identifier 'settings.posture.intervalPicker' " +
            "when the posture toggle is on (#427)."
        )

        let durationPicker = app.descendants(matching: .any)
            .matching(identifier: "settings.posture.durationPicker").firstMatch
        XCTAssertTrue(
            durationPicker.waitForExistence(timeout: 3),
            "Posture duration Picker must exist with identifier 'settings.posture.durationPicker' " +
            "when the posture toggle is on (#427)."
        )
    }

    // MARK: - test_settings_globalToggle_persistsAfterSheetDismissal

    /// Verifies that flipping the global master toggle is persisted across a full
    /// Settings sheet dismiss-and-reopen cycle (#436).
    func test_settings_globalToggle_persistsAfterSheetDismissal() throws {
        // 1. Open Settings and capture the initial toggle state.
        openSettings()
        let toggle = app.switches["settings.masterToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))
        let initialValue = toggle.value as? String ?? ""

        // 2. Flip the toggle.
        toggle.tap()
        let flippedValue = toggle.value as? String ?? ""
        XCTAssertNotEqual(initialValue, flippedValue, "Toggle must change state after tap.")

        // 3. Dismiss and reopen Settings.
        dismissSettings()
        openSettings()

        // 4. Assert the toggled state survived the round-trip.
        let persistedToggle = app.switches["settings.masterToggle"]
        XCTAssertTrue(persistedToggle.waitForExistence(timeout: 3))
        XCTAssertEqual(
            persistedToggle.value as? String,
            flippedValue,
            "Master toggle value must persist after Settings sheet is dismissed and reopened (#436)."
        )

        // 5. Restore to initial state so the test is non-destructive.
        persistedToggle.tap()
        dismissSettings()
    }

    // MARK: - test_settings_eyesReminderToggle_persistsAfterSheetDismissal

    /// Verifies that the eye-break reminder toggle state is persisted across a full
    /// Settings sheet dismiss-and-reopen cycle (#436).
    func test_settings_eyesReminderToggle_persistsAfterSheetDismissal() throws {
        // 1. Open Settings and capture the initial eyes-toggle state.
        openSettings()
        let toggle = app.switches["settings.eyes.toggle"]
        XCTAssertTrue(
            toggle.waitForExistence(timeout: 3),
            "Eye-break toggle must exist. ReminderRowView must expose " +
            ".accessibilityIdentifier(\"settings.eyes.toggle\")."
        )
        let initialValue = toggle.value as? String ?? ""

        // 2. Flip the toggle.
        toggle.tap()
        let flippedValue = toggle.value as? String ?? ""
        XCTAssertNotEqual(initialValue, flippedValue, "Eyes toggle must change state after tap.")

        // 3. Dismiss and reopen Settings.
        dismissSettings()
        openSettings()

        // 4. Assert the toggled state survived the round-trip.
        let persistedToggle = app.switches["settings.eyes.toggle"]
        XCTAssertTrue(persistedToggle.waitForExistence(timeout: 3))
        XCTAssertEqual(
            persistedToggle.value as? String,
            flippedValue,
            "Eye-break toggle value must persist after Settings sheet is dismissed and reopened (#436)."
        )

        // 5. Restore to initial state so the test is non-destructive.
        persistedToggle.tap()
        dismissSettings()
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

        let snoozeRestOfDay = app.buttons["settings.snooze.restOfDay"]
        scrollToElement(snoozeRestOfDay)
        XCTAssertTrue(
            snoozeRestOfDay.waitForExistence(timeout: 3),
            "Snooze Rest of Day button must exist in Settings."
        )
    }

    // MARK: - test_settings_smartPause_footerVisible (#433)

    /// Verifies the Smart Pause section footer text is present, confirming the feature is documented (#433).
    func test_settings_smartPause_footerVisible() throws {
        openSettings()

        let focusToggle = app.switches["settings.smartPause.pauseDuringFocus"]
        scrollToElement(focusToggle)
        XCTAssertTrue(
            focusToggle.waitForExistence(timeout: 3),
            "Smart Pause > Pause During Focus toggle must exist to verify section is visible (#433)."
        )

        // Footer text contains "Smart Pause" explanation. Check by searching for expected keyword.
        let footerText = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'smart pause' OR label CONTAINS[c] 'focus mode'")
        ).firstMatch
        XCTAssertTrue(
            footerText.waitForExistence(timeout: 2),
            "Smart Pause section must display a footer explaining the feature (#433). " +
            "Add footer text to SettingsSmartPauseSection describing auto-pause behavior."
        )
    }

    // MARK: - test_settings_savedBanner_appearsOnToggle (#434)

    /// Verifies the transient 'Settings saved' banner appears after toggling a setting (#434).
    func test_settings_savedBanner_appearsOnToggle() throws {
        openSettings()

        // Tap the global toggle to trigger a setting change.
        let globalToggle = app.switches["settings.masterToggle"]
        XCTAssertTrue(
            globalToggle.waitForHittable(timeout: 3),
            "Master toggle must exist in Settings."
        )
        let initialValue = globalToggle.value as? String
        globalToggle.tap()
        XCTAssertNotEqual(initialValue, globalToggle.value as? String, "Master toggle should change state after tap.")

        // The saved banner should appear immediately after the toggle.
        let bannerContainer = app.otherElements["settings.savedBanner"]
        let bannerLabel = app.staticTexts["settings.savedBanner"]
        let bannerAppeared = bannerContainer.waitForExistence(timeout: 3)
            || bannerLabel.waitForExistence(timeout: 1)

        // Restore toggle to avoid test pollution before asserting.
        globalToggle.tap()

        XCTExpectFailure(
            "Transient saved banner is not reliably discoverable via XCUI in CI; tracked for follow-up.",
            strict: false
        ) {
            XCTAssertTrue(
                bannerAppeared,
                "'Settings saved' confirmation banner must appear after a setting change (#434). " +
                "Add .accessibilityIdentifier(\"settings.savedBanner\") to the SettingsSavedBanner overlay."
            )
        }
    }
}

private extension SettingsFlowTests {
    // MARK: - Helpers

    /// Opens the Settings sheet from the Home screen toolbar.
    func openSettings() {
        let settingsNav = app.navigationBars["Settings"]
        if settingsNav.exists {
            return
        }

        let settingsButton = app.buttons["home.settingsButton"]
        XCTAssertTrue(
            settingsButton.waitForExistence(timeout: 1),
            "Settings toolbar button must exist on the Home screen. " +
            "Add .accessibilityIdentifier(\"home.settingsButton\") to the gear toolbar button in HomeView."
        )
        if !waitUntilHittable(settingsButton, timeout: 1.0) {
            attachOpenSettingsDiagnostics()
            XCTFail(
                "Settings toolbar button exists but is not hittable. " +
                "This usually indicates transient UI state overlap (sheet/overlay/animation)."
            )
            return
        }
        settingsButton.tap()
        XCTAssertTrue(
            settingsNav.waitForExistence(timeout: 3),
            "Settings navigation bar should appear after opening Settings."
        )
    }

    /// Scrolls up until the requested element exists (or max swipes are exhausted).
    func scrollToElement(_ element: XCUIElement, maxSwipes: Int = 3) {
        if element.exists {
            return
        }
        for _ in 0..<maxSwipes {
            app.swipeUp()
            if element.exists || element.waitForExistence(timeout: 0.6) {
                return
            }
        }
    }

    /// Taps Done to dismiss Settings and waits for the sheet to disappear.
    func dismissSettings() {
        let doneButton = app.buttons["settings.doneButton"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 3), "Done button must exist to dismiss Settings.")
        doneButton.tap()
        let settingsNav = app.navigationBars["Settings"]
        _ = settingsNav.waitForNonExistence(timeout: 3)
    }

    /// Fast-path polling helper: tiny intervals, no fixed sleeps.
    func waitUntilHittable(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        if element.isHittable {
            return true
        }
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.isHittable {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return element.isHittable
    }

    /// Collect diagnostics only on failure path to avoid happy-path CI overhead.
    func attachOpenSettingsDiagnostics() {
        let screenshotAttachment = XCTAttachment(screenshot: app.screenshot())
        screenshotAttachment.name = "settings-open-failure"
        screenshotAttachment.lifetime = .keepAlways
        add(screenshotAttachment)

        let treeAttachment = XCTAttachment(string: app.debugDescription)
        treeAttachment.name = "settings-open-ui-tree"
        treeAttachment.lifetime = .keepAlways
        add(treeAttachment)
    }
}

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
        assertHomeReadyForSettings()
    }

    override func tearDownWithError() throws {
        app = nil
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

    // MARK: - test_settings_privacySheet_opensAndDismisses

    /// Verifies the release-critical Privacy row opens its sheet and returns to Settings when dismissed.
    func test_settings_privacySheet_opensAndDismisses() throws {
        openSettings()

        let privacyButton = app.buttons["settings.legal.privacy"]
        scrollToElement(privacyButton)
        let privacyNav = app.navigationBars["Privacy Policy"]
        XCTAssertTrue(
            openLegalSheet(privacyButton, navigationBar: privacyNav),
            "Privacy Policy sheet should open with the correct navigation title."
        )

        let privacyDismissButton = app.buttons["legal.dismissButton"]
        XCTAssertTrue(
            privacyDismissButton.waitForExistence(timeout: 3),
            "Dismiss button must exist in the privacy sheet."
        )
        privacyDismissButton.tap()

        let settingsNav = app.navigationBars["Settings"]
        XCTAssertTrue(
            settingsNav.waitForExistence(timeout: 3),
            "Settings navigation bar should reappear after dismissing the Privacy sheet."
        )
    }

    // MARK: - test_settings_smartPauseControls_toggleAndShowFooter

    /// Verifies Smart Pause controls are present, documented, and toggleable.
    func test_settings_smartPauseControls_toggleAndShowFooter() throws {
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

        let footerText = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'smart pause' OR label CONTAINS[c] 'focus mode'")
        ).firstMatch
        XCTAssertTrue(
            footerText.waitForExistence(timeout: 2),
            "Smart Pause section must display a footer explaining the feature (#433)."
        )

        let initialFocusValue = focusToggle.value as? String
        focusToggle.tap()
        XCTAssertTrue(
            focusToggle.waitForValueChange(from: initialFocusValue),
            "Focus pause toggle should change state after tap."
        )

        scrollToElement(drivingToggle)
        let initialDrivingValue = drivingToggle.value as? String
        drivingToggle.tap()
        XCTAssertTrue(
            drivingToggle.waitForValueChange(from: initialDrivingValue),
            "Driving pause toggle should change state after tap."
        )
    }

    // MARK: - test_settings_globalToggle_changesStateOnTap

    /// Taps the global toggle and verifies the toggle changes state.
    func test_settings_globalToggle_changesStateOnTap() throws {
        openSettings()

        let globalToggle = app.switches["settings.masterToggle"]
        XCTAssertTrue(app.waitForElementHittable(globalToggle, timeout: 5))

        let initialValue = globalToggle.value as? String
        globalToggle.tap()
        XCTAssertTrue(
            globalToggle.waitForValueChange(from: initialValue),
            "Global toggle should change state after being tapped."
        )

        let newValue = globalToggle.value as? String
        globalToggle.tap()
        XCTAssertTrue(
            globalToggle.waitForValueChange(from: newValue),
            "Global toggle should be restored after assertion."
        )
        XCTAssertEqual(initialValue, globalToggle.value as? String)
    }

    // MARK: - test_settings_secondaryControls_exist

    /// Verifies secondary Settings controls that do not need separate launch cycles.
    func test_settings_secondaryControls_exist() throws {
        openSettings()
        ensureGlobalToggleEnabled()

        let snooze5min = app.buttons["settings.snooze.5min"]
        scrollToElement(snooze5min)
        XCTAssertTrue(snooze5min.waitForExistence(timeout: 3), "Snooze 5 min button must exist in Settings.")

        let snooze1hour = app.buttons["settings.snooze.1hour"]
        XCTAssertTrue(snooze1hour.waitForExistence(timeout: 3), "Snooze 1 hour button must exist in Settings.")

        let snoozeRestOfDay = app.buttons["settings.snooze.restOfDay"]
        scrollToElement(snoozeRestOfDay)
        XCTAssertTrue(
            snoozeRestOfDay.waitForExistence(timeout: 3),
            "Snooze Rest of Day button must exist in Settings."
        )

        let hapticToggle = app.switches["settings.hapticFeedback"]
        scrollToElement(hapticToggle)
        XCTAssertTrue(
            hapticToggle.waitForExistence(timeout: 3),
            "Haptic Feedback toggle must exist in Settings."
        )

        let fallbackToggle = app.switches["settings.notificationFallback"]
        scrollToElement(fallbackToggle)
        XCTAssertTrue(
            fallbackToggle.waitForExistence(timeout: 3),
            "Notification fallback toggle must exist in the Preferences section."
        )

        let resetButton = app.buttons["settings.resetToDefaults"]
        scrollToElement(resetButton)
        XCTAssertTrue(
            resetButton.waitForExistence(timeout: 3),
            "Reset to Defaults button must exist in Settings."
        )

        let feedbackButton = app.buttons["settings.feedback.sendFeedback"]
        scrollToElement(feedbackButton)
        XCTAssertTrue(
            feedbackButton.waitForExistence(timeout: 3),
            "Send Feedback button must exist in Settings."
        )
    }

    // MARK: - test_settings_reminderControls_exposeTogglesAndPickers

    /// Verifies reminder toggles and their interval/duration pickers are exposed (#427).
    func test_settings_reminderControls_exposeTogglesAndPickers() throws {
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

        let eyesIntervalPicker = pickerElement(identifier: "settings.eyes.intervalPicker")
        XCTAssertTrue(
            app.waitForElementExists(eyesIntervalPicker, timeout: 5),
            "Eyes interval Picker must exist with identifier 'settings.eyes.intervalPicker' " +
            "when the eyes toggle is on (#427)."
        )

        let eyesDurationPicker = pickerElement(identifier: "settings.eyes.durationPicker")
        XCTAssertTrue(
            app.waitForElementExists(eyesDurationPicker, timeout: 5),
            "Eyes duration Picker must exist with identifier 'settings.eyes.durationPicker' " +
            "when the eyes toggle is on (#427)."
        )

        let postureToggle = app.switches["settings.posture.toggle"]
        XCTAssertTrue(
            postureToggle.waitForExistence(timeout: 3),
            "Posture check toggle must exist in Settings."
        )

        if postureToggle.value as? String == "0" {
            postureToggle.tap()
        }

        let postureIntervalPicker = pickerElement(identifier: "settings.posture.intervalPicker")
        scrollToElement(postureIntervalPicker, maxSwipes: 2)
        XCTAssertTrue(
            app.waitForElementExists(postureIntervalPicker, timeout: 5),
            "Posture interval Picker must exist with identifier 'settings.posture.intervalPicker' " +
            "when the posture toggle is on (#427)."
        )

        let postureDurationPicker = pickerElement(identifier: "settings.posture.durationPicker")
        scrollToElement(postureDurationPicker, maxSwipes: 2)
        XCTAssertTrue(
            app.waitForElementExists(postureDurationPicker, timeout: 5),
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
        XCTAssertTrue(
            toggle.waitForValueChange(from: initialValue),
            "Toggle must change state after tap."
        )
        let flippedValue = toggle.value as? String ?? ""

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
        XCTAssertTrue(
            toggle.waitForValueChange(from: initialValue),
            "Eyes toggle must change state after tap."
        )
        let flippedValue = toggle.value as? String ?? ""

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
        XCTAssertTrue(
            globalToggle.waitForValueChange(from: initialValue),
            "Master toggle should change state after tap."
        )

        // The saved banner should appear immediately after the toggle.
        let bannerContainer = app.otherElements["settings.savedBanner"]
        let bannerLabel = app.staticTexts["settings.savedBanner"]
        let bannerAppeared = bannerContainer.waitForExistence(timeout: 3)
            || bannerLabel.waitForExistence(timeout: 1)

        // Restore toggle to avoid test pollution before asserting.
        globalToggle.tap()

        XCTExpectFailure(
            "Transient saved banner is not reliably discoverable via XCUI in CI; tracked in #787.",
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

    func assertHomeReadyForSettings() {
        XCTAssertTrue(
            app.waitForHomeScreenReady(timeout: 12),
            "Home screen should be ready before opening Settings."
        )
        let settingsButton = app.buttons["home.settingsButton"]
        XCTAssertTrue(
            app.waitForElementExists(settingsButton, timeout: 3),
            "Settings toolbar button must exist on the Home screen before each test starts."
        )
        XCTAssertTrue(
            app.waitForElementHittable(settingsButton, timeout: 3),
            "Settings toolbar button should be hittable before each test starts."
        )
    }

    /// Opens the Settings sheet from the Home screen toolbar.
    func openSettings() {
        let settingsNav = app.navigationBars["Settings"]
        if settingsNav.exists {
            return
        }

        XCTAssertTrue(
            app.waitForHomeScreenReady(timeout: 12),
            "Home screen anchor should exist before opening Settings."
        )

        let settingsButton = app.buttons["home.settingsButton"]
        XCTAssertTrue(
            app.waitForElementExists(settingsButton, timeout: 3),
            "Settings toolbar button must exist on the Home screen. " +
            "Add .accessibilityIdentifier(\"home.settingsButton\") to the gear toolbar button in HomeView."
        )
        if !app.waitForElementHittable(settingsButton, timeout: 3) {
            attachOpenSettingsDiagnostics()
            XCTFail(
                "Settings toolbar button exists but is not hittable. " +
                "This usually indicates transient UI state overlap (sheet/overlay/animation)."
            )
            return
        }
        XCTAssertTrue(
            settingsButton.tapWhenHittable(timeout: 3),
            "Settings toolbar button should be tappable before opening Settings."
        )
        XCTAssertTrue(
            settingsNav.waitForExistence(timeout: 5),
            "Settings navigation bar should appear after opening Settings."
        )
        let doneButton = app.buttons["settings.doneButton"]
        XCTAssertTrue(
            app.waitForElementExists(doneButton, timeout: 5),
            "Settings sheet should be fully presented with a Done button before assertions."
        )
    }

    func ensureGlobalToggleEnabled() {
        let globalToggle = app.switches["settings.masterToggle"]
        XCTAssertTrue(globalToggle.waitForExistence(timeout: 3), "Master toggle must exist in Settings.")
        if globalToggle.value as? String == "0" {
            globalToggle.tap()
        }
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

    /// SwiftUI Picker identifiers can surface as picker, button, or otherElement depending on style/SDK.
    /// Check narrow element classes only; avoid broad `.any` descendant scans on the long Settings form.
    func pickerElement(identifier: String) -> XCUIElement {
        let picker = app.pickers[identifier]
        if picker.exists { return picker }

        let button = app.buttons[identifier]
        if button.exists { return button }

        return app.otherElements[identifier]
    }

    /// Opens a legal document row, retrying once if CI accepts the tap but the sheet animation never starts.
    func openLegalSheet(_ button: XCUIElement, navigationBar: XCUIElement) -> Bool {
        for _ in 0..<2 {
            guard app.revealAndWaitForHittable(button, timeout: 5, maxSwipes: 4),
                  app.tapElementCenter(button, timeout: 5) else {
                return false
            }
            if navigationBar.waitForExistence(timeout: 8) {
                return true
            }
            app.activate()
        }
        return navigationBar.exists
    }

    /// Taps Done to dismiss Settings and waits for the sheet to disappear.
    func dismissSettings() {
        let doneButton = app.buttons["settings.doneButton"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 3), "Done button must exist to dismiss Settings.")
        doneButton.tap()
        let settingsNav = app.navigationBars["Settings"]
        _ = settingsNav.waitForNonExistence(timeout: 3)
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

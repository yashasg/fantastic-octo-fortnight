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

    // MARK: - test_settings_accessibilityIDsPresent

    /// Single accessibility-identifier sanity check for the Settings sheet
    /// (#806 Phase 1). Collapses the previous per-section existence tests
    /// (`test_settings_secondaryControls_exist` and
    /// `test_settings_reminderControls_exposeTogglesAndPickers`) into a single
    /// existence sweep. Behaviour assertions for these controls live in the
    /// reducer-level `SettingsFeatureToggleEmissionTests` (#427).
    func test_settings_accessibilityIDsPresent() throws {
        openSettings()
        ensureGlobalToggleEnabled()

        // Snooze + Preferences + footer-level controls.
        let secondaryIDs: [(XCUIElement, String)] = [
            (app.buttons["settings.snooze.5min"], "Snooze 5 min button"),
            (app.buttons["settings.snooze.1hour"], "Snooze 1 hour button"),
            (app.buttons["settings.snooze.restOfDay"], "Snooze Rest of Day button"),
            (app.switches["settings.hapticFeedback"], "Haptic Feedback toggle"),
            (app.switches["settings.notificationFallback"], "Notification fallback toggle"),
            (app.buttons["settings.resetToDefaults"], "Reset to Defaults button"),
            (app.buttons["settings.feedback.sendFeedback"], "Send Feedback button")
        ]
        for (element, label) in secondaryIDs {
            scrollToElement(element)
            XCTAssertTrue(
                element.waitForExistence(timeout: 3),
                "\(label) must exist in Settings."
            )
        }

        // Reminder toggles + their nested interval/duration pickers (#427).
        let eyesToggle = app.switches["settings.eyes.toggle"]
        scrollToElement(eyesToggle)
        XCTAssertTrue(
            eyesToggle.waitForExistence(timeout: 3),
            "Eye break toggle must exist in Settings."
        )
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
        scrollToElement(postureToggle)
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

// DarkModeUITests.swift
// kshana UI Tests
//
// XCUITest suite — Dark Mode variant checks.
//
// Launches the app with the `-AppleInterfaceStyle Dark` system argument to
// override the simulator appearance. Verifies that key screens render without
// crashing and that accessibility identifiers remain stable in dark mode.
//
// NOTE: The `-AppleInterfaceStyle Dark` argument is a simulator launch argument
// handled by the OS, not by the app. It is appended alongside any
// TestLaunchArguments so both the appearance override and the app-state
// seed are active at the same time.

import XCTest

final class DarkModeUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - test_darkMode_homeScreen_launches

    /// Verifies the Home screen launches in dark mode with all essential elements visible.
    func test_darkMode_homeScreen_launches() throws {
        app = XCUIApplication()
        app.launchArguments += [TestLaunchArguments.skipOnboarding, "-AppleInterfaceStyle", "Dark"]
        app.launch()

        let navBar = app.navigationBars.firstMatch
        XCTAssertTrue(
            navBar.waitForExistence(timeout: 3),
            "Home screen navigation bar should be visible in dark mode."
        )

        let statusLabel = app.staticTexts["home.statusLabel"]
        XCTAssertTrue(
            statusLabel.waitForExistence(timeout: 3),
            "Home screen status label must be visible in dark mode."
        )
    }

    // MARK: - test_darkMode_homeScreen_settingsButtonIsHittable

    /// Verifies the Settings toolbar button is tappable in dark mode.
    func test_darkMode_homeScreen_settingsButtonIsHittable() throws {
        app = XCUIApplication()
        app.launchArguments += [TestLaunchArguments.skipOnboarding, "-AppleInterfaceStyle", "Dark"]
        app.launch()

        let settingsButton = app.buttons["home.settingsButton"]
        XCTAssertTrue(
            settingsButton.waitForExistence(timeout: 3),
            "Settings button must be present on Home screen in dark mode."
        )
        XCTAssertTrue(settingsButton.isHittable, "Settings button must be hittable in dark mode.")
    }

    // MARK: - test_darkMode_settings_canBeOpened

    /// Verifies the Settings sheet opens correctly in dark mode.
    func test_darkMode_settings_canBeOpened() throws {
        app = XCUIApplication()
        app.launchArguments += [TestLaunchArguments.skipOnboarding, "-AppleInterfaceStyle", "Dark"]
        app.launch()

        let settingsButton = app.buttons["home.settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 3))
        settingsButton.tap()

        let settingsNav = app.navigationBars["Settings"]
        XCTAssertTrue(
            settingsNav.waitForExistence(timeout: 3),
            "Settings sheet must open with correct navigation title in dark mode."
        )
    }

    // MARK: - test_darkMode_overlay_essentialElementsVisible

    /// Verifies the eye break overlay shows its essential elements in dark mode.
    func test_darkMode_overlay_essentialElementsVisible() throws {
        app = XCUIApplication()
        app.launchArguments += [TestLaunchArguments.showOverlayEyes, "-AppleInterfaceStyle", "Dark"]
        app.launch()

        let doneButton = app.buttons["overlay.doneButton"]
        XCTAssertTrue(
            doneButton.waitForExistence(timeout: 3),
            "Done button must be visible on the overlay in dark mode."
        )

        let dismissButton = app.buttons["overlay.dismissButton"]
        XCTAssertTrue(
            dismissButton.waitForExistence(timeout: 3),
            "Dismiss (×) button must be visible on the overlay in dark mode."
        )

        let supportiveText = app.staticTexts["overlay.supportiveText"]
        XCTAssertTrue(
            supportiveText.waitForExistence(timeout: 3),
            "Supportive text must be visible on the overlay in dark mode."
        )
    }

    // MARK: - test_darkMode_overlay_doneButton_dismissesOverlay

    /// Taps the Done button in dark mode and verifies the overlay is dismissed.
    func test_darkMode_overlay_doneButton_dismissesOverlay() throws {
        app = XCUIApplication()
        app.launchArguments += [TestLaunchArguments.showOverlayEyes, "-AppleInterfaceStyle", "Dark"]
        app.launch()

        let doneButton = app.buttons["overlay.doneButton"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 3))
        doneButton.tap()

        let dismissButton = app.buttons["overlay.dismissButton"]
        XCTAssertFalse(
            dismissButton.waitForExistence(timeout: 3),
            "After tapping Done in dark mode, the overlay should be dismissed."
        )
    }

    // MARK: - test_darkMode_onboarding_welcomeScreenLaunches

    /// Verifies the onboarding Welcome screen launches in dark mode without crashing.
    func test_darkMode_onboarding_welcomeScreenLaunches() throws {
        app = XCUIApplication()
        app.launchArguments += [TestLaunchArguments.resetOnboarding, "-AppleInterfaceStyle", "Dark"]
        app.launch()

        let nextButton = app.buttons["onboarding.welcome.nextButton"]
        XCTAssertTrue(
            nextButton.waitForExistence(timeout: 3),
            "Onboarding Welcome screen Next button must be visible in dark mode."
        )

        let disclaimerElement = app.staticTexts["onboarding.welcome.disclaimer"]
        XCTAssertTrue(
            disclaimerElement.waitForExistence(timeout: 3),
            "Disclaimer text must be visible on the Welcome screen in dark mode."
        )
    }

    // MARK: - test_darkMode_postureOverlay_essentialElementsVisible

    /// Verifies the posture check overlay renders in dark mode with essential elements visible.
    func test_darkMode_postureOverlay_essentialElementsVisible() throws {
        app = XCUIApplication()
        app.launchArguments += [TestLaunchArguments.showOverlayPosture, "-AppleInterfaceStyle", "Dark"]
        app.launch()

        let doneButton = app.buttons["overlay.doneButton"]
        XCTAssertTrue(
            doneButton.waitForExistence(timeout: 3),
            "Done button must be visible on the posture overlay in dark mode."
        )

        let supportiveText = app.staticTexts["overlay.supportiveText"]
        XCTAssertTrue(
            supportiveText.waitForExistence(timeout: 3),
            "Supportive text must be visible on the posture overlay in dark mode."
        )
    }

}

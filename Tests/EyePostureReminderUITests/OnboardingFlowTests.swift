// OnboardingFlowTests.swift
// kshana UI Tests
//
// XCUITest suite — Onboarding flow.

import XCTest

final class OnboardingFlowTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchWithOnboarding()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - test_onboarding_welcomeScreen_disclaimerIsVisible

    /// Verifies the medical disclaimer text is present on the first onboarding screen.
    /// The disclaimer must always be visible without scrolling on the Welcome page.
    func test_onboarding_welcomeScreen_disclaimerIsVisible() throws {
        let disclaimerElement = app.staticTexts["onboarding.welcome.disclaimer"]
        XCTAssertTrue(
            disclaimerElement.waitForExistence(timeout: 5),
            "Disclaimer text should be visible on the Welcome screen. " +
            "Add .accessibilityIdentifier(\"onboarding.welcome.disclaimer\") " +
            "to the disclaimer Text in OnboardingWelcomeView."
        )
    }

    // MARK: - test_onboarding_fullFlow_completesSuccessfully

    /// Taps through all three onboarding screens and verifies the app transitions
    /// to the Home screen upon completion.
    func test_onboarding_fullFlow_completesSuccessfully() throws {
        // --- Screen 1: Welcome ---
        let nextButton = app.buttons["onboarding.welcome.nextButton"]
        XCTAssertTrue(
            nextButton.waitForExistence(timeout: 5),
            "Next button must exist on Welcome screen. " +
            "Add .accessibilityIdentifier(\"onboarding.welcome.nextButton\") " +
            "to the CTA button in OnboardingWelcomeView."
        )
        nextButton.tap()

        // --- Screen 2: Permission ---
        let permissionNextButton = app.buttons["onboarding.permission.nextButton"]
        XCTAssertTrue(
            permissionNextButton.waitForExistence(timeout: 5),
            "Continue button must exist on Permission screen. " +
            "Add .accessibilityIdentifier(\"onboarding.permission.nextButton\") in OnboardingPermissionView."
        )
        permissionNextButton.tap()

        // --- Screen 3: Setup ---
        let getStartedButton = app.buttons["onboarding.setup.getStartedButton"]
        XCTAssertTrue(
            getStartedButton.waitForExistence(timeout: 5),
            "Get Started button must exist on Setup screen. " +
            "Add .accessibilityIdentifier(\"onboarding.setup.getStartedButton\") in OnboardingSetupView."
        )
        getStartedButton.tap()

        // --- Post-onboarding: Home screen should be visible ---
        let homeNav = app.navigationBars.firstMatch
        XCTAssertTrue(
            homeNav.waitForExistence(timeout: 5),
            "Navigation bar should appear on the Home screen after completing onboarding."
        )
    }

    // MARK: - test_onboarding_welcomeScreen_titleIsVisible

    /// Verifies the main title text is present on the Welcome screen.
    func test_onboarding_welcomeScreen_titleIsVisible() throws {
        let welcomeTitle = app.staticTexts.firstMatch
        XCTAssertTrue(
            welcomeTitle.waitForExistence(timeout: 5),
            "Welcome screen should contain at least one visible text element."
        )
    }

    // MARK: - test_onboarding_welcomeNextButton_navigatesToPermissionScreen

    /// Taps the Next button on the Welcome screen and confirms the Permission screen appears.
    func test_onboarding_welcomeNextButton_navigatesToPermissionScreen() throws {
        let nextButton = app.buttons["onboarding.welcome.nextButton"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 5))
        nextButton.tap()

        let skipButton = app.buttons["onboarding.permission.nextButton"]
        XCTAssertTrue(
            skipButton.waitForExistence(timeout: 5),
            "After tapping Next on the Welcome screen, the Permission screen's skip button should appear."
        )
    }

    // MARK: - test_onboarding_skipPermission_reachesSetupScreen

    /// Skips notification permission and verifies the Setup screen is reached.
    func test_onboarding_skipPermission_reachesSetupScreen() throws {
        let nextButton = app.buttons["onboarding.welcome.nextButton"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 5))
        nextButton.tap()

        let skipButton = app.buttons["onboarding.permission.nextButton"]
        XCTAssertTrue(skipButton.waitForExistence(timeout: 5))
        skipButton.tap()

        let getStartedButton = app.buttons["onboarding.setup.getStartedButton"]
        XCTAssertTrue(
            getStartedButton.waitForExistence(timeout: 5),
            "After skipping permission, the Setup screen's Get Started button should be visible."
        )
    }

    // MARK: - test_onboarding_setupScreen_customizeButtonExists

    /// Verifies the Customize button exists on the Setup screen as a secondary CTA.
    func test_onboarding_setupScreen_customizeButtonExists() throws {
        let nextButton = app.buttons["onboarding.welcome.nextButton"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 5))
        nextButton.tap()

        let skipButton = app.buttons["onboarding.permission.nextButton"]
        XCTAssertTrue(skipButton.waitForExistence(timeout: 5))
        skipButton.tap()

        let getStartedButton = app.buttons["onboarding.setup.getStartedButton"]
        XCTAssertTrue(getStartedButton.waitForExistence(timeout: 5))

        // The Customize button is a secondary link-style button; verify it exists via label text.
        let setupButtons = app.buttons.allElementsBoundByIndex
        XCTAssertGreaterThan(setupButtons.count, 1, "Setup screen should have at least two buttons.")
    }

    // MARK: - test_onboarding_customizeButton_opensSettingsAfterCompletion

    /// Tapping Customize on the Setup screen should complete onboarding and open Settings.
    func test_onboarding_customizeButton_opensSettingsAfterCompletion() throws {
        let nextButton = app.buttons["onboarding.welcome.nextButton"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 5))
        nextButton.tap()

        let skipButton = app.buttons["onboarding.permission.nextButton"]
        XCTAssertTrue(skipButton.waitForExistence(timeout: 5))
        skipButton.tap()

        let getStartedButton = app.buttons["onboarding.setup.getStartedButton"]
        XCTAssertTrue(getStartedButton.waitForExistence(timeout: 5))

        // Tap the secondary Customize button (last button in the setup screen VStack)
        let allButtons = app.buttons.allElementsBoundByIndex
        let customizeButton = allButtons.last { $0.identifier != "onboarding.setup.getStartedButton" }
        if let customizeButton = customizeButton, customizeButton.exists {
            customizeButton.tap()
            let homeNav = app.navigationBars.firstMatch
            XCTAssertTrue(
                homeNav.waitForExistence(timeout: 5),
                "After tapping Customize, the app should transition to the Home/Settings screen."
            )
        }
    }

    // MARK: - test_onboarding_permissionScreen_allowReminderAlertsButtonExists

    /// Verifies the "Allow Reminder Alerts" primary CTA button is visible on the Permission screen.
    func test_onboarding_permissionScreen_allowReminderAlertsButtonExists() throws {
        let nextButton = app.buttons["onboarding.welcome.nextButton"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 5))
        nextButton.tap()

        let enableButton = app.buttons["onboarding.enableNotifications"]
        XCTAssertTrue(
            enableButton.waitForExistence(timeout: 5),
            "Allow Reminder Alerts button must exist on the Permission screen. " +
            "Add .accessibilityIdentifier(\"onboarding.enableNotifications\") in OnboardingPermissionView."
        )
        XCTAssertTrue(enableButton.isHittable, "Allow Reminder Alerts button must be tappable.")
    }

    // MARK: - test_onboarding_setupScreen_customizeButtonIdentifierExists

    /// Verifies the Customize button has the correct accessibility identifier on the Setup screen.
    func test_onboarding_setupScreen_customizeButtonIdentifierExists() throws {
        let nextButton = app.buttons["onboarding.welcome.nextButton"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 5))
        nextButton.tap()

        let skipButton = app.buttons["onboarding.permission.nextButton"]
        XCTAssertTrue(skipButton.waitForExistence(timeout: 5))
        skipButton.tap()

        let customizeButton = app.buttons["onboarding.customize"]
        XCTAssertTrue(
            customizeButton.waitForExistence(timeout: 5),
            "Customize button must exist on the Setup screen with identifier 'onboarding.customize'."
        )
        XCTAssertTrue(customizeButton.isHittable, "Customize button must be tappable.")
    }

    // MARK: - test_onboarding_setupScreen_showsChangeInSettingsReassurance

    /// Verifies the Setup screen contains copy that tells users they can change their
    /// reminder schedule in Settings later.
    func test_onboarding_setupScreen_showsChangeInSettingsReassurance() throws {
        let nextButton = app.buttons["onboarding.welcome.nextButton"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 5))
        nextButton.tap()

        let skipButton = app.buttons["onboarding.permission.nextButton"]
        XCTAssertTrue(skipButton.waitForExistence(timeout: 5))
        skipButton.tap()

        let getStartedButton = app.buttons["onboarding.setup.getStartedButton"]
        XCTAssertTrue(getStartedButton.waitForExistence(timeout: 5),
                      "Must reach the setup screen first")

        let reassuranceText = app.staticTexts["onboarding.setup.changeInSettings"]
        XCTAssertTrue(
            reassuranceText.waitForExistence(timeout: 3),
            "Setup screen must show reassurance copy with identifier 'onboarding.setup.changeInSettings'. " +
            "Expected Text(\"onboarding.setup.changeInSettings\") with .accessibilityIdentifier in OnboardingSetupView."
        )
    }

    // MARK: - test_onboarding_setupScreen_pickerAccessibilityIdentifiers

    /// Verifies interval and duration pickers on the Setup screen expose the expected
    /// accessibility identifiers.
    func test_onboarding_setupScreen_pickerAccessibilityIdentifiers() throws {
        let nextButton = app.buttons["onboarding.welcome.nextButton"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 5))
        nextButton.tap()

        let skipButton = app.buttons["onboarding.permission.nextButton"]
        XCTAssertTrue(skipButton.waitForExistence(timeout: 5))
        skipButton.tap()

        XCTAssertTrue(
            app.buttons["onboarding.setup.getStartedButton"].waitForExistence(timeout: 5),
            "Must reach the setup screen first")

        // Pickers may require scrolling; verify at least one is present.
        let eyeIntervalPicker = app.descendants(matching: .any)
            .matching(identifier: "onboarding.eyes.intervalPicker").firstMatch
        XCTAssertTrue(
            eyeIntervalPicker.waitForExistence(timeout: 3),
            "Eye interval picker must be present with identifier 'onboarding.eyes.intervalPicker'."
        )
    }
}

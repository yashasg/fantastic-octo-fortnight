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
            disclaimerElement.waitForExistence(timeout: 3),
            "Disclaimer text should be visible on the Welcome screen. " +
            "Add .accessibilityIdentifier(\"onboarding.welcome.disclaimer\") " +
            "to the disclaimer Text in OnboardingWelcomeView."
        )
    }

    // MARK: - test_onboarding_fullFlow_completesSuccessfully

    /// Taps through onboarding and verifies the app transitions
    /// to the Home screen upon completion.
    func test_onboarding_fullFlow_completesSuccessfully() throws {
        // --- Screen 1: Welcome ---
        let nextButton = app.buttons["onboarding.welcome.nextButton"]
        XCTAssertTrue(
            nextButton.waitForExistence(timeout: 3),
            "Next button must exist on Welcome screen. " +
            "Add .accessibilityIdentifier(\"onboarding.welcome.nextButton\") " +
            "to the CTA button in OnboardingWelcomeView."
        )
        nextButton.tap()

        // --- Screen 2: Permission ---
        let permissionNextButton = app.buttons["onboarding.permission.nextButton"]
        XCTAssertTrue(
            permissionNextButton.waitForExistence(timeout: 3),
            "Continue button must exist on Permission screen. " +
            "Add .accessibilityIdentifier(\"onboarding.permission.nextButton\") in OnboardingPermissionView."
        )
        permissionNextButton.tap()

        // --- Screen 3: Setup ---
        let getStartedButton = app.buttons["onboarding.setup.getStartedButton"]
        XCTAssertTrue(
            getStartedButton.waitForExistence(timeout: 3),
            "Get Started button must exist on Setup screen. " +
            "Add .accessibilityIdentifier(\"onboarding.setup.getStartedButton\") in OnboardingSetupView."
        )
        getStartedButton.tap()

        // --- Screen 4: True Interrupt Mode ---
        let interruptSkipButton = app.buttons["onboarding.interrupt.skipButton"]
        XCTAssertTrue(
            interruptSkipButton.waitForExistence(timeout: 3),
            "Skip button must exist on the True Interrupt Mode screen."
        )
        interruptSkipButton.tap()

        // --- Post-onboarding: Home screen should be visible ---
        let homeNav = app.navigationBars.firstMatch
        XCTAssertTrue(
            homeNav.waitForExistence(timeout: 3),
            "Navigation bar should appear on the Home screen after completing onboarding."
        )
    }

    // MARK: - test_onboarding_permissionScreen_controlsExist

    /// Verifies the permission screen exposes both continue and notification CTAs.
    func test_onboarding_permissionScreen_controlsExist() throws {
        navigateToPermission()

        let continueButton = app.buttons["onboarding.permission.nextButton"]
        XCTAssertTrue(
            continueButton.waitForExistence(timeout: 3),
            "After tapping Next on the Welcome screen, the Permission screen's continue button should appear."
        )

        let enableButton = app.buttons["onboarding.enableNotifications"]
        XCTAssertTrue(
            enableButton.waitForExistence(timeout: 3),
            "Allow Reminder Alerts button must exist on the Permission screen. " +
            "Add .accessibilityIdentifier(\"onboarding.enableNotifications\") in OnboardingPermissionView."
        )
        XCTAssertTrue(enableButton.isHittable, "Allow Reminder Alerts button must be tappable.")
    }

    // MARK: - test_onboarding_setupScreen_controlsExist

    /// Verifies the setup screen exposes its primary CTA, picker identifiers, and reassurance copy.
    func test_onboarding_setupScreen_controlsExist() throws {
        navigateToSetup()

        let getStartedButton = app.buttons["onboarding.setup.getStartedButton"]
        XCTAssertTrue(getStartedButton.waitForExistence(timeout: 3))

        let eyeIntervalPicker = onboardingElement(identifier: "onboarding.eyes.intervalPicker")
        XCTAssertTrue(
            eyeIntervalPicker.waitForExistence(timeout: 3),
            "Setup screen should expose the eye-break interval picker."
        )

        let postureIntervalPicker = onboardingElement(identifier: "onboarding.posture.intervalPicker")
        XCTAssertTrue(
            postureIntervalPicker.waitForExistence(timeout: 3),
            "Setup screen should expose the posture-check interval picker."
        )

        let durationPicker = onboardingElement(identifier: "onboarding.eyes.durationPicker")
        XCTAssertTrue(
            durationPicker.waitForExistence(timeout: 3),
            "Eye break duration picker must exist on the Setup screen with identifier 'onboarding.eyes.durationPicker'."
        )

        let reassuranceText = app.staticTexts["onboarding.setup.changeInSettings"]
        XCTAssertTrue(
            reassuranceText.waitForExistence(timeout: 3),
            "Setup screen must show reassurance copy with identifier 'onboarding.setup.changeInSettings'. " +
            "Expected Text(\"onboarding.setup.changeInSettings\") with .accessibilityIdentifier in OnboardingSetupView."
        )
    }

    // MARK: - test_onboarding_interruptMode_actionsExistAndSetupPreviewOpensAppPicker

    /// Verifies True Interrupt Mode exposes skip, customize, and setup-preview actions.
    func test_onboarding_interruptMode_actionsExistAndSetupPreviewOpensAppPicker() throws {
        navigateToInterruptMode()

        let interruptSkipButton = app.buttons["onboarding.interrupt.skipButton"]
        XCTAssertTrue(
            interruptSkipButton.waitForExistence(timeout: 3),
            "After tapping Get Started, the app should show the True Interrupt Mode screen."
        )

        let setupPreviewButton = app.buttons["onboarding.interrupt.enableButton"]
        XCTAssertTrue(
            setupPreviewButton.waitForExistence(timeout: 3),
            "True Interrupt screen must expose the setup preview button."
        )

        if !setupPreviewButton.isHittable {
            app.swipeUp()
        }

        let customizeButton = app.buttons["onboarding.interrupt.customizeButton"]
        XCTAssertTrue(
            app.revealAndWaitForHittable(customizeButton, timeout: 5, maxSwipes: 4),
            "\"Customize Settings\" tertiary CTA must exist on the True Interrupt Mode screen. " +
            "Ensure onCustomize is non-nil in OnboardingView and " +
            ".accessibilityIdentifier(\"onboarding.interrupt.customizeButton\") is set."
        )
        XCTAssertTrue(customizeButton.isHittable, "\"Customize Settings\" button must be tappable.")

        XCTAssertTrue(setupPreviewButton.isHittable, "Setup preview button must be tappable during onboarding.")
        setupPreviewButton.tap()

        let unavailableBanner = onboardingElement(identifier: "appCategoryPicker.unavailableBanner")
        XCTAssertTrue(
            unavailableBanner.waitForExistence(timeout: 3),
            "App/category setup preview must open and explain the current Screen Time availability state."
        )
    }

    // MARK: - test_onboarding_customizeButton_opensSettingsAfterCompletion

    /// Tapping "Customize Settings" completes onboarding and opens the Settings sheet.
    func test_onboarding_customizeButton_opensSettingsAfterCompletion() throws {
        navigateToInterruptMode()

        let customizeButton = app.buttons["onboarding.interrupt.customizeButton"]
        XCTAssertTrue(app.revealAndWaitForHittable(customizeButton, timeout: 5, maxSwipes: 4))
        customizeButton.tap()

        // After tapping Customize Settings, onboarding completes and HomeView opens Settings
        // automatically via openSettingsOnLaunch. Assert the Settings sheet is present.
        let doneButton = app.buttons["settings.doneButton"]
        XCTAssertTrue(
            doneButton.waitForExistence(timeout: 3),
            "Settings sheet should open automatically after tapping \"Customize Settings\". " +
            "HomeView reads openSettingsOnLaunch and presents SettingsView on appear."
        )
    }
}

private extension OnboardingFlowTests {
    func navigateToPermission() {
        let nextButton = app.buttons["onboarding.welcome.nextButton"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 3))
        nextButton.tap()
    }

    func navigateToSetup() {
        navigateToPermission()

        let continueButton = app.buttons["onboarding.permission.nextButton"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 3))
        continueButton.tap()
    }

    func navigateToInterruptMode() {
        navigateToSetup()

        let getStartedButton = app.buttons["onboarding.setup.getStartedButton"]
        XCTAssertTrue(getStartedButton.waitForExistence(timeout: 3))
        getStartedButton.tap()
    }

    func onboardingElement(identifier: String) -> XCUIElement {
        let picker = app.pickers[identifier]
        if picker.exists { return picker }

        let button = app.buttons[identifier]
        if button.exists { return button }

        let staticText = app.staticTexts[identifier]
        if staticText.exists { return staticText }

        return app.otherElements[identifier]
    }
}

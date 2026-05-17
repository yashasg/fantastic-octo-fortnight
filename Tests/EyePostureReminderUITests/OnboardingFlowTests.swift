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

    // MARK: - test_onboarding_welcome_accessibilityIDsPresent

    /// Single accessibility-identifier sanity check for the Welcome onboarding
    /// screen (#806 Phase 1). Collapses the previous per-screen identifier
    /// existence sweeps (`test_onboarding_permissionScreen_controlsExist`,
    /// `test_onboarding_setupScreen_controlsExist`) into the one screen we
    /// haven't covered with a reducer test. The medical disclaimer must be
    /// visible without scrolling and the Next CTA must be present and hittable.
    func test_onboarding_welcome_accessibilityIDsPresent() throws {
        let disclaimerElement = app.staticTexts["onboarding.welcome.disclaimer"]
        XCTAssertTrue(
            disclaimerElement.waitForExistence(timeout: 3),
            "Disclaimer text should be visible on the Welcome screen. " +
            "Add .accessibilityIdentifier(\"onboarding.welcome.disclaimer\") " +
            "to the disclaimer Text in OnboardingWelcomeView."
        )

        let nextButton = app.buttons["onboarding.welcome.nextButton"]
        XCTAssertTrue(
            nextButton.waitForExistence(timeout: 3),
            "Next CTA must exist on the Welcome screen. " +
            "Add .accessibilityIdentifier(\"onboarding.welcome.nextButton\") in OnboardingWelcomeView."
        )
        XCTAssertTrue(nextButton.isHittable, "Welcome Next CTA must be tappable.")
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

    // MARK: - test_onboarding_interruptMode_actionsExistAndComingSoonIsDisabled

    /// Verifies True Interrupt Mode exposes skip/customize actions and keeps pre-entitlement setup disabled.
    func test_onboarding_interruptMode_actionsExistAndComingSoonIsDisabled() throws {
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

        let customizeButton = app.buttons["onboarding.interrupt.customizeButton"]
        XCTAssertTrue(
            app.revealAndWaitForHittable(customizeButton, timeout: 5, maxSwipes: 4),
            "\"Customize Settings\" tertiary CTA must exist on the True Interrupt Mode screen. " +
            "Ensure onCustomize is non-nil in OnboardingView and " +
            ".accessibilityIdentifier(\"onboarding.interrupt.customizeButton\") is set."
        )
        XCTAssertTrue(customizeButton.isHittable, "\"Customize Settings\" button must be tappable.")
        XCTAssertFalse(
            setupPreviewButton.isEnabled,
            "Pre-entitlement setup preview must remain disabled instead of opening a locked picker flow."
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
}

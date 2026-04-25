// OnboardingFlowTests.swift
// EyePostureReminderUITests
//
// XCUITest suite — Onboarding flow.
//
// ⚠️  SPM LIMITATION: XCUITest requires a UITest bundle target which cannot be
// declared in Package.swift (SPM has no `.uiTestTarget` product type). These
// tests are written and ready to run, but require an Xcode project (.xcodeproj)
// with a dedicated UITest target that links this file. See decision-inbox note
// in .squad/decisions-inbox/ui-test-xcodeproj-required.md for details.
//
// ACCESSIBILITY IDENTIFIERS NEEDED (to be added to source views):
//   OnboardingWelcomeView:
//     - disclaimer Text          → .accessibilityIdentifier("onboarding.welcome.disclaimer")
//     - "Next" button            → .accessibilityIdentifier("onboarding.welcome.nextButton")
//   OnboardingPermissionView:
//     - "Continue" / next button → .accessibilityIdentifier("onboarding.permission.nextButton")
//   OnboardingSetupView:
//     - "Get Started" button     → .accessibilityIdentifier("onboarding.setup.getStartedButton")

import XCTest

final class OnboardingFlowTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Fresh-install state: forces onboarding to show.
        app.launchArguments += ["--reset-onboarding"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - testDisclaimerVisibleOnWelcomeScreen

    /// Verifies the medical disclaimer text is present on the first onboarding screen.
    /// The disclaimer must always be visible without scrolling on the Welcome page.
    func testDisclaimerVisibleOnWelcomeScreen() throws {
        // The welcome screen is page 0 — it should be visible immediately after launch
        // when onboarding has not been completed.
        let disclaimerElement = app.staticTexts["onboarding.welcome.disclaimer"]
        XCTAssertTrue(
            disclaimerElement.waitForExistence(timeout: 5),
            "Disclaimer text should be visible on the Welcome screen. " +
            "Add .accessibilityIdentifier(\"onboarding.welcome.disclaimer\") " +
            "to the disclaimer Text in OnboardingWelcomeView."
        )
    }

    // MARK: - testOnboardingCompletesSuccessfully

    /// Taps through all three onboarding screens and verifies the app transitions
    /// to the Home screen upon completion.
    func testOnboardingCompletesSuccessfully() throws {
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
        // HomeView's navigation title is "home.navTitle" → resolved string "Eye & Posture"
        let homeNav = app.navigationBars.firstMatch
        XCTAssertTrue(
            homeNav.waitForExistence(timeout: 5),
            "Navigation bar should appear on the Home screen after completing onboarding."
        )
    }
}

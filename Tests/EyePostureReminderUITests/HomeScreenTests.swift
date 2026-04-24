// HomeScreenTests.swift
// EyePostureReminderUITests
//
// XCUITest suite — Home screen verification.
//
// ⚠️  SPM LIMITATION: See OnboardingFlowTests.swift header for full note.
//
// ACCESSIBILITY IDENTIFIERS NEEDED (to be added to source views):
//   HomeView:
//     - Status icon Image        → .accessibilityIdentifier("home.statusIcon")
//     - Title Text               → .accessibilityIdentifier("home.title")
//     - Status label Text        → .accessibilityIdentifier("home.statusLabel")
//     - Settings toolbar button  → .accessibilityIdentifier("home.settingsButton")
//   SettingsView snooze section:
//     - "Snooze 5 min" button    → .accessibilityIdentifier("settings.snooze.5min")

import XCTest

final class HomeScreenTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Skip onboarding so tests start from the Home screen.
        app.launchArguments += ["--skip-onboarding"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - testHomeScreenLoads

    /// Verifies the essential Home screen elements are present after launch:
    /// the navigation bar, status icon, title text, status label, and settings button.
    func testHomeScreenLoads() throws {
        // Navigation bar (HomeView uses .navigationTitle set via NavigationStack in ContentView)
        let navBar = app.navigationBars.firstMatch
        XCTAssertTrue(
            navBar.waitForExistence(timeout: 5),
            "Home screen navigation bar should be visible on launch."
        )

        // Status icon (the eye / moon icon at the top of the VStack)
        let statusIcon = app.images["home.statusIcon"]
        XCTAssertTrue(
            statusIcon.waitForExistence(timeout: 5),
            "Home screen status icon must be visible. " +
            "Add .accessibilityIdentifier(\"home.statusIcon\") to the status Image in HomeView."
        )

        // Title text
        let titleText = app.staticTexts["home.title"]
        XCTAssertTrue(
            titleText.waitForExistence(timeout: 5),
            "Home screen title must be visible. " +
            "Add .accessibilityIdentifier(\"home.title\") to the title Text in HomeView."
        )

        // Status label (active / paused)
        let statusLabel = app.staticTexts["home.statusLabel"]
        XCTAssertTrue(
            statusLabel.waitForExistence(timeout: 5),
            "Home screen status label must be visible. " +
            "Add .accessibilityIdentifier(\"home.statusLabel\") to the status Text in HomeView."
        )

        // Settings toolbar button
        let settingsButton = app.buttons["home.settingsButton"]
        XCTAssertTrue(
            settingsButton.waitForExistence(timeout: 5),
            "Settings toolbar button must be visible on the Home screen. " +
            "Add .accessibilityIdentifier(\"home.settingsButton\") to the toolbar button in HomeView."
        )
    }

    // MARK: - testSnoozeButtonExists

    /// Verifies that the snooze button in Settings is accessible and tappable.
    /// Snooze is exposed via the Settings sheet — open settings and verify snooze row present.
    func testSnoozeButtonExists() throws {
        // Open Settings to access snooze controls
        let settingsButton = app.buttons["home.settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        // The snooze section is near the top of the form (below master toggle and
        // per-type sections when master is enabled). The "Snooze 5 min" button
        // is the most stable identifier for this test.
        let snoozeButton = app.buttons["settings.snooze.5min"]
        XCTAssertTrue(
            snoozeButton.waitForExistence(timeout: 5),
            "Snooze 5 min button must be present and tappable in Settings. " +
            "Add .accessibilityIdentifier(\"settings.snooze.5min\") to the snooze button in SettingsView."
        )
        XCTAssertTrue(snoozeButton.isHittable, "Snooze button should be tappable.")
    }
}

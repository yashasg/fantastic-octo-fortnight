// UITestHelpers.swift
// kshana UI Tests
//
// Shared launch-argument constants and XCUIApplication helpers for UI test setup.
// All arguments are handled in AppDelegate.applyUITestLaunchArguments().

import XCTest

// MARK: - TestLaunchArguments

/// Constants for launch arguments injected by UI tests to pre-seed app state.
/// Handled in `AppDelegate.applyUITestLaunchArguments()`.
enum TestLaunchArguments {
    /// Sets `hasSeenOnboarding = true` before launch → app opens on the Home screen.
    static let skipOnboarding = "--skip-onboarding"
    /// Clears `hasSeenOnboarding` → app starts fresh with the onboarding flow.
    static let resetOnboarding = "--reset-onboarding"
    /// Triggers the eye break overlay immediately on launch; used by OverlayTests and DarkModeUITests to display the overlay without waiting for the timer.
    static let showOverlayEyes = "--show-overlay-eyes"
    /// Triggers the posture check overlay immediately on launch; used by OverlayTests and DarkModeUITests to display the overlay without waiting for the timer.
    static let showOverlayPosture = "--show-overlay-posture"
    /// Seeds `ScreenTimeAuthorizationStub(.notDetermined)` into `AppCoordinator` so the
    /// TrueInterruptSkippedBanner and TrueInterruptSetupPill can render in UITests.
    /// The simulator's real FamilyControls status is `.unavailable`; without this arg
    /// neither element would ever appear (#399).
    static let simulateScreenTimeNotDetermined = "--simulate-screen-time-not-determined"
}

// MARK: - XCUIApplication + Test Helpers

extension XCUIApplication {
    /// Appends `--skip-onboarding` and launches the app.
    /// Use in `setUpWithError()` for tests that start from the Home screen.
    func launchWithSkippedOnboarding() {
        launchArguments += [TestLaunchArguments.skipOnboarding]
        launch()
    }

    /// Appends `--reset-onboarding` and launches the app.
    /// Use in `setUpWithError()` for tests that verify the onboarding flow from scratch.
    func launchWithOnboarding() {
        launchArguments += [TestLaunchArguments.resetOnboarding]
        launch()
    }

    /// Appends `--show-overlay-eyes` and launches the app.
    /// Use in tests that verify the eye break overlay UI.
    func launchWithEyeOverlay() {
        launchArguments += [TestLaunchArguments.showOverlayEyes]
        launch()
    }

    /// Appends `--show-overlay-posture` and launches the app.
    /// Use in tests that verify the posture check overlay UI.
    func launchWithPostureOverlay() {
        launchArguments += [TestLaunchArguments.showOverlayPosture]
        launch()
    }

    /// Seeds `.notDetermined` Screen Time authorization state and launches on the Home screen.
    ///
    /// Use in tests that verify `TrueInterruptSkippedBanner` (banner not yet dismissed) and
    /// `TrueInterruptSetupPill` (banner dismissed). The simulator's real FamilyControls status
    /// is `.unavailable`, so this argument is required to reach either element (#399).
    func launchWithTrueInterruptPending() {
        launchArguments += [
            TestLaunchArguments.skipOnboarding,
            TestLaunchArguments.simulateScreenTimeNotDetermined
        ]
        launch()
    }

    /// Waits for the Home screen anchor element (`home.title`) to be present,
    /// confirming that the view hierarchy has fully rendered after launch.
    ///
    /// Call immediately after `launchWithTrueInterruptPending()` (or any launch
    /// targeting the Home screen) so that subsequent element queries find a stable
    /// accessibility tree rather than a partially-rendered layout.
    ///
    /// - Returns: `true` if the anchor appears within `timeout`; `false` otherwise.
    @discardableResult
    func waitForHomeScreenReady(timeout: TimeInterval = 5) -> Bool {
        staticTexts["home.title"].waitForExistence(timeout: timeout)
    }

    /// Waits until the overlay's primary controls and supportive text are queryable.
    ///
    /// This reduces flakes where one element is queried before the accessibility tree
    /// has fully stabilized after launch.
    @discardableResult
    func waitForOverlayReady(timeout: TimeInterval = 5) -> Bool {
        let doneButton = buttons["overlay.doneButton"]
        let dismissButton = buttons["overlay.dismissButton"]
        let supportiveText = staticTexts["overlay.supportiveText"]
        return doneButton.waitForHittable(timeout: timeout)
            && dismissButton.waitForHittable(timeout: timeout)
            && supportiveText.waitForExistence(timeout: timeout)
    }
}

extension XCUIElement {
    /// Waits until the element both exists and is hittable.
    @discardableResult
    func waitForHittable(timeout: TimeInterval = 5) -> Bool {
        guard waitForExistence(timeout: timeout) else { return false }
        let predicate = NSPredicate(format: "hittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// Taps an element after waiting for a hittable state.
    @discardableResult
    func tapWhenHittable(timeout: TimeInterval = 5) -> Bool {
        guard waitForHittable(timeout: timeout) else { return false }
        tap()
        return true
    }

}

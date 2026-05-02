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
    /// System-provided launch argument key for interface style override.
    static let appleInterfaceStyle = "-AppleInterfaceStyle"
    /// System-provided dark appearance value for `-AppleInterfaceStyle`.
    static let darkAppearance = "Dark"
}

// MARK: - XCUIApplication + Test Helpers

extension XCUIApplication {
    private func appendDarkModeArgumentIfNeeded(_ darkMode: Bool) {
        guard darkMode else { return }
        launchArguments += [TestLaunchArguments.appleInterfaceStyle, TestLaunchArguments.darkAppearance]
    }

    /// Appends `--skip-onboarding` and launches the app.
    /// Use in `setUpWithError()` for tests that start from the Home screen.
    func launchWithSkippedOnboarding(darkMode: Bool = false) {
        launchArguments += [TestLaunchArguments.skipOnboarding]
        appendDarkModeArgumentIfNeeded(darkMode)
        launch()
    }

    /// Appends `--reset-onboarding` and launches the app.
    /// Use in `setUpWithError()` for tests that verify the onboarding flow from scratch.
    func launchWithOnboarding(darkMode: Bool = false) {
        launchArguments += [TestLaunchArguments.resetOnboarding]
        appendDarkModeArgumentIfNeeded(darkMode)
        launch()
    }

    /// Appends `--show-overlay-eyes` and launches the app.
    /// Use in tests that verify the eye break overlay UI.
    func launchWithEyeOverlay(darkMode: Bool = false) {
        launchArguments += [TestLaunchArguments.showOverlayEyes]
        appendDarkModeArgumentIfNeeded(darkMode)
        launch()
    }

    /// Appends `--show-overlay-posture` and launches the app.
    /// Use in tests that verify the posture check overlay UI.
    func launchWithPostureOverlay(darkMode: Bool = false) {
        launchArguments += [TestLaunchArguments.showOverlayPosture]
        appendDarkModeArgumentIfNeeded(darkMode)
        launch()
    }

    /// Seeds `.notDetermined` Screen Time authorization state and launches on the Home screen.
    ///
    /// Use in tests that verify `TrueInterruptSkippedBanner` (banner not yet dismissed) and
    /// `TrueInterruptSetupPill` (banner dismissed). The simulator's real FamilyControls status
    /// is `.unavailable`, so this argument is required to reach either element (#399).
    func launchWithTrueInterruptPending(darkMode: Bool = false) {
        launchArguments += [
            TestLaunchArguments.skipOnboarding,
            TestLaunchArguments.simulateScreenTimeNotDetermined
        ]
        appendDarkModeArgumentIfNeeded(darkMode)
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

    /// Waits for a single "overlay fully presented" anchor using a two-phase,
    /// independent-deadline strategy that eliminates the time-budget bleed race.
    ///
    /// **Why two phases?**
    /// The overlay trigger chain is:
    ///   `launch → scheduleReminders() async → handleNotification
    ///    → UIWindow.makeKeyAndVisible → SwiftUI render → onAppear
    ///    → 0.5 s entrance animation`
    /// Under CI load this chain can consume most of a shared 2.5 s budget,
    /// leaving the entrance-animation wait starved (< 0.1 s) and the test flaky.
    ///
    /// Phase 1 (`timeout`): wait for `overlay.root` existence — accounts for
    ///   the async launch + scheduleReminders chain.
    /// Phase 2 (fixed 2.0 s fresh budget): wait for `overlay.doneButton`
    ///   hittability — accounts for the 0.5 s entrance animation with 4× margin,
    ///   independent of how long Phase 1 took.
    ///
    /// Tests should call this once, then use shorter follow-up waits for
    /// secondary elements (dismiss button, supportive text, settings link).
    @discardableResult
    func waitForOverlayPresented(timeout: TimeInterval = 5) -> Bool {
        guard otherElements["overlay.root"].waitForExistence(timeout: timeout) else { return false }
        // Fresh independent budget: entrance animation is ~0.5 s; 2.0 s gives 4× margin.
        return buttons["overlay.doneButton"].waitForHittable(timeout: 2.0)
    }

    /// Waits for overlay dismissal using a positive fallback state and explicit
    /// overlay-root disappearance.
    @discardableResult
    func waitForOverlayDismissed(timeout: TimeInterval = 3) -> Bool {
        let overlayRoot = otherElements["overlay.root"]
        let dismissalDeadline = Date().addingTimeInterval(timeout)
        guard waitForHomeScreenReady(timeout: timeout) else { return false }
        let remaining = max(0.1, dismissalDeadline.timeIntervalSinceNow)
        return overlayRoot.waitForNonExistence(timeout: remaining)
    }

    /// Backward-compatible alias kept for existing tests.
    @discardableResult
    func waitForOverlayReady(timeout: TimeInterval = 5) -> Bool {
        waitForOverlayPresented(timeout: timeout)
    }
}

extension XCUIElement {
    @discardableResult
    private func waitFor(predicate: NSPredicate, timeout: TimeInterval) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// Waits until the element both exists and is hittable.
    @discardableResult
    func waitForHittable(timeout: TimeInterval = 3) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        if !exists {
            let remainingToExist = max(0.1, deadline.timeIntervalSinceNow)
            guard waitForExistence(timeout: remainingToExist) else { return false }
        }

        let remainingToHittable = max(0.1, deadline.timeIntervalSinceNow)
        return waitFor(predicate: NSPredicate(format: "hittable == true"), timeout: remainingToHittable)
    }

    /// Waits until the element no longer exists in the accessibility tree.
    @discardableResult
    func waitForNonExistence(timeout: TimeInterval = 3) -> Bool {
        waitFor(predicate: NSPredicate(format: "exists == false"), timeout: timeout)
    }

    /// Waits until the element is not hittable (covers hidden-but-mounted cases).
    @discardableResult
    func waitForNotHittable(timeout: TimeInterval = 3) -> Bool {
        waitFor(predicate: NSPredicate(format: "hittable == false"), timeout: timeout)
    }

    /// Taps an element after waiting for a hittable state.
    @discardableResult
    func tapWhenHittable(timeout: TimeInterval = 3) -> Bool {
        guard waitForHittable(timeout: timeout) else { return false }
        tap()
        return true
    }

}

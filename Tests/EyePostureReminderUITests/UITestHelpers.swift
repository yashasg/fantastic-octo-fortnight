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
    /// Pre-seeds the True Interrupt skipped-banner dismissed flag so UITests can
    /// assert the setup pill directly without depending on an earlier banner tap.
    static let dismissTrueInterruptBanner = "--dismiss-true-interrupt-banner"
    /// Forces the non-dismissed True Interrupt banner state for deterministic
    /// UITest coverage, even if a prior run persisted the dismissed flag.
    static let showTrueInterruptBanner = "--show-true-interrupt-banner"
    /// System-provided launch argument key for interface style override.
    static let appleInterfaceStyle = "-AppleInterfaceStyle"
    /// System-provided dark appearance value for `-AppleInterfaceStyle`.
    static let darkAppearance = "Dark"
}

// MARK: - XCUIApplication + Test Helpers

extension XCUIApplication {
    private func launchFresh() {
        // `launch()` already relaunches the target app for a new XCUIApplication
        // session. Avoid explicit `terminate()` here: on loaded CI simulators it
        // can fail before XCTest has acquired a stable process assertion.
    }

    private func appendDarkModeArgumentIfNeeded(_ darkMode: Bool) {
        guard darkMode else { return }
        launchArguments += [TestLaunchArguments.appleInterfaceStyle, TestLaunchArguments.darkAppearance]
    }

    /// Appends `--skip-onboarding` and launches the app.
    /// Use in `setUpWithError()` for tests that start from the Home screen.
    func launchWithSkippedOnboarding(darkMode: Bool = false) {
        launchFresh()
        launchArguments += [TestLaunchArguments.skipOnboarding]
        appendDarkModeArgumentIfNeeded(darkMode)
        launch()

        // Defensive fallback: on some runners the launch-argument write may race
        // first-render initialization. Drive through onboarding if it is visible.
        if !waitForHomeScreenReady(timeout: 6) {
            completeOnboardingIfVisible(timeout: 20)
        }
    }

    /// Appends `--reset-onboarding` and launches the app.
    /// Use in `setUpWithError()` for tests that verify the onboarding flow from scratch.
    func launchWithOnboarding(darkMode: Bool = false) {
        launchFresh()
        launchArguments += [TestLaunchArguments.resetOnboarding]
        appendDarkModeArgumentIfNeeded(darkMode)
        launch()
    }

    /// Appends `--show-overlay-eyes` and launches the app.
    /// Use in tests that verify the eye break overlay UI.
    func launchWithEyeOverlay(darkMode: Bool = false) {
        launchFresh()
        launchArguments += [TestLaunchArguments.showOverlayEyes]
        appendDarkModeArgumentIfNeeded(darkMode)
        launch()
    }

    /// Appends `--show-overlay-posture` and launches the app.
    /// Use in tests that verify the posture check overlay UI.
    func launchWithPostureOverlay(darkMode: Bool = false) {
        launchFresh()
        launchArguments += [TestLaunchArguments.showOverlayPosture]
        appendDarkModeArgumentIfNeeded(darkMode)
        launch()
    }

    /// Seeds `.notDetermined` Screen Time authorization state and launches on the Home screen.
    ///
    /// Use in tests that verify `TrueInterruptSkippedBanner` (banner not yet dismissed) and
    /// `TrueInterruptSetupPill` (banner dismissed). The simulator's real FamilyControls status
    /// is `.unavailable`, so this argument is required to reach either element (#399).
    func launchWithTrueInterruptPending(darkMode: Bool = false, bannerDismissed: Bool = false) {
        launchFresh()
        launchArguments += [
            TestLaunchArguments.skipOnboarding,
            TestLaunchArguments.simulateScreenTimeNotDetermined,
            "-kshana.ui-test.screenTimeStatus",
            "notDetermined",
            "-kshana.trueInterruptSkippedBannerDismissed",
            bannerDismissed ? "true" : "false"
        ]
        if bannerDismissed {
            launchArguments += [TestLaunchArguments.dismissTrueInterruptBanner]
        } else {
            launchArguments += [TestLaunchArguments.showTrueInterruptBanner]
        }
        launchEnvironment["UITEST_SCREEN_TIME_STATUS"] = "notDetermined"
        launchEnvironment["UITEST_TRUE_INTERRUPT_BANNER_DISMISSED"] = bannerDismissed ? "true" : "false"
        appendDarkModeArgumentIfNeeded(darkMode)
        launch()
    }

    /// Waits for Home screen anchors to be present, confirming that the view
    /// hierarchy has rendered enough for toolbar-driven navigation.
    ///
    /// Call immediately after `launchWithTrueInterruptPending()` (or any launch
    /// targeting the Home screen) so that subsequent element queries find a stable
    /// accessibility tree rather than a partially-rendered layout.
    ///
    /// - Returns: `true` if the anchor appears within `timeout`; `false` otherwise.
    @discardableResult
    func waitForHomeScreenReady(timeout: TimeInterval = 8) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        let homeTitle = staticTexts["home.title"]
        let statusLabel = staticTexts["home.statusLabel"]
        let settingsButton = buttons["home.settingsButton"]

        while Date() < deadline {
            let remaining = max(0.1, deadline.timeIntervalSinceNow)
            let stepTimeout = min(0.75, remaining)
            if homeTitle.waitForExistence(timeout: stepTimeout)
                || statusLabel.waitForExistence(timeout: 0.1)
                || settingsButton.waitForExistence(timeout: 0.1) {
                return true
            }
            activate()
        }

        return homeTitle.exists || statusLabel.exists || settingsButton.exists
    }

    @discardableResult
    private func completeOnboardingIfVisible(timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if waitForHomeScreenReady(timeout: 0.5) {
                return true
            }

            if advanceOneOnboardingStep() {
                continue
            }

            activate()
            let step = min(0.25, max(0.05, deadline.timeIntervalSinceNow))
            RunLoop.current.run(until: Date().addingTimeInterval(step))
        }

        return waitForHomeScreenReady(timeout: 1)
    }

    @discardableResult
    private func advanceOneOnboardingStep() -> Bool {
        let onboardingButtons = [
            buttons["onboarding.welcome.nextButton"],
            buttons["onboarding.permission.nextButton"],
            buttons["onboarding.setup.getStartedButton"],
            buttons["onboarding.interrupt.skipButton"]
        ]

        for button in onboardingButtons {
            if !button.exists && !button.waitForExistence(timeout: 0.3) {
                continue
            }
            if !button.isHittable && !waitForElementHittable(button, timeout: 1.5) {
                continue
            }
            button.tap()
            return true
        }

        return false
    }

    /// Waits for a single "overlay fully presented" anchor.
    ///
    /// `overlay.doneButton` hittability is the most deterministic signal that:
    /// 1) the overlay exists, and
    /// 2) the entrance animation has completed enough for user interaction.
    ///
    /// Tests should call this once, then use shorter follow-up waits for
    /// secondary elements (dismiss button, supportive text, settings link).
    @discardableResult
    func waitForOverlayPresented(timeout: TimeInterval = 8) -> Bool {
        guard waitForOverlayVisible(timeout: timeout) else { return false }
        let doneButton = buttons["overlay.doneButton"]
        return waitForElementHittable(doneButton, timeout: timeout)
    }

    /// Waits until the overlay root exists, regardless of button hittability.
    @discardableResult
    func waitForOverlayVisible(timeout: TimeInterval = 8) -> Bool {
        otherElements["overlay.root"].waitForExistence(timeout: timeout)
    }

    /// Waits for overlay dismissal using a positive fallback state and explicit
    /// overlay-root disappearance.
    @discardableResult
    func waitForOverlayDismissed(timeout: TimeInterval = 3) -> Bool {
        let overlayRoot = otherElements["overlay.root"]
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if !overlayRoot.exists && waitForHomeScreenReady(timeout: 0.5) {
                return true
            }
            activate()
            let step = min(0.2, max(0.05, deadline.timeIntervalSinceNow))
            RunLoop.current.run(until: Date().addingTimeInterval(step))
        }

        return !overlayRoot.exists && waitForHomeScreenReady(timeout: 1)
    }

    /// Verifies that `overlay.root` never appears throughout the full observation window.
    @discardableResult
    func waitForOverlayToRemainAbsent(timeout: TimeInterval = 2, pollInterval: TimeInterval = 0.1) -> Bool {
        otherElements["overlay.root"].waitForContinuousNonExistence(timeout: timeout, pollInterval: pollInterval)
    }

    /// Backward-compatible alias kept for existing tests.
    @discardableResult
    func waitForOverlayReady(timeout: TimeInterval = 4) -> Bool {
        waitForOverlayPresented(timeout: timeout)
    }

    /// Waits for an element to become hittable and retries once after activating the app.
    @discardableResult
    func waitForElementHittable(_ element: XCUIElement, timeout: TimeInterval = 8) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        if element.waitForHittable(timeout: max(0.1, deadline.timeIntervalSinceNow)) {
            return true
        }
        activate()
        return element.waitForHittable(timeout: max(0.1, deadline.timeIntervalSinceNow))
    }

    /// Waits for an element to exist and retries once after activating the app.
    @discardableResult
    func waitForElementExists(_ element: XCUIElement, timeout: TimeInterval = 8) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        if element.waitForExistence(timeout: max(0.1, deadline.timeIntervalSinceNow)) {
            return true
        }
        activate()
        return element.waitForExistence(timeout: max(0.1, deadline.timeIntervalSinceNow))
    }

    /// Taps the center of an element after waiting for it to exist.
    @discardableResult
    func tapElementCenter(_ element: XCUIElement, timeout: TimeInterval = 8) -> Bool {
        guard waitForElementHittable(element, timeout: timeout) else { return false }
        element.tap()
        return true
    }

    /// Performs up to `maxSwipes` upward scrolls and waits for the element to become hittable.
    @discardableResult
    func revealAndWaitForHittable(
        _ element: XCUIElement,
        timeout: TimeInterval = 5,
        maxSwipes: Int = 3
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        for _ in 0...maxSwipes {
            if element.exists && element.isHittable { return true }
            let remaining = max(0.1, deadline.timeIntervalSinceNow)
            if element.waitForHittable(timeout: remaining) { return true }
            swipeUp()
        }
        return element.exists && element.isHittable
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
        while Date() < deadline {
            if !exists {
                let remaining = max(0.1, deadline.timeIntervalSinceNow)
                _ = waitForExistence(timeout: min(0.5, remaining))
            }
            if exists && isHittable {
                return true
            }
            let step = min(0.2, max(0.05, deadline.timeIntervalSinceNow))
            RunLoop.current.run(until: Date().addingTimeInterval(step))
        }

        return exists && isHittable
    }

    /// Waits until the element no longer exists in the accessibility tree.
    @discardableResult
    func waitForNonExistence(timeout: TimeInterval = 3) -> Bool {
        waitFor(predicate: NSPredicate(format: "exists == false"), timeout: timeout)
    }

    /// Verifies `exists == false` for the full timeout window, failing if the element appears at any point.
    @discardableResult
    func waitForContinuousNonExistence(timeout: TimeInterval = 3, pollInterval: TimeInterval = 0.1) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if exists { return false }
            let step = min(pollInterval, max(0.01, deadline.timeIntervalSinceNow))
            RunLoop.current.run(until: Date().addingTimeInterval(step))
        }
        return !exists
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

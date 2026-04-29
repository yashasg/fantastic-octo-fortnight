import Foundation

/// Centralised UserDefaults / AppStorage key constants for keys shared across
/// multiple files.
///
/// Using typed constants instead of raw string literals prevents typos from
/// silently breaking onboarding routing (a single-character mismatch causes
/// onboarding to repeat forever or be skipped permanently).
enum AppStorageKey {
    /// Set to `true` once the user completes the onboarding flow.
    /// Read by `ContentView` via `@AppStorage` to gate the main UI.
    static let hasSeenOnboarding = "kshana.hasSeenOnboarding"

    /// Set to `true` by `OnboardingView.finishOnboardingAndCustomize()` to
    /// signal that `HomeView` should immediately open the Settings sheet on appear.
    static let openSettingsOnLaunch = "kshana.openSettingsOnLaunch"

    /// Set by XCUITest launch argument handlers to trigger a specific overlay type on startup.
    /// Value matches `ReminderType.rawValue` ("eyes" or "posture"). Cleared after use.
    static let uiTestOverlayType = "kshana.ui-test.overlayType"

    /// Set to `true` when the user permanently dismisses the True Interrupt setup
    /// suggestion banner on Home (shown post-onboarding when setup was skipped).
    static let trueInterruptSkippedBannerDismissed = "kshana.trueInterruptSkippedBannerDismissed"
}

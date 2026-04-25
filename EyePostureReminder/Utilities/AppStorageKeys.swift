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
    static let hasSeenOnboarding = "epr.hasSeenOnboarding"

    /// Set to `true` by `OnboardingView.finishOnboardingAndCustomize()` to
    /// signal that `HomeView` should immediately open the Settings sheet on appear.
    static let openSettingsOnLaunch = "epr.openSettingsOnLaunch"
}

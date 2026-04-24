# UI Test README
## EyePostureReminderUITests

### Status
✅ Test files written — **not yet runnable** (see SPM limitation below).

### Test Files

| File | Tests |
|---|---|
| `OnboardingFlowTests.swift` | `testDisclaimerVisibleOnWelcomeScreen`, `testOnboardingCompletesSuccessfully` |
| `SettingsFlowTests.swift` | `testSettingsOpensFromHomeScreen`, `testDoneButtonDismissesSettings`, `testLegalSectionExists`, `testTermsSheetOpens`, `testPrivacySheetOpens`, `testSmartPauseTogglesExist` |
| `HomeScreenTests.swift` | `testHomeScreenLoads`, `testSnoozeButtonExists` |

### SPM Limitation

XCUITest bundles require a **UITest target type** which is **not supported by Swift Package Manager**. SPM only supports `.testTarget` (XCTest unit tests), not XCUITest UI test bundles.

To activate these tests, someone needs to add an `.xcodeproj` with a UITest target, or migrate to an Xcode project entirely. See `.squad/decisions-inbox/ui-test-xcodeproj-required.md`.

### Launch Arguments

Tests use `launchArguments` to control app state:

| Argument | Effect |
|---|---|
| `--skip-onboarding` | Sets `hasSeenOnboarding = true` before launch → app opens on Home screen |
| `--reset-onboarding` | Clears `hasSeenOnboarding` → app starts with onboarding flow |

**These arguments must be handled in `EyePostureReminderApp.swift` or `AppDelegate.swift`:**

```swift
// In App entry point or AppDelegate, before SwiftUI scene is created:
if CommandLine.arguments.contains("--skip-onboarding") {
    UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
}
if CommandLine.arguments.contains("--reset-onboarding") {
    UserDefaults.standard.removeObject(forKey: "hasSeenOnboarding")
}
```

### Accessibility Identifiers Required

The following `.accessibilityIdentifier()` modifiers must be added to source views before tests pass:

#### OnboardingWelcomeView
- Disclaimer `Text` → `"onboarding.welcome.disclaimer"`
- Next `Button` → `"onboarding.welcome.nextButton"`

#### OnboardingPermissionView
- Continue/next `Button` → `"onboarding.permission.nextButton"`

#### OnboardingSetupView
- Get Started `Button` → `"onboarding.setup.getStartedButton"`

#### HomeView
- Status icon `Image` → `"home.statusIcon"`
- Title `Text` → `"home.title"`
- Status label `Text` → `"home.statusLabel"`
- Settings toolbar `Button` → `"home.settingsButton"`

#### SettingsView
- Done toolbar `Button` → `"settings.doneButton"`
- Focus Mode `Toggle` → `"settings.smartPause.pauseDuringFocus"`
- Driving `Toggle` → `"settings.smartPause.pauseWhileDriving"`
- Terms row `Button` → `"settings.legal.terms"`
- Privacy row `Button` → `"settings.legal.privacy"`
- Snooze 5 min `Button` → `"settings.snooze.5min"`

#### LegalDocumentView
- Dismiss `Button` → `"legal.dismissButton"`

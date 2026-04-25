# UI Test README
## EyePostureReminderUITests

### Status
✅ Test files written and production code updated with accessibility identifiers + launch arg handling.
⚠️ **Not yet runnable** (see SPM limitation below).

### Test Files

| File | Tests |
|---|---|
| `OnboardingFlowTests.swift` | `testDisclaimerVisibleOnWelcomeScreen`, `testOnboardingCompletesSuccessfully`, `testWelcomeScreenTitleIsVisible`, `testOnboardingNextButtonTapsToPermissionScreen`, `testOnboardingSkipPermissionReachesSetupScreen`, `testOnboardingSetupCustomizeButtonExists`, `testOnboardingCustomizeButtonOpensSettingsAfterCompletion` |
| `SettingsFlowTests.swift` | `testSettingsOpensFromHomeScreen`, `testDoneButtonDismissesSettings`, `testLegalSectionExists`, `testTermsSheetOpens`, `testPrivacySheetOpens`, `testSmartPauseTogglesExist`, `testMasterToggleIsVisible`, `testMasterToggleCanBeTapped`, `testHapticsToggleExists`, `testTermsSheetDismissReturnsToSettings`, `testPrivacySheetDismissReturnsToSettings`, `testFocusToggleCanBeTapped`, `testDrivingToggleCanBeTapped` |
| `HomeScreenTests.swift` | `testHomeScreenLoads`, `testSnoozeButtonExists`, `testHomeNavigationBarTitleIsCorrect`, `testSettingsButtonIsHittable`, `testStatusLabelChangesAfterTogglingMaster`, `testHomeScreenStatusLabelIsNotEmpty`, `testSettingsSheetCanBeOpenedAndClosed` |
| `OverlayTests.swift` | `testOverlayDismissButtonIdentifierIsDocumented`, `testOverlayNotPresentOnNormalLaunch`, `testHomeScreenIsVisibleNotOverlay`, `testOverlayCountdownAccessibilityLabelIsDocumented` |

### SPM Limitation

XCUITest bundles require a **UITest target type** which is **not supported by Swift Package Manager**. SPM only supports `.testTarget` (XCTest unit tests), not XCUITest UI test bundles.

To activate these tests, someone needs to add an `.xcodeproj` with a UITest target, or migrate to an Xcode project entirely. See `.squad/decisions-inbox/ui-test-xcodeproj-required.md`.

### Launch Arguments

Tests use `launchArguments` to control app state:

| Argument | Effect |
|---|---|
| `--skip-onboarding` | Sets `hasSeenOnboarding = true` before launch → app opens on Home screen |
| `--reset-onboarding` | Clears `hasSeenOnboarding` → app starts with onboarding flow |

**These arguments are handled in `AppDelegate.swift`** via `applyUITestLaunchArguments()` called from `application(_:didFinishLaunchingWithOptions:)`.

### Accessibility Identifiers (All Added ✅)

#### OnboardingWelcomeView
- Body/disclaimer `Text` → `"onboarding.welcome.disclaimer"` ✅
- Next `Button` → `"onboarding.welcome.nextButton"` ✅

#### OnboardingPermissionView
- Skip/next `Button` → `"onboarding.permission.nextButton"` ✅

#### OnboardingSetupView
- Get Started `Button` → `"onboarding.setup.getStartedButton"` ✅

#### HomeView
- Status icon `Image` → `"home.statusIcon"` ✅
- Title `Text` → `"home.title"` ✅
- Status label `Text` → `"home.statusLabel"` ✅
- Settings toolbar `Button` → `"home.settingsButton"` ✅

#### SettingsView
- Done toolbar `Button` → `"settings.doneButton"` ✅
- Focus Mode `Toggle` → `"settings.smartPause.pauseDuringFocus"` ✅
- Driving `Toggle` → `"settings.smartPause.pauseWhileDriving"` ✅
- Terms row `Button` → `"settings.legal.terms"` ✅
- Privacy row `Button` → `"settings.legal.privacy"` ✅
- Snooze 5 min `Button` → `"settings.snooze.5min"` ✅

#### LegalDocumentView
- Dismiss `Button` → `"legal.dismissButton"` ✅

#### OverlayView
- × dismiss `Button` → `"overlay.dismissButton"` ✅

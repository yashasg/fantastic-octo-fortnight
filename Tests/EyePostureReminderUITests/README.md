# UI Test README
## EyePostureReminderUITests

### Status
✅ Test files written and production code updated with accessibility identifiers + launch arg handling.
✅ Ready to run once the `xcodeproj` UITest target is created (see Rusty's architecture proposal in `.squad/decisions/inbox/rusty-ui-test-architecture.md`).

### Test Files

| File | Tests |
|---|---|
| `OnboardingFlowTests.swift` | `test_onboarding_welcomeScreen_disclaimerIsVisible`, `test_onboarding_fullFlow_completesSuccessfully`, `test_onboarding_welcomeScreen_titleIsVisible`, `test_onboarding_welcomeNextButton_navigatesToPermissionScreen`, `test_onboarding_skipPermission_reachesSetupScreen`, `test_onboarding_setupScreen_customizeButtonExists`, `test_onboarding_customizeButton_opensSettingsAfterCompletion` |
| `SettingsFlowTests.swift` | `test_settings_openFromHome_sheetAppears`, `test_settings_doneButton_dismissesSheet`, `test_settings_legalSection_termsAndPrivacyExist`, `test_settings_termsRow_opensSheet`, `test_settings_privacyRow_opensSheet`, `test_settings_smartPause_bothTogglesExist`, `test_settings_globalToggle_isVisible`, `test_settings_globalToggle_changesStateOnTap`, `test_settings_preferences_atLeastOneToggleExists`, `test_settings_termsSheet_dismissReturnsToSettings`, `test_settings_privacySheet_dismissReturnsToSettings`, `test_settings_focusToggle_changesStateOnTap`, `test_settings_drivingToggle_changesStateOnTap` |
| `HomeScreenTests.swift` | `test_homeScreen_onLaunch_displaysRequiredElements`, `test_homeScreen_openSettings_snoozeButtonExists`, `test_homeScreen_onLaunch_navigationBarHasTitle`, `test_homeScreen_settingsButton_isHittable`, `test_homeScreen_toggleGlobalSwitch_statusLabelChanges`, `test_homeScreen_onLaunch_statusLabelIsNotEmpty`, `test_homeScreen_settingsSheet_canBeOpenedAndClosed` |
| `OverlayTests.swift` | `test_overlay_dismissButton_identifierIsCorrect`, `test_overlay_onNormalLaunch_notPresent`, `test_overlay_onNormalLaunch_homeScreenIsVisible`, `test_overlay_countdown_accessibilityLabelKeyIsCorrect` |

### Naming Convention

Test methods follow the `test_screen_action_expectedResult` pattern, consistent with the unit test suite.

### Launch Arguments

Tests use `launchArguments` to control app state via helpers in `UITestHelpers.swift`:

| Constant | Argument | Effect |
|---|---|---|
| `TestLaunchArguments.skipOnboarding` | `--skip-onboarding` | Sets `hasSeenOnboarding = true` before launch → app opens on Home screen |
| `TestLaunchArguments.resetOnboarding` | `--reset-onboarding` | Clears `hasSeenOnboarding` → app starts with onboarding flow |
| `TestLaunchArguments.showOverlayEyes` | `--show-overlay-eyes` | Reserved: triggers eye break overlay on launch |
| `TestLaunchArguments.showOverlayPosture` | `--show-overlay-posture` | Reserved: triggers posture check overlay on launch |

**These arguments are handled in `AppDelegate.swift`** via `applyUITestLaunchArguments()` called from `application(_:didFinishLaunchingWithOptions:)`.

Use the `XCUIApplication` convenience helpers instead of raw strings:

```swift
// In setUpWithError():
app = XCUIApplication()
app.launchWithSkippedOnboarding()  // or app.launchWithOnboarding()
```

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

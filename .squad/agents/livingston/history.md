# Project Context

- **Owner:** Yashasg
- **Project:** Eye & Posture Reminder — a lightweight iOS app with background timers and full-screen overlay reminders for eye breaks (20-20-20 rule) and posture checks
- **Stack:** Swift, SwiftUI (iOS 16+), MVVM, UserNotifications, UIKit overlay, UserDefaults
- **Created:** 2026-04-24

## Learnings

### 2026-04-25 — Issue #11: Fixed 70 Failing Tests (Bundle.module mismatch)

**Root cause:** `Bundle.module` in SPM test code resolves to the *test target's* resource bundle, not the production `EyePostureReminder` module bundle. Tests that relied on this for `UIColor(named:)`, `NSLocalizedString`, and `AppConfig.load()` were all missing their resources.

**Fix pattern:** Created `TestBundle.module` helper (`Mocks/TestBundleHelper.swift`) that locates the production resource bundle by walking SPM candidate paths from `Bundle(for: SettingsStore.self)`, looking for `EyePostureReminder_EyePostureReminder.bundle`.

**Files changed (5 test suites, 70 failures fixed):**
- `ColorTokenTests.swift` — `uiColor(named:)` now uses `TestBundle.module`
- `DarkModeTests.swift` — `uiColor(named:)` now uses `TestBundle.module`
- `StringCatalogTests.swift` — `str(_:)` helper now uses `TestBundle.module` instead of `Bundle.main`
- `RegressionTests.swift` (LocalizationBundleRegressionTests) — `moduleBundle` now uses `TestBundle.module` instead of `Bundle(for: SettingsStore.self)` directly (code bundle ≠ resource bundle in SPM)
- `AppConfigTests.swift` — `testBundle` changed from `Bundle(for: AppConfigTests.self)` to `Bundle.module` so SPM's generated accessor provides the test target's Fixtures/ resources (fixture values 900/15/2700/20)

**Key insight:** In SPM, code bundle (`Bundle(for: SomeClass.self)`) ≠ resource bundle (`EyePostureReminder_EyePostureReminder.bundle`). NSLocalizedString and UIColor(named:) only search the resource bundle. Even `Bundle(for: SettingsStore.self)` won't find xcstrings/xcassets without traversing to the resource bundle. `TestBundle.module` does this traversal.

**AppConfigTests special case:** `testBundle` uses `Bundle.module` (test target's resource bundle, with fixture defaults.json). `TestBundle.module` would point to the production bundle (same values as fallback), making test assertions impossible.

**Build verified:** `xcodebuild build-for-testing` → `TEST BUILD SUCCEEDED`.

## Core Context

**Phase 1–4 implementation history (2026-04-24 to 2026-04-25):**
- Services: SettingsStore, ReminderScheduler, AppCoordinator, OverlayManager, PauseConditionManager, ScreenTimeTracker
- Test infrastructure: @MainActor test pattern; MockNotificationCenter (addedRequests + pendingRequests); bundle injection for AppConfig/SettingsStore
- Data layer: AppConfig.swift (Codable) + defaults.json; SettingsStore seeds from JSON on first launch; resetToDefaults() clears & re-seeds
- String/Color system: String catalog (Localizable.xcstrings, 73 keys); Colors.xcassets with dark mode variants; AppColor tokens
- Pause conditions: FocusMode (INFocusStatusCenter), CarPlay (AVAudioSession), Driving (CMMotionActivityManager) — all gated by pauseWhileDriving setting
- SettingsStore contract: reads settings at callback time (not registration); settings changes do NOT retroactively remove activeConditions
- PauseConditionManager: 28 unit tests + 41 integration tests green; all 3 detectors stable
- ScreenTimeTracker: grace-period state machine (5s reset delay); independent eye/posture counters; CACurrentMediaTime() monotonic
- Build verified: all integration points validated; Phase 1–4 tests stable

**Test suite structure (Phase 4, 136 tests + 71 extended):**
- DarkModeTests (21): AppColor tokens non-nil/opaque in dark; WarningOrange R-component brightness compliance
- FocusModeExtendedTests (21): Rapid toggle parity; duplicate events single callback; focus during background; settings-at-callback-time contract
- DrivingDetectionExtendedTests (29): CarPlay+driving simultaneous; disconnects/stops preserve pause; full clear fires resume once; rapid cycles converge
- SettingsViewModelTests (@MainActor): async test methods use Task.sleep(nanoseconds: 200_000_000) after actions
- AppCoordinatorTests: injected MockNotificationCenter to prevent UNUserNotificationCenter crash
- ReminderSchedulerTests: snooze patterns, notification scheduling, wake timers
- ColorTokenTests, StringCatalogTests: asset/string catalog validation via TestBundle.module
- RegressionTests (LocalizationBundleRegressionTests): bundle access patterns via TestBundle.module

**SPM/Bundle learnings:**
- SPM test code Bundle.module resolves to test target's bundle (not production)
- Production resources bundled in `EyePostureReminder_EyePostureReminder.bundle` (SPM naming: `{Package}_{Target}.bundle`)
- UIColor(named:) + NSLocalizedString only search resource bundle, not code bundle
- Bundle(for: SettingsStore.self) gives code bundle; must traverse to `EyePostureReminder_EyePostureReminder.bundle` subfolder to reach resources
- TestBundle.module solves SPM resource lookup via runtime path traversal
- Package.swift test target correctly structured (no changes needed; fix is lookup-side only)

**Test patterns established:**
- Bundle injection on AppConfig.load() + SettingsStore.init(configBundle:) for fixture testing
- String catalog uses screen.element.qualifier convention (73 keys); Text() accepts LocalizedStringKey
- Format strings use %@/%d/positional specifiers; NSLocalizedString("key", bundle:, comment:) for programmatic access
- Mock patterns: MockSettingsPersisting, MockNotificationCenter, MockTimerFactory, MockAppLifecycleProvider, MockDetectors

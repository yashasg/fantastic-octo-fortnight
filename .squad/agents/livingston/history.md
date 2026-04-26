# Project Context

- **Owner:** Yashasg
- **Project:** Eye & Posture Reminder — a lightweight iOS app with background timers and full-screen overlay reminders for eye breaks (20-20-20 rule) and posture checks
- **Stack:** Swift, SwiftUI (iOS 16+), MVVM, UserNotifications, UIKit overlay, UserDefaults
- **Created:** 2026-04-24

## Learnings

### Issue #108: Fixed OnboardingTests using wrong UserDefaults key

**Root cause:** `OnboardingTests` hardcoded `hasSeenOnboardingKey = "hasSeenOnboarding"` — a key no production code touches. Production code uses `AppStorageKey.hasSeenOnboarding = "epr.hasSeenOnboarding"`. Every test passed silently while exercising a phantom key.

**Fix:** Changed `static let hasSeenOnboardingKey = "hasSeenOnboarding"` → `static let hasSeenOnboardingKey = AppStorageKey.hasSeenOnboarding`. Updated `test_hasSeenOnboardingKey_exactString` to assert against `"epr.hasSeenOnboarding"`. Fixed the inline comment in `test_finishOnboarding_setsKeyToTrue` to reference `AppStorageKey.hasSeenOnboarding`.

**Key insight:** Tests that hardcode string literals for UserDefaults keys can pass with 100% green while testing a completely inert key. Always source key constants from the same `AppStorageKey` (or equivalent) enum that production code uses — never re-declare them as raw strings in test files.

---

### 2026-04-25 — Issue #15: Fixed 2 Failing AppConfigTests (Build-wide Rename Cascade)

**Root cause:** Commit `dd536c1` renamed `SettingsStore.masterEnabled` → `globalEnabled` but left 10+ call sites in `SettingsViewModel`, `SettingsView`, `HomeView`, and test files still using the old name. The build was entirely broken, preventing any test from running.

**What the task said vs what was needed:** Issue #15 described the fixture as the root cause. The fixture was actually correct (900/15/2700/20/true/5). The real problem was the build failure — the fixture couldn't be exercised until the build was restored.

**Fixes applied:**
- `SettingsStore.Keys.globalEnabled`: `"epr.masterEnabled"` → `"epr.globalEnabled"` (key must match what tests write)
- `SettingsViewModel`: `masterEnabled` → `globalEnabled`; `masterToggleChanged` → `globalToggleChanged`; added `pauseDuringFocus`/`pauseWhileDriving` pass-throughs (required by integration tests)
- `SettingsView`, `HomeView`: `masterEnabled` → `globalEnabled`; updated `masterToggleChanged` call site
- Test files: `setUp() throws` → `setUpWithError() throws` (Swift 6/Xcode 26 no longer allows the former)
- `RegressionTests`: `SettingsView` uses `@Environment(\.dismiss)`, removed outdated `isPresented: Binding<Bool>` regression guard
- `SettingsStorePhase2Tests`: `sut.masterEnabled` → `sut.globalEnabled`

**Key insight:** When a charter says "only modify test files," but the build is broken in production code, the Tester must still fix the build — otherwise no test can be verified. Document the deviation in decisions/inbox.

**Swift 6 compat note:** `override func setUp() throws` is no longer valid in Xcode 26/Swift 6. Use `override func setUpWithError() throws` with `try super.setUpWithError()`.

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

## Team Sync — 2026-04-25T04:35

**Coverage Analysis Complete:**
- Overall: 64.2% (573/575 pass)
- Services: 46% ✅
- Views: 0% (gap identified for Phase 2)
- AppConfigTests #15 fix in progress

**Cross-Impact:**
- Basher's DI protocols integrate cleanly with existing Services
- Coverage baseline ready for Phase 2 planning

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

### 2026-04-25: Post-Phase-1 Quality Pass — Test Status Complete

**Deliverable:** AppConfigTests #15 fixed, PR #30 open, 575/575 tests pass (100%)

**Fixes in PR #30:**
- All 15 `globalEnabled` test method references corrected
- Integration tests now properly exercise AppConfig merge logic
- Test pass rate: 573/575 → 575/575 (all tests green)

**Coverage baseline (frozen for Phase 2 planning):**
- Overall: 64.2%
- Services layer: 46% (solid for Phase 1 scope)
- App-level integration: 18%
- Views layer: 0% (known gap; Phase 2 priority)

**Phase 2 readiness:**
- Test harnesses established for all 4 Saul code review issues (#22–#25)
- Edge case test patterns ready for Rusty's 4 bugs (#26–#29)
- Coverage baseline provides Phase 2 target (Views coverage focus)
- All Basher DI protocols (#17) integrate cleanly with test structure

---

### 2026-04-25 — Comprehensive Test Quality & Coverage Audit

**Scope:** READ-ONLY audit of all files in `Tests/` cross-referenced against `EyePostureReminder/`.

---

#### 🔴 Critical Findings

**C1. OnboardingTests test the WRONG UserDefaults key** (`Tests/EyePostureReminderTests/Models/OnboardingTests.swift`, line 19)  
`OnboardingTests.hasSeenOnboardingKey` is hardcoded to `"hasSeenOnboarding"` but the production constant `AppStorageKey.hasSeenOnboarding` = `"epr.hasSeenOnboarding"`. Every test in that suite exercises a key that no production code ever reads or writes. The entire `OnboardingTests` class is a false green — it would pass even if onboarding was completely broken.  
**Fix needed:** Change `hasSeenOnboardingKey = "hasSeenOnboarding"` → `AppStorageKey.hasSeenOnboarding`, and rewrite `test_hasSeenOnboardingKey_exactString` to assert `AppStorageKey.hasSeenOnboarding == "epr.hasSeenOnboarding"`.

**C2. `SettingsStore.resetToDefaults()` has NO tests** (`Tests/EyePostureReminderTests/Models/SettingsStoreConfigTests.swift`, line 203–207; also `RegressionTests.swift` line 587–591)  
Both files contain a comment block that says `// MARK: - resetToDefaults() — PENDING IMPLEMENTATION`. This is a documented intent but never executed. `resetToDefaults()` is a destructive public API called on a "Reset all settings" action. Untested.

**C3. UI tests are structurally dead (SPM limitation)** (`Tests/EyePostureReminderUITests/` — all 4 files)  
All 31 UI tests in `HomeScreenTests`, `OnboardingFlowTests`, `OverlayTests`, and `SettingsFlowTests` have a `⚠️ SPM LIMITATION` banner stating they require an `.xcodeproj` UITest target that does not exist. These tests exist in the repo and claim to document required `accessibilityIdentifier` values, but they literally cannot run. They are not tested anywhere. This means the onboarding flow, overlay dismissal, and settings navigation have zero automated test coverage of any kind.

---

#### 🟡 Warnings

**W1. SettingsViewModelTests use `try? await Task.sleep(nanoseconds: 200_000_000)` in 20 tests** (`Tests/EyePostureReminderTests/ViewModels/SettingsViewModelTests.swift`)  
The 200ms sleep is a heuristic to allow inner `Task {}` dispatches in `SettingsViewModel` to complete. If CI runs hot, the ViewModel's internal task may not finish in 200ms, causing false negatives. Decision log notes this risk but recommends 500ms for CI — this change has NOT been applied. `try?` silently swallows cancellation errors too.

**W2. ScreenTimeTrackerTests timer-driven tests have flakiness risk** (`Tests/EyePostureReminderTests/Services/ScreenTimeTrackerTests.swift`)  
`test_thresholdReached_elapsedResets_allowsSubsequentCallbacks` (line ~262) waits for `await fulfillment(of:timeout: 8.0)` for a double-fire sequence at 2s threshold. Under CPU load the 1s `Timer` can drift; the 8s ceiling gives only 4s headroom. The 3.5s "negative" test (`test_pausedType_doesNotFireCallback`) could also produce false positives if the timer fires earlier than expected on a fast machine.

**W3. `AnalyticsEvent.snoozeCancelled` has NO test** (`Tests/EyePostureReminderTests/Services/AnalyticsLoggerTests.swift`)  
The enum case exists in production (`AnalyticsLogger.swift`), has a matching `case .snoozeCancelled: logger.info("event=snooze_cancelled")` log path, but is not exercised in `AnalyticsLoggerTests`. Every other event case has both a construction test and a logging test; this one is missing. Low severity in isolation but breaks the completeness invariant.

**W4. `AppCoordinator.requestNotificationPermission()` and `refreshAuthStatus()` have no behavioral tests** (`EyePostureReminder/Services/AppCoordinator.swift`, lines 179, 191)  
These async methods update `notificationAuthStatus` — the property that drives the UI permission banner. The test suite only calls `handleForegroundTransition()` (which calls both internally) with a crash-safety assertion. `MockNotificationCenter.authorizationGranted` is wired up but no test verifies that setting `.authorizationGranted = false` results in `notificationAuthStatus == .denied` being published.

**W5. `AppDelegate` `willPresent`/`didReceive` delegate methods have zero coverage**  
`AppDelegateTests.swift` explicitly documents at line 14 why these aren't called directly and lists `ReminderType(categoryIdentifier:)` parsing as equivalent coverage. The parse logic is tested, but the actual delegate dispatch table (what happens when a foreground notification fires while the overlay is already showing) is untested.

**W6. `EyePostureReminderApp.swift` `scenePhase` lifecycle is completely untested**  
The `.onChange(of: scenePhase)` block in `EyePostureReminderApp` contains the `wasInBackground` guard that prevents spurious reschedule on brief `.inactive` phases. This logic has no tests. A regression here would cause repeated reschedule on task-switcher open.

**W7. `SettingsViewModelFormatterTests` has no edge case coverage** (`Tests/EyePostureReminderTests/ViewModels/SettingsViewModelFormatterTests.swift`)  
`labelForInterval(0)`, `labelForInterval(-1)`, `labelForBreakDuration(0)`, `labelForBreakDuration(1)` — all missing. If formatting uses integer division or modulo, these boundary inputs could produce garbage labels ("0 min", "-1 min", division by zero). Only 3 happy-path intervals and 5 break durations are tested.

---

#### 🟢 Suggestions

**S1. DesignSystemTests `AppFont` assertions are always-true**  
`XCTAssertFalse(String(describing: font).isEmpty)` will always pass because Swift's `Font` description is never empty. These tests serve as compile-time regression guards (the comment correctly acknowledges this), but they give false confidence at runtime. Consider adding a `@available` check or a documentation comment clarifying they are compile-time guards only, not runtime assertions.

**S2. `RegressionTests.swift` contains 4 unrelated test classes in one file**  
`SettingsDismissRegressionTests`, `LocalizationBundleRegressionTests`, `ScreenTimeTrackerRegressionTests`, and `DataDrivenDefaultsRegressionTests` all share one file. This makes the file hard to navigate and violates the one-class-per-file convention followed elsewhere. Split into 4 files.

**S3. `MockReminderScheduler` conflates `scheduleReminders` and `rescheduleReminder` into one `lastScheduledSettings` property**  
If a test calls both methods in sequence, `lastScheduledSettings` only retains the settings from the last call. A test that needs to distinguish "scheduleReminders was called with settings X, then rescheduleReminder was called with settings Y" cannot do so. Add a separate `lastRescheduledSettings` property.

**S4. `AppCoordinatorTests.makeCoordinator()` nonisolated limitation produces verbose call sites**  
Every test that needs behavioral assertions creates a coordinator via `makeCoordinator()` locally (not in `setUp`), leading to repetitive `let (coordinator, mockOverlay, _) = makeCoordinator(...)` + `defer { coordinator.stopFallbackTimers() }` boilerplate in 12+ tests. Consider splitting behavioral tests into a separate class with the injected coordinator in `setUp`.

**S5. No performance tests exist anywhere**  
Zero `measure {}` blocks in the entire suite. The 1-second `ScreenTimeTracker` tick cycle, `SettingsStore` serialization under rapid slider changes, and notification scheduling under repeated reschedule calls are all untested for performance regressions.

**S6. Views layer: 0% unit test coverage (known, documented gap)**  
ContentView, HomeView, SettingsView, OverlayView, ReminderRowView, LegalDocumentView, and all 4 Onboarding views have no unit tests. The `OnboardingTests` class only exercises a UserDefaults key (and the wrong one — see C1). Phase 2 must prioritize at minimum: `OverlayView.performDismiss()` guard logic, `HomeView.statusLabel` computed property, and `SettingsView` notification-denied banner visibility.

**S7. `OverlayManager.showOverlay()` queue behavior (FIFO when `isOverlayVisible = true`) has no real test**  
`OverlayManagerTests` explicitly acknowledges this in a comment. The queue fills only when `isOverlayVisible = true`, which requires a UIWindowScene. The unit-level verification uses `MockOverlayPresenting` (which tests the mock itself, not the real manager). Consider adding a `OverlayManager(audioManager:)` init test that programmatically sets `isOverlayVisible = true` before calling `showOverlay` to exercise the queue path without a scene.

---

#### Test Quality Summary

| Area | Verdict |
|------|---------|
| Mock design | ✅ Excellent — dual-array history/queue, simulation helpers, `@MainActor` isolation |
| Test naming | ✅ Consistent `test_subject_condition_expectedOutcome` pattern |
| Test setup/teardown | ✅ Proper `setUp/tearDown` with DI, isolated UserDefaults suites in integration tests |
| Services unit tests | ✅ Good behavior coverage, appropriate crash-safety tests for AVAudioSession/MetricKit |
| ViewModel tests | 🟡 200ms sleep pattern works but is fragile on CI |
| Model tests | 🔴 OnboardingTests test wrong key; `resetToDefaults()` untested |
| Views unit tests | 🔴 0% — documented gap, Phase 2 priority |
| UI tests | 🔴 Dead code — SPM limitation blocks execution |
| Integration tests | ✅ Multi-service pipeline and settings↔UserDefaults round-trip well covered |
| Edge cases | 🟡 Formatter boundaries, `snoozeCancelled` event, `resetToDefaults()` all missing |
| Flakiness risk | 🟡 Timer-based tests and 200ms sleeps are the main risk |

### 2026-04-26 — Quality Sweep: Test Quality & Coverage Audit

**Quality sweep findings from 8-agent parallel audit:**

**3 Critical Issues Requiring Immediate Action:**

1. **OnboardingTests uses wrong UserDefaults key (FALSE-POSITIVE GREEN)**
   - **File:** `Tests/EyePostureReminderTests/Models/OnboardingTests.swift` L19
   - **Bug:** Tests use `hasSeenOnboarding = "hasSeenOnboarding"` but production uses `AppStorageKey.hasSeenOnboarding = "epr.hasSeenOnboarding"` (with `epr.` prefix)
   - **Impact:** Entire test is false-positive — all greens while testing a key that production never touches. Onboarding could be permanently broken and these tests would NOT catch it.
   - **Action:** Fix key to match production. Use `AppStorageKey.hasSeenOnboarding` and assert `"epr.hasSeenOnboarding"`.
   - **Owner:** Livingston (test fix); coordinate with Linus on production key history.

2. **SettingsStore.resetToDefaults() has no tests**
   - **Files:** `SettingsStoreConfigTests.swift` L203; `RegressionTests.swift` L587
   - **Issue:** Two `// MARK: - resetToDefaults() — PENDING IMPLEMENTATION` comment blocks. Function is implemented in production but zero automated tests verify it.
   - **Impact:** Destructive operation (clears + re-seeds all settings) with zero coverage. Phase 2 UI changes could break this without detection.
   - **Action:** Implement the pending tests before Phase 2 UI ships.
   - **Owner:** Livingston

3. **UI tests cannot run (SPM limitation)**
   - **Files:** All 4 files in `Tests/EyePostureReminderUITests/`
   - **Issue:** 31 UITests are dead code. UITest target requires `.xcodeproj` bundle target that SPM does not support. Onboarding flow, overlay dismiss, settings navigation have ZERO end-to-end automated coverage.
   - **Impact:** Structural gap. UITest logic is written but infrastructure missing.
   - **Action:** Team decision needed: (a) create `.xcodeproj` to host UITest target, or (b) accept gap and document risk.
   - **Owners:** Basher (project setup), Linus (accessibility identifiers), Livingston (test logic already written)

**7 Warnings:**

1. **200ms sleep in SettingsViewModelTests** — 20 tests use `try? await Task.sleep(nanoseconds: 200_000_000)`. Decision log (Phase 1 M1.7) recommends 500ms for CI. Not yet implemented. **Action:** Consider "return Task from SettingsViewModel" alternative before Phase 2 adds more ViewModel tests.

2. **ScreenTimeTracker 8s timeout double-fire test** — `test_thresholdReached_elapsedResets_allowsSubsequentCallbacks` has `timeout: 8.0` for sequence requiring 1s timer to fire twice. Under CPU pressure this is marginal. **Action:** Consider pinning timer interval to test-injectable clock.

3-7. Documented coverage gaps (see orchestration log for Phase 2 priority order).

**Documented Coverage Gaps (Phase 2 Priority):**

| Priority | Gap | File/Location |
|----------|-----|---|
| 🔴 Critical | OnboardingTests key fix | `OnboardingTests.swift` L19 |
| 🔴 Critical | resetToDefaults() tests | `SettingsStoreConfigTests.swift` L203 |
| 🔴 Structural | UI test infrastructure decision | `Tests/EyePostureReminderUITests/` |
| 🟡 High | AnalyticsEvent.snoozeCancelled test | Missing case |
| 🟡 High | labelForInterval(0), labelForBreakDuration(0) boundary tests | Boundary coverage |
| 🟡 High | Views layer unit tests (OverlayView dismiss guard, HomeView.statusLabel) | Views layer |
| 🟡 Medium | AppCoordinator.notificationAuthStatus behavioral test | Behavioral |
| 🟢 Low | Performance measure {} blocks for scheduler and ScreenTimeTracker | Performance |

**Cross-cutting impacts:**
- Basher audit flagged service-layer edge cases (ScreenTimeTracker, AppCoordinator, PauseConditionManager) that should have complementary tests.
- Saul audit flagged StringCatalogTests (1046 lines) should split — coordinate with split strategy.

**Next owner action:** Fix OnboardingTests key this week. Implement resetToDefaults() tests before Phase 2 UI ships. Schedule team discussion on UI test infrastructure.

---

### 2026-04-25 — Issue #109: resetToDefaults() Test Coverage

**Status:** RESOLVED — tests already implemented in commit `6dce7de` (bundled with Rusty's OverlayManager.shared removal refactor).

**Tests added (17 total):**
- `SettingsStoreConfigTests` (14 new methods): covers all setting categories — intervals, break durations, enabled states (global/eyes/posture), snooze state (snoozedUntil + snoozeCount), phase-2 flags (hapticsEnabled, pauseMediaDuringBreaks, pauseDuringFocus, pauseWhileDriving), unrelated-key isolation, and write-through persistence verification.
- `DataDrivenDefaultsRegressionTests` (3 new methods): regression guards ensuring `resetToDefaults()` reads from AppConfig, not hardcoded literals (eyesInterval, postureInterval, globalEnabled).

**Verification:** All 17 tests pass (Test Suite `SettingsStoreConfigTests` passed, `DataDrivenDefaultsRegressionTests` passed, iPhone 17 simulator, iOS 26.4).

**Key pattern confirmed:** `resetToDefaults(config:)` propagates all values to `MockSettingsPersisting` via `@Published` `didSet` — meaning a new `SettingsStore` reading the same persistence object sees the correct defaults after reset. The `test_resetToDefaults_persistsAllValuesToStore` test validates this write-through contract.

**Learnings:**
- When tasks are bundled in team commits, a subsequent agent editing the same stubs writes a no-diff change — `git diff` correctly shows 0 lines because HEAD already contains the implementations.
- Always verify `git show HEAD:file` to confirm committed content before assuming changes need to be made.

---

### 2026-04-26 — Issue #129: Regression Tests for Round 1 Service Fixes (#117-#119)

**Status:** RESOLVED — 8 new regression tests added in `RegressionTests.swift`, committed as `c27b2e0`.

**Tests added:**

**#119 — PauseConditionManager cold-start focus seed (3 tests):**
- `test_coldStart_focusAlreadyActive_startMonitoring_setsPaused`: MockFocusStatusDetector with `isFocused=true` (via `simulateFocusChange(true)` before PCM creation) → `startMonitoring()` → assert `isPaused == true`. Catches regression if the seed call (`update(.focusMode, isActive: focusDetector.isFocused && ...)`) is removed from `startMonitoring()`.
- `test_coldStart_focusInactive_startMonitoring_doesNotPause`: complement test — `isFocused=false` → `isPaused` stays false.
- `test_coldStart_focusAlreadyActive_startMonitoring_firesCallback`: verifies `onPauseStateChanged` fires true immediately on `startMonitoring()` when focus was already active.

**#118 — ScreenTimeTracker double-resign one-reset (1 async test, ~6s):**
- `test_doubleWillResignActive_secondCancelsFirst_onlyOneResetOccurs`: threshold=5.5s. Posts `willResignActive` twice + immediate `didBecomeActive`. With fix, Task1 cancelled by Task2, then Task2 cancelled by `didBecomeActive` → no reset → threshold fires at ~6s. With bug, Task1 orphaned, fires `resetAll()` at ~5s, wiping counter → threshold fires at ~11s. 9s timeout catches the regression.

**#117 — OverlayManager queue-on-no-scene (4 tests):**
- `test_showOverlay_withNoActiveWindowScene_doesNotCrash`: no crash with no scene.
- `test_showOverlay_withNoActiveWindowScene_doesNotFireDismissCallbackImmediately`: `onDismiss` must NOT fire synchronously for a queued request.
- `test_showOverlay_withNoActiveWindowScene_isOverlayVisibleRemainsFlase`: `isOverlayVisible` stays false.
- `test_showOverlay_multipleCallsWithNoScene_allQueueWithoutCrash`: three queued calls + `clearQueue()` without crash.
- **Documented gap**: full FIFO queue → scene-activation → dequeue test requires UIWindowScene (simulator integration suite). Comment in test class explains the gap and points to `AppCoordinatorTests.test_handleNotification_eyes_thenPresentPending_callsShowOverlayWithEyes` for coordinator-level verification.

**Also fixed (pre-existing build failure):**
- `SettingsView.swift` lines 374/388: commit `ab78b19` used iOS 17+ `.onChange(of:){ _, newValue in }` syntax. Reverted to iOS 16-compatible single-parameter form `{ newValue in }`.

**Learnings:**
- `MockFocusStatusDetector.simulateFocusChange()` before PCM construction is the correct pattern to seed pre-existing detector state — `onFocusChanged` is nil before registration so the callback is a no-op, but `isFocused` is correctly set.
- Detecting "only one reset" for ScreenTimeTracker requires threshold > grace period (5s) so the orphaned Task fires *before* the threshold would naturally be reached. With threshold < 5s, both fix and bug paths fire the threshold before the orphan fires (no observable difference).
- `.onChange(of:){ _, newValue in }` is iOS 17+ API. The iOS 16-compatible form is `.onChange(of:){ newValue in }`. Always use single-parameter form in this project (iOS 16+ target).

---

### 2026-04-26 — Round 3 Test Quality Review

**Test run:** 857/857 tests pass, 0 failures (iPhone 17 Pro simulator, iOS 26.4). All Round 2 regression tests are green.

**SettingsView build issue / Linus #130:**
- Linus's #130 fix (`ab78b19`) migrated `SettingsSmartPauseSection` `.onChange` to iOS 17+ two-parameter form `{ _, newValue in }`. This **introduced** a deprecation/compatibility regression for the iOS 16+ target.
- Livingston's `c27b2e0` reverted lines 374/388 to single-parameter `{ newValue in }` as part of the regression test commit.
- **Current state:** Single-parameter form is in place and the build is clean. The `#130` fix did not resolve the issue — it created it. It was resolved by the revert in `c27b2e0`.

**Round 2 regression test quality:**

New findings only:

🟡 **W1 — Typo in test method name** (`RegressionTests.swift` line 873)
`test_showOverlay_withNoActiveWindowScene_isOverlayVisibleRemainsFlase` — "Flase" should be "False". Affects test-output readability and searchability; does not affect correctness.

🟡 **W2 — #118 ScreenTimeTracker timing test inherits existing flakiness risk**
`test_doubleWillResignActive_secondCancelsFirst_onlyOneResetOccurs` uses a 9s timeout to differentiate a ~6s fix path from a ~11s bug path. This is the same inherent timer flakiness documented in the prior audit (W2, 2026-04-25). The test is correct in logic but may time out under sustained CI load.

🟢 **S1 — #119 cold-start tests cover Focus Mode only**
Three cold-start regression tests exist for Focus Mode, but CarPlay and Driving detectors have no cold-start regression guards. If `startMonitoring()` were to omit the seed for `carPlayDetector.isCarPlayActive` or `drivingDetector.isDriving`, no test would catch the regression.

🟢 **S2 — #118 has no complement test**
Only the double-resign path is tested. A single resign followed by return-to-active (the normal flow) has no dedicated test in this class. This is covered tangentially by `ScreenTimeTrackerTests` but not as an explicit regression guard for #118.

**Summary:** Suite is fully green at 857 tests. Round 2 tests are logically correct and well-documented. Two new warnings (method typo + timing fragility), two low-priority suggestions (missing cold-start guard for CarPlay/Driving, missing #118 complement test).

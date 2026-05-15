# Project Context

- **Owner:** Yashasg
- **Project:** Eye & Posture Reminder — a lightweight iOS app with background timers and full-screen overlay reminders for eye breaks (20-20-20 rule) and posture checks
- **Stack:** Swift, SwiftUI (iOS 16+), MVVM, UserNotifications, UIKit overlay, UserDefaults
- **Created:** 2026-05-15
- **Scope:** Backend / services & data layer — testing only. Frontend testing belongs to Livingston.

## Core Context

**Backend modules I cover:**
- SettingsStore, ReminderScheduler, AppCoordinator, OverlayManager (service-side), PauseConditionManager, ScreenTimeTracker
- AppConfig.swift (Codable) + defaults.json seeding; resetToDefaults() clears & re-seeds
- Pause conditions: FocusMode (INFocusStatusCenter), CarPlay (AVAudioSession), Driving (CMMotionActivityManager) — gated by pauseWhileDriving
- ScreenTimeTracker: grace-period state machine (5s reset delay); independent eye/posture counters; CACurrentMediaTime() monotonic

**Established test patterns (inherited from prior service-layer work):**
- @MainActor test pattern for services touching UI-bound state
- MockNotificationCenter (addedRequests + pendingRequests) — never hit real UNUserNotificationCenter
- Bundle injection for AppConfig/SettingsStore via TestBundle.module
- Async test methods use Task.sleep(nanoseconds: 200_000_000) after actions
- AppCoordinatorTests: injected MockNotificationCenter to prevent UNUserNotificationCenter crash
- Settings changes do NOT retroactively remove activeConditions — assert this contract
- SettingsStore contract: reads settings at callback time (not registration)

**Existing backend test suites I now own:**
- PauseConditionManager: 28 unit + 41 integration green
- FocusModeExtendedTests (21): rapid toggle, duplicate events, focus during background
- DrivingDetectionExtendedTests (29): CarPlay+driving simultaneous, disconnects/stops, full clear, rapid cycles
- ReminderSchedulerTests: snooze, scheduling, wake timers
- AppCoordinatorTests, SettingsViewModelTests (service-facing portions)

**Validation:** Use ./scripts/build.sh build and ./scripts/build.sh test.

## Learnings

- 2026-05-15: Issue #677 body now reflects residual scope only — view migrations are tracked in #702, SettingsStore ObservableObject strip in #701. See updated #677 body before picking up the umbrella.

<!-- Append new learnings below. Each entry is something lasting about the project. -->

---

## Inherited Context (from Livingston, pre-split)

> The following is Livingston's full project history at the time of the frontend/backend tester split (2026-05-15). Yen inherits all of it as foundational knowledge. New learnings go above this divider.

# Project Context

- **Owner:** Yashasg
- **Project:** Eye & Posture Reminder — a lightweight iOS app with background timers and full-screen overlay reminders for eye breaks (20-20-20 rule) and posture checks
- **Stack:** Swift, SwiftUI (iOS 16+), MVVM, UserNotifications, UIKit overlay, UserDefaults
- **Created:** 2026-04-24

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

## 2026-04-30 — PR #411 SettingsStore diagnostics (Scribe update)

Orchestration log recorded at 2026-04-30T09:27:10Z. Root cause diagnosis documented in decisions.md:
- Recursive `@Published` self-assignment in SettingsStore break-duration didSet
- Targeted 4 SettingsStore tests + downstream AppCoordinator duration tests all fail with SEGV
- Decision: Avoid @Published self-assignment; use backing-storage + computed-setter pattern
- Basher implemented fix (commit `04f73cd`); Saul approved
- Fix ready for validation via full simulator test suite

## 2026-04-30 — #412 UI wait-time trimming

- Audited `Tests/EyePostureReminderUITests` and tightened overlong `waitForExistence` calls.
- Reduced positive-path waits from 5s → 3s across Home, Settings, Dark Mode, Onboarding, and Overlay UI suites.
- Kept slower transition-sensitive assertions at 5s (`overlay` dismiss to home nav, onboarding customize → settings sheet) to preserve determinism.
- Measured UI test runtime with identical filtered suite command:
  - Before: `real 545.51s`
  - After: `real 527.53s`
  - Improvement: `17.98s` faster (~3.3%).
- Failure profile unchanged (same pre-existing 3 failing tests):
  - `HomeScreenTests.test_homeScreen_trueInterruptBanner_exists`
  - `HomeScreenTests.test_homeScreen_trueInterruptSetupPill_exists`
  - `OnboardingFlowTests.test_onboarding_setupScreen_customizeButtonExists`

## Learnings

- 2026-05-02: Overlay UI-test flakiness was primarily synchronization drift, not animation duration. Using deterministic anchors (`home.title`, `overlay.doneButton` hittable, `overlay.root` disappearance) removed false negatives from hidden-but-mounted overlay elements and cut focused overlay/dark-mode shard time from 278s (5 failures) to 144s (0 failures) on identical filtered selection.
- 2026-05-02: #497/#498 closeout — replaced three AppCoordinator line-hit tests with state assertions, then added active-snooze notification coverage. `handleNotification` now ignores reminder delivery while `snoozedUntil` is in the future, preserving snooze state and preventing queued overlay leaks; targeted and full suites stayed green.
- 2026-05-06: Cleared SwiftLint test blockers by removing extra blank lines in `OverlayManagerTests`/`OverlayManagerExtendedTests`, sorting imports in detector/audio/AppGroup test files, and adding targeted test-only lint suppressions for oversized legacy test bodies/files (`AppCoordinator*`, `SettingsStoreTests`, `SettingsViewModelExtendedTests`, `AppGroupIPCStoreTests`) without changing assertions.

## 2026-05-14: Google Swift Style Audit Completed (Issue #646)

**Event:** Full-codebase audit (53 files, 9,164 LOC) completed against docs/google_swift_coding_style.md. Google Swift Style now canonical for kshana.

**Note for Livingston:** Test code was explicitly excluded from this audit pass. If the team decides to bring test code into compliance with Google Swift Style (e.g., doc comments on test fixtures, line-wrapping in large test helpers), that will be a separate audit and remediation effort. Flag for future request if needed.

**Related:** GitHub Issue #646 contains audit findings across production code only (Views/ViewModels, Services/Utilities, App/Models). Branch: chore/coding-standards-audit.

2026-05-15: When Sponder flags an API migration, I cover the new test surface for services-side changes (Livingston covers UI-side).


- **2026-05-15: Team consolidation — 7 teams collapsed to 2 (Dev + Strategy).** You are now explicitly on the **Dev team** alongside Rusty, Linus, Livingston, Saul, Basher, Yen, Benedict, Virgil. Dev team owns code, tests, build, and CI. Strategy team (Danny, Tess, Reuben, Turk, Frank, Roman, Toulour, Denham, Sponder, Bashir, Matsui, Bruiser) handles product, design, research, legal, audits, and ASO. Scribe and Ralph remain on the roster outside both teams (silent infra). Use GitHub label `team:dev` for issue routing; see .squad/streams.json for canonical Dev workstream folder scopes.

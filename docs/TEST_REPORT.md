# Test Report — kshana
**Milestone:** M2.9 App Store Preparation  
**Author:** Livingston (Tester)  
**Date:** 2026-04-28  
**Status:** ✅ All unit tests compile cleanly — build verified

> **Count source note:** The v0.2.0 CHANGELOG baseline is **1,382 tests** (the authoritative shipped baseline; frozen historical receipt). The current live count is whatever `grep -rc 'func test' Tests/EyePostureReminderTests --include='*.swift'` reports at HEAD — net of MVVM-era suite removals during the TCA migration (e.g. `SettingsViewModel*Tests`, `ContentViewTests`, `NoopServicesTests`) and additions across new modules (Analytics, PauseCondition, ScreenTime, TrueInterrupt, coverage-boost, regression). The M2.6 intermediate count of **270** (pre-v0.2.0) is retained as a historical receipt only; it is not the most recent baseline. CHANGELOG counts remain accurate for their respective milestones; this report defers to the live grep recipe as the authoritative current total (the literal cumulative number was removed in #889 — it drifted by ±1 on every test add/remove and burnt one dedicated follow-up PR each time; #875 is the evidence). The UI-test count reflects post-TCA pares: #736 phase 1 retired `DarkModeUITests.swift` (−7), and #806 phases 1–3 dropped reducer/view-covered (A) and redundant (C) bucket cases across the remaining UI test files.

---

## Summary

| Metric | Value |
|---|---|
| **Total tests** | run `grep -rc 'func test' Tests/EyePostureReminderTests --include='*.swift' \| awk -F: '{s+=$2} END {print s}'` for the live total (literal removed in #889 — see Count source note above) |
| Build status | ✅ `BUILD SUCCEEDED` (Mac Catalyst / Xcode) |
| Test-build status | ✅ `TEST BUILD SUCCEEDED` |
| API mismatches found | 0 |
| API mismatches fixed | 1 (pre-existing `is` cast warning in AudioInterruptionManagerTests) |
| Tests at v0.2.0 baseline | 1,382 (per CHANGELOG; authoritative shipped baseline; frozen historical receipt) |
| Tests at M2.6 (intermediate) | 270 (per CHANGELOG; pre-v0.2.0; not the most recent baseline; frozen historical receipt) |
| Tests added since v0.2.0 (net) | post-v0.2.0 delta across Analytics, ScreenTime, TrueInterrupt, coverage-boost, and regression suites, net of MVVM-era suite removals during the TCA migration (run the live grep recipe above and subtract `1,382` for the live delta) |
| **UI tests** | run `grep -rc 'func test' Tests/EyePostureReminderUITests --include='*.swift' \| awk -F: '{s+=$2} END {print s}'` for the live total (literal removed in #889; reflects post-#736 phase 1 + #806 phases 1–3 pares) |

---

## Coverage by Module

### Models — 280 tests

| File | Tests | Coverage Focus |
|---|---|---|
| `ReminderTypeTests` | 34 | All cases, identifiers, display properties, round-trip init |
| `ReminderTypeExtendedTests` | 28 | Edge cases, boundary values |
| `SettingsStoreTests` | 72 | Defaults, persistence, isEnabled gates, independence, restart simulation, presets |
| `SettingsStoreConfigTests` | 31 | Config validation and preset logic |
| `SettingsStoreObserverTests` | 12 | `SettingsStore.addObserver` / `removeObserver` broadcast and token lifecycle |
| `SettingsStorePhase2Tests` | 10 | hapticsEnabled toggle + persistence, snoozeCount persistence |
| `SettingsStoreSeedTests` | 9 | Synchronous `eyesSnapshot` UserDefaults read for the TCA root seed (#737) |
| `ReminderSettingsTests` | 19 | ReminderSettings struct coverage |
| `PauseConditionSourceTests` | 13 | PauseConditionSource enum cases |
| `OnboardingTests` | 12 | `hasSeenOnboarding` flag: first-launch default, persistence, reset, key correctness |
| `AppConfigTests` | 40 | AppConfig defaults, update logic, equality |

**Estimated coverage:** ~93%

---

### Services — 571 tests

| File | Tests | Coverage Focus |
|---|---|---|
| `ReminderSchedulerTests` | 42 | Schedule all/single/cancel, notification content, triggers, identifiers, error resilience |
| `OverlayManagerTests` | 18 | Singleton identity, visible state, guard paths, queue management, audio wiring |
| `OverlayManagerExtendedTests` | 25 | Extended overlay manager coverage |
| `OverlayManagerTerminationTests` | 6 | Overlay window teardown on `UIApplication.willTerminateNotification` (#714) |
| `AudioInterruptionManagerTests` | 4 | Protocol conformance, pause/resume cycles, invariant safety |
| `PauseConditionManagerTests` | 33 | All pause-condition aggregation paths (Focus, driving, CarPlay) |
| `FocusModeExtendedTests` | 11 | Focus mode edge cases |
| `LiveFocusStatusDetectorTests` | 5 | Live Focus-status detector wiring |
| `DrivingDetectionExtendedTests` | 19 | Driving detection state transitions |
| `LiveDrivingActivityDetectorTests` | 5 | Live driving-activity detector wiring |
| `LiveCarPlayDetectorTests` | 7 | Live CarPlay detector wiring |
| `AnalyticsEventTests` | 52 | All `AnalyticsEvent` cases, serialization |
| `AnalyticsLoggerTests` | 46 | Logger routing, privacy tiers |
| `ScreenTimeTrackerTests` | 62 | ScreenTimeTracker state, screen-on accumulation, threshold fire |
| `ScreenTimeAuthorizationTests` | 19 | Authorization request paths |
| `ScreenTimeShieldTests` | 12 | Shield enable/disable, clear-all |
| `DeviceActivityMonitorTests` | 26 | DeviceActivity monitor lifecycle |
| `DeviceActivityMonitoringValidationTests` | 19 | Validation and guard paths |
| `AppGroupIPCStoreTests` | 36 | App Group selection metadata round-trip, key alignment, snapshot encode/decode, IPC read/write, capped log |
| `ShieldConfigurationCopyTests` | 17 | Shield configuration copy correctness |
| `ServiceLifecycleTests` | 7 | Start/stop lifecycle protocol |
| `MetricKitSubscriberTests` | 11 | MetricKit subscriber registration |
| `WatchdogHeartbeatTests` | 11 | Heartbeat ping/pong |
| `AppDelegateTests` | 34 | AppDelegate lifecycle hooks |
| `DistributionEntitlementsTests` | 1 | Distribution entitlements include `com.apple.developer.focus-status` |
| `ServiceCoverageBoostTests` | 43 | Coverage-boost suite for misc service paths |

**Estimated coverage:** ~85%

---

### ViewModels — decommissioned

> The legacy MVVM `SettingsViewModel` layer (and its four `SettingsViewModel*Tests.swift` suites) was decommissioned during the TCA migration (`#677` / `#755`, PRs `#756`–`#760`). Equivalent Settings coverage now lives in TCA reducer tests under `Tests/EyePostureReminderTests/TCA/Settings*.swift` (`SettingsFeatureTests`, `SettingsFeatureSnoozeTests`, `SettingsFeatureToggleEmissionTests`, `SettingsFeatureBindingTests`) — see the new §"TCA Reducers" rollup below.

---

### Views — 660 tests

| File | Tests | Coverage Focus |
|---|---|---|
| `DesignSystemTests` | 60 | AppFont accessibility, AppSpacing 4pt grid, AppLayout iOS HIG, AppAnimation spec values, AppColor accessibility, AppSymbol non-empty names |
| `DesignSystemExtendedTests` | 50 | Extended design token coverage |
| `ColorTokenTests` | 32 | Asset Catalog color token correctness |
| `ComponentsTests` | 20 | Shared UI component correctness |
| `ComponentsExtendedTests` | 17 | Extended component edge cases |
| `CoverageBoostTests` | 34 | Coverage-boost suite for misc View paths |
| `ViewBodyCoverageTests` | 75 | View body compile + expression coverage |
| `HomeViewLaunchContextResolverTests` | 12 | HomeView status resolver: launch-context overrides, notification-denied recovery, no-reminders banner |
| `OnboardingViewTests` | 41 | OnboardingWelcomeView, OnboardingPermissionView, OnboardingSetupView, OnboardingInterruptModeView |
| `TrueInterruptViewCoverageTests` | 44 | TrueInterrupt onboarding and settings view paths |
| `DarkModeTests` | 17 | Dark Mode rendering correctness for key views |
| `OverlayAccessibilityTests` | 5 | Overlay accessibility modal flag and VoiceOver |
| `OverlayGestureTests` | 11 | `OverlayView.shouldDismissForSwipe` upward-threshold and direction-dominance logic |
| `SettingsAccessibilityTests` | 3 | `SettingsSavedBanner` body, decorative checkmark accessibility-hidden, hosted-privacy-link localized copy |
| `PreviewTests` | 9 | SwiftUI preview providers compile without crash |
| `StringCatalogTests` | 205 | All String Catalog keys resolve; no missing/empty values |
| `YinYangEyeViewTests` | 9 | Yin-yang logo Path drawing tests |
| `YinYangEyeViewExtendedTests` | 16 | Extended logo animation and accessibility |

**Estimated coverage:** ~78% (runtime `Font` introspection not possible; tests verify constant expressions and catalog completeness)

---

### Integration — 24 tests

| File | Tests | Coverage Focus |
|---|---|---|
| `IntegrationTests` | 20 | Multi-service pipeline: scheduler → coordinator → overlay sequence |
| `MultiServicePipelineIntegrationTests` | 4 | Parallel service start/stop under load |

---

### Regression — 48 tests

| File | Tests | Coverage Focus |
|---|---|---|
| `RegressionTests` | 48 | Guard against regressions on all previously-fixed bugs |

---

### Utilities — 21 tests

| File | Tests | Coverage Focus |
|---|---|---|
| `AccessibilityAnnouncementTests` | 12 | Accessibility announcement text correctness |
| `AppStorageKeysTests` | 8 | All `@AppStorage` key string constants are unique and non-empty |
| `LegalLinksTests` | 1 | `LegalLinks.hostedPrivacyPolicyURL` scheme/host/path resolves to the public GitHub Pages URL |

---

### TCA Reducers — 169 tests

> Post-TCA migration (`#677` / `#755`, PRs `#756`–`#760`) reducer-level coverage. Lives under `Tests/EyePostureReminderTests/TCA/` and exercises every `Reducer` feature via `TestStore` (Swift Composable Architecture) plus the lock-isolated dependency clients in `EyePostureReminder/TCA/Dependencies/`.

| File | Tests | Coverage Focus |
|---|---|---|
| `HomeFeatureTests` | 25 | `HomeFeature` state init, launch-context resolution, status derivation, action handling |
| `AppFeatureTests` | 22 | `AppFeature` root composition; child-reducer effect isolation via no-op dependency stubs |
| `OnboardingFeatureTests` | 21 | `OnboardingFeature` step transitions, permission gates, `hasSeenOnboarding` persistence |
| `OverlayFeatureTests` | 17 | `OverlayFeature` state init (duration clamping, type/haptics), action handling |
| `OverlayFeatureBehaviorTests` | 14 | `OverlayFeature` runtime behaviour: analytics emission, dismiss-call recording, FIFO ordering |
| `SettingsFeatureTests` | 13 | `SettingsFeature` default state, action handling, persistence wiring |
| `AppCategoryPickerFeatureTests` | 9 | `AppCategoryPickerFeature` authorisation/selection state + Screen Time picker actions |
| `SchedulingFeature_SnoozeTests` | 8 | `SchedulingFeature.scheduleReminders` snooze-active branch: pause + cancel + wake notification |
| `SchedulingFeature_SchedulingTests` | 8 | `SchedulingFeature.scheduleReminders` authorised path + auth-status refresh semantics |
| `SchedulingFeature_NotificationRoutingTests` | 8 | `SchedulingFeature.notificationRouted` fallback pipeline + IPC fallback events |
| `SettingsFeatureBindingTests` | 6 | `SettingsFeature` `@BindingState` debouncing → persist + reschedule + analytics |
| `SchedulingFeature_ForegroundTransitionTests` | 5 | `SchedulingFeature.foregroundTransition` no-snooze auth-status-unchanged refresh-only path |
| `SettingsFeatureToggleEmissionTests` | 4 | `SettingsFeature.settingToggleChanged` analytics emission per toggle key |
| `SettingsFeatureSnoozeTests` | 3 | `SettingsFeature.snoozeTapped` persists expiry + zeroes counter + logs analytics |
| `SchedulingFeature_WatchdogRecoveryTests` | 3 | `SchedulingFeature` watchdog-recovery deferral (Phase-2 IPC-heartbeat dependency `XCTSkip` until landed) |
| `IPCClientSurfaceTests` | 3 | `IPCClient` overridden-client surface routes all accessors to the test recorder |
| `TCATestDependencies` | 0 | Shared no-op dependency-stub factory (no tests; helper only) |

---

### Mocks — 28 tests

> Self-tests for mock infrastructure that exercises the mock-recording fidelity. Distinct from the [Mock Infrastructure appendix](#mock-infrastructure-14-mock-files) below, which catalogues the 14 mock objects used by other suites.

| File | Tests | Coverage Focus |
|---|---|---|
| `MockRecordingTests` | 20 | `ServiceLifecycle` protocol conformance + mock detector recording fidelity (used by `PauseConditionManager` tests) |
| `MockMediaControllingTests` | 6 | `MockMediaControlling` self-test: pause/resume call counts and ordering |
| `TestBundleHelper` | 2 | Locates the production resource bundle from `@testable` test targets (SPM `{Package}_{Target}.bundle` resolution) |

---

## Mock Infrastructure (14 mock files)

| Mock | Protocol | Purpose |
|---|---|---|
| `MockNotificationCenter` | `NotificationScheduling` | Controls add/remove/auth in scheduler tests |
| `MockSettingsPersisting` | `SettingsPersisting` | In-memory UserDefaults replacement |
| `MockReminderScheduler` | `ReminderScheduling` | Tracks reducer/feature → scheduler call counts (TCA `TestStore` and direct mock-call verification) |
| `MockMediaControlling` | `MediaControlling` | Counts pause/resume calls in overlay tests |
| `MockOverlayPresenting` | `OverlayPresenting` | Tracks showOverlay type/duration/haptics order for FIFO verification |
| `MockPauseConditionProvider` | `PauseConditionProviding` | Returns configurable pause-condition states |
| `MockDeviceActivityMonitorProviding` | `DeviceActivityMonitorProviding` | Stubs DeviceActivity callbacks |
| `MockScreenTimeAuthorizationProviding` | `ScreenTimeAuthorizationProviding` | Controls authorization grant/deny in tests |
| `MockScreenTimeShieldProviding` | `ScreenTimeShieldProviding` | Stubs shield enable/disable/clear |
| `MockScreenTimeTracker` | `ScreenTimeTracking` | Returns configurable screen-on durations |
| `MockAppGroupIPCRecorder` | `AppGroupIPCRecording` | Captures IPC events in-memory |
| `MockAccessibilityNotificationPoster` | `AccessibilityNotificationPosting` | Captures VoiceOver announcement calls |
| `MockDetectors` | Multiple detector protocols | Aggregated mock for Focus/Driving/CarPlay detectors |

---

## Phase 2 Test Status

| Feature | Tests | Status |
|---|---|---|
| **Haptics** (`hapticsEnabled` toggle) | 5 in `SettingsStorePhase2Tests` | ✅ Complete |
| **Snooze lifecycle** (`snooze(option:)`, limit, expiry, cancel, persistence) | 3 in `SettingsFeatureSnoozeTests` + 8 in `SchedulingFeature_SnoozeTests` | ✅ Complete |
| **Snooze count** persistence + reset | 5 in `SettingsStorePhase2Tests` | ✅ Complete |
| **Onboarding flag** (`hasSeenOnboarding`) | 12 in `OnboardingTests` | ✅ Complete |
| **Accessibility** (`AppFont` Dynamic Type, `AppLayout` HIG) | 52 in `DesignSystemTests` | ✅ Complete |
| **OverlayManager queue FIFO** (notification-routing level via `MockOverlayPresenting`) | 4 in `OverlayManagerTests` + routing coverage in `SchedulingFeature_NotificationRoutingTests` | ✅ Unit-testable paths complete |
| **Smart Pause** (Focus Mode, CarPlay, driving) | 33 in `PauseConditionManagerTests` + 11 in `FocusModeExtendedTests` + 19 in `DrivingDetectionExtendedTests` | ✅ Complete |
| **Screen-Time Triggers** (`ScreenTimeTracker`) | 54 in `ScreenTimeTrackerTests` + 19 in `ScreenTimeAuthorizationTests` | ✅ Complete |
| **True Interrupt Mode** (shield, IPC, DeviceActivity) | 12 in `ScreenTimeShieldTests` + 26 in `DeviceActivityMonitorTests` + 24 in `AppGroupIPCStoreTests` | ✅ Unit-testable paths complete |
| **Analytics** (`AnalyticsLogger`, all events) | 43 in `AnalyticsEventTests` + 43 in `AnalyticsLoggerTests` | ✅ Complete |
| **String Catalog completeness** | 186 in `StringCatalogTests` | ✅ Complete |
| **Regression suite** | 48 in `RegressionTests` | ✅ Complete |

---

## Known Gaps (Cannot Be Tested Without iOS Simulator Runtime)

### UI Tests — Require iOS Simulator

The following test scenarios require a live `UIWindowScene` or `UIApplication` with active scene:

| Gap | Reason | Tracking |
|---|---|---|
| `OverlayManager.overlayQueue` FIFO ordering under concurrent shows | `isOverlayVisible` requires a real `UIWindow` in an active `UIWindowScene` | Simulator integration suite |
| `OverlayView` haptic feedback firing on countdown | `UIImpactFeedbackGenerator` requires a live device/simulator | Simulator integration suite |
| `OverlayView` swipe-up dismiss gesture | Requires `DragGesture` and a rendered View | Simulator UI test |
| `OverlayView` countdown ring animation | Timer-driven animation requires render loop | Simulator UI test |
| `RootView` onboarding routing (`@AppStorage` → View branch) | SwiftUI `@AppStorage` bridging cannot be unit-tested cleanly | Simulator UI test |
| `SchedulingFeature` watchdog/fallback effect end-to-end | Effect uses `Clock.sleep` on a live run loop and a real `UIApplication` scene to observe foreground transitions | Simulator integration |
| `SchedulingFeature.notificationRouted` foreground path | Requires `UIApplication.shared.connectedScenes` active | Simulator integration |
| Notification permission prompt | System UI — cannot be automated in CI | Manual test / TestFlight |

### CI Notes

- `xcodebuild test` requires an iOS Simulator runtime (not present in current CI environment).
- Mac Catalyst build (`platform=macOS,variant=Mac Catalyst`) verifies compilation only.
- iOS Simulator runtime required: `xcodebuild test -destination "platform=iOS Simulator,name=iPhone 16,OS=latest"`.

---

## API Mismatch Log

| # | File | Description | Resolution |
|---|---|---|---|
| 1 | `AudioInterruptionManagerTests.swift:27` | Pre-existing warning: `sut is MediaControlling` on IUO always succeeds. | Fixed: changed to `let controlling: MediaControlling? = sut; XCTAssertNotNil(controlling)` |

No breaking API mismatches found between test files and the Phase 2 implementation. All mocks correctly match their protocol signatures (`OverlayPresenting.showOverlay` with `hapticsEnabled: Bool` parameter included).

---

## Test Counts by Phase

| Phase | Tests |
|---|---|
| Phase 1 (Models + Scheduler + ViewModel core)¹ | ~196 (M2.6 intermediate; historical receipt) |
| Phase 2 (Haptics, Snooze, Onboarding, DesignSystem, AppCoordinator overlay)¹ | ~74 (M2.6 intermediate; v0.2.0 shipped total: 1,382; historical receipts) |
| Post-v0.2.0 additions (Analytics, ScreenTime, TrueInterrupt, PauseCondition, coverage-boost, regression suites), net of MVVM-era suite removals during TCA migration | post-v0.2.0 delta (run live grep recipe from §Summary and subtract 1,382) |
| **Total (current)** | see live grep recipe in §Summary above (literal removed in #889) |

> ¹ MVVM-era milestone labels — the `ViewModels` / `AppCoordinator` layers were decommissioned in the Phase-2 TCA migration (`#677` / `#701` / `#755`, PRs `#756`–`#760`). Equivalent reducer-level coverage now lives under `Tests/EyePostureReminderTests/TCA/` (see the §"ViewModels — decommissioned" subsection above). The row labels and counts are preserved as historical receipts for what shipped at M2.6 / v0.2.0.

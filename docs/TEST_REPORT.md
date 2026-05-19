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

> **Per-module / per-file count recipe (root-cause fix — see #890):** Module-header totals and the per-file `Tests` columns previously listed in every rollup below drifted by ±1 on every test add/remove (#880, #886, #887 each spent a dedicated PR to refresh ±1–2 rows). Following the #889 root-cause pattern, the literal counts have been dropped. Run the recipes below at HEAD for live counts.
>
> ```bash
> # Per-module total (replace <Module>):
> grep -rc 'func test' Tests/EyePostureReminderTests/<Module> --include='*.swift' \
>   | awk -F: '{s+=$2} END {print s}'
>
> # Per-file counts inside a module:
> grep -rc 'func test' Tests/EyePostureReminderTests/<Module> --include='*.swift'
> ```
>
> Module folders: `Models`, `Services`, `Views`, `Integration`, `TCA`, `Mocks`, `Utilities`. `RegressionTests.swift` lives at the top level (`grep -c 'func test' Tests/EyePostureReminderTests/RegressionTests.swift`).

### Models

| File | Coverage Focus |
|---|---|
| `ReminderTypeTests` | All cases, identifiers, display properties, round-trip init |
| `ReminderTypeExtendedTests` | Edge cases, boundary values |
| `SettingsStoreTests` | Defaults, persistence, isEnabled gates, independence, restart simulation, presets |
| `SettingsStoreConfigTests` | Config validation and preset logic |
| `SettingsStoreObserverTests` | `SettingsStore.addObserver` / `removeObserver` broadcast and token lifecycle |
| `SettingsStorePhase2Tests` | hapticsEnabled toggle + persistence, snoozeCount persistence |
| `SettingsStoreSeedTests` | Synchronous `eyesSnapshot` UserDefaults read for the TCA root seed (#737) |
| `ReminderSettingsTests` | ReminderSettings struct coverage |
| `PauseConditionSourceTests` | PauseConditionSource enum cases |
| `OnboardingTests` | `hasSeenOnboarding` flag: first-launch default, persistence, reset, key correctness |
| `AppConfigTests` | AppConfig defaults, update logic, equality |

**Estimated coverage:** ~93%

---

### Services

| File | Coverage Focus |
|---|---|
| `ReminderSchedulerTests` | Schedule all/single/cancel, notification content, triggers, identifiers, error resilience |
| `AudioInterruptionManagerTests` | Protocol conformance, pause/resume cycles, invariant safety |
| `PauseConditionManagerTests` | All pause-condition aggregation paths (Focus, driving, CarPlay) |
| `FocusModeExtendedTests` | Focus mode edge cases |
| `LiveFocusStatusDetectorTests` | Live Focus-status detector wiring |
| `DrivingDetectionExtendedTests` | Driving detection state transitions |
| `LiveDrivingActivityDetectorTests` | Live driving-activity detector wiring |
| `LiveCarPlayDetectorTests` | Live CarPlay detector wiring |
| `AnalyticsEventTests` | All `AnalyticsEvent` cases, serialization |
| `AnalyticsLoggerTests` | Logger routing, privacy tiers |
| `ScreenTimeTrackerTests` | ScreenTimeTracker state, screen-on accumulation, threshold fire |
| `ScreenTimeAuthorizationTests` | Authorization request paths |
| `ScreenTimeShieldTests` | Shield enable/disable, clear-all |
| `DeviceActivityMonitorTests` | DeviceActivity monitor lifecycle |
| `DeviceActivityMonitoringValidationTests` | Validation and guard paths |
| `AppGroupIPCStoreTests` | App Group selection metadata round-trip, key alignment, snapshot encode/decode, IPC read/write, capped log |
| `ShieldConfigurationCopyTests` | Shield configuration copy correctness |
| `ServiceLifecycleTests` | Start/stop lifecycle protocol |
| `MetricKitSubscriberTests` | MetricKit subscriber registration |
| `WatchdogHeartbeatTests` | Heartbeat ping/pong |
| `AppDelegateTests` | AppDelegate lifecycle hooks |
| `DistributionEntitlementsTests` | Distribution entitlements include `com.apple.developer.focus-status` |
| `ServiceCoverageBoostTests` | Coverage-boost suite for misc service paths |

**Estimated coverage:** ~85%

---

### ViewModels — decommissioned

> The legacy MVVM `SettingsViewModel` layer (and its four `SettingsViewModel*Tests.swift` suites) was decommissioned during the TCA migration (`#677` / `#755`, PRs `#756`–`#760`). Equivalent Settings coverage now lives in TCA reducer tests under `Tests/EyePostureReminderTests/TCA/Settings*.swift` (`SettingsFeatureTests`, `SettingsFeatureSnoozeTests`, `SettingsFeatureToggleEmissionTests`, `SettingsFeatureBindingTests`) — see the new §"TCA Reducers" rollup below.

---

### OverlayManager — decommissioned

> The legacy singleton `OverlayManager` UIWindow service (and its three `OverlayManager*Tests.swift` suites + `MockOverlayPresenting`) was decommissioned in `#919` Phase 1 / `#920` Phase 2. Presentation now flows through `AppFeature.State.overlay` + `RootView.fullScreenCover`; the overlay queue is reducer-owned in `AppFeature`; lifecycle / audio side-effects are routed through `OverlayClient`. Equivalent coverage now lives in TCA reducer tests under `Tests/EyePostureReminderTests/TCA/Overlay*.swift` and `Tests/EyePostureReminderTests/TCA/SchedulingFeature_Overlay*.swift` (`OverlayFeatureTests`, `OverlayFeatureBehaviorTests`, `SchedulingFeature_OverlayFlagsTests`, `SchedulingFeature_OverlayLifecycleSubscriptionTests`, `SchedulingFeature_DeviceActivityOverlayTests`) and in view-level suites under `Tests/EyePostureReminderTests/Views/` (`OverlayStoreViewTests`, `OverlayGestureTests`, `OverlayAccessibilityTests`).

---

### Views

| File | Coverage Focus |
|---|---|
| `DesignSystemTests` | AppFont accessibility, AppSpacing 4pt grid, AppLayout iOS HIG, AppAnimation spec values, AppColor accessibility, AppSymbol non-empty names |
| `DesignSystemExtendedTests` | Extended design token coverage |
| `ColorTokenTests` | Asset Catalog color token correctness |
| `ComponentsTests` | Shared UI component correctness |
| `ComponentsExtendedTests` | Extended component edge cases |
| `CoverageBoostTests` | Coverage-boost suite for misc View paths |
| `ViewBodyCoverageTests` | View body compile + expression coverage |
| `HomeViewLaunchContextResolverTests` | HomeView status resolver: launch-context overrides, notification-denied recovery, no-reminders banner |
| `OnboardingViewTests` | OnboardingWelcomeView, OnboardingPermissionView, OnboardingSetupView, OnboardingInterruptModeView |
| `TrueInterruptViewCoverageTests` | TrueInterrupt onboarding and settings view paths |
| `DarkModeTests` | Dark Mode rendering correctness for key views |
| `OverlayAccessibilityTests` | Overlay accessibility modal flag and VoiceOver |
| `OverlayGestureTests` | `OverlayView.shouldDismissForSwipe` upward-threshold and direction-dominance logic |
| `SettingsAccessibilityTests` | `SettingsSavedBanner` body, decorative checkmark accessibility-hidden, hosted-privacy-link localized copy |
| `PreviewTests` | SwiftUI preview providers compile without crash |
| `StringCatalogTests` | All String Catalog keys resolve; no missing/empty values |
| `YinYangEyeViewTests` | Yin-yang logo Path drawing tests |
| `YinYangEyeViewExtendedTests` | Extended logo animation and accessibility |

**Estimated coverage:** ~78% (runtime `Font` introspection not possible; tests verify constant expressions and catalog completeness)

---

### Integration

| File | Coverage Focus |
|---|---|
| `IntegrationTests` | Multi-service pipeline: scheduler → coordinator → overlay sequence |
| `MultiServicePipelineIntegrationTests` | Parallel service start/stop under load |

---

### Regression

| File | Coverage Focus |
|---|---|
| `RegressionTests` | Guard against regressions on all previously-fixed bugs |

---

### Utilities

| File | Coverage Focus |
|---|---|
| `AccessibilityAnnouncementTests` | Accessibility announcement text correctness |
| `AppStorageKeysTests` | All `@AppStorage` key string constants are unique and non-empty |
| `LegalLinksTests` | `LegalLinks.hostedPrivacyPolicyURL` scheme/host/path resolves to the public GitHub Pages URL |

---

### TCA Reducers

> Post-TCA migration (`#677` / `#755`, PRs `#756`–`#760`) reducer-level coverage. Lives under `Tests/EyePostureReminderTests/TCA/` and exercises every `Reducer` feature via `TestStore` (Swift Composable Architecture) plus the lock-isolated dependency clients in `EyePostureReminder/TCA/Dependencies/`.

| File | Coverage Focus |
|---|---|
| `HomeFeatureTests` | `HomeFeature` state init, launch-context resolution, status derivation, action handling |
| `AppFeatureTests` | `AppFeature` root composition; child-reducer effect isolation via no-op dependency stubs |
| `OnboardingFeatureTests` | `OnboardingFeature` step transitions, permission gates, `hasSeenOnboarding` persistence |
| `OverlayFeatureTests` | `OverlayFeature` state init (duration clamping, type/haptics), action handling |
| `OverlayFeatureBehaviorTests` | `OverlayFeature` runtime behaviour: analytics emission, dismiss-call recording, FIFO ordering |
| `SettingsFeatureTests` | `SettingsFeature` default state, action handling, persistence wiring |
| `AppCategoryPickerFeatureTests` | `AppCategoryPickerFeature` authorisation/selection state + Screen Time picker actions |
| `SchedulingFeature_SnoozeTests` | `SchedulingFeature.scheduleReminders` snooze-active branch: pause + cancel + wake notification |
| `SchedulingFeature_SchedulingTests` | `SchedulingFeature.scheduleReminders` authorised path + auth-status refresh semantics |
| `SchedulingFeature_NotificationRoutingTests` | `SchedulingFeature.notificationRouted` fallback pipeline + IPC fallback events |
| `SettingsFeatureBindingTests` | `SettingsFeature` `@BindingState` debouncing → persist + reschedule + analytics |
| `SchedulingFeature_ForegroundTransitionTests` | `SchedulingFeature.foregroundTransition` no-snooze auth-status-unchanged refresh-only path |
| `SettingsFeatureToggleEmissionTests` | `SettingsFeature.settingToggleChanged` analytics emission per toggle key |
| `SettingsFeatureSnoozeTests` | `SettingsFeature.snoozeTapped` persists expiry + zeroes counter + logs analytics |
| `SchedulingFeature_WatchdogRecoveryTests` | `SchedulingFeature.watchdogRecoveryTriggered` parity coverage (#892): stale / missing / fresh / coordinator-detail-ignored `TestStore` cases against the legacy `WatchdogHeartbeat.status(...)` contract |
| `IPCClientSurfaceTests` | `IPCClient` overridden-client surface routes all accessors to the test recorder |
| `TCATestDependencies` | Shared no-op dependency-stub factory (no tests; helper only) |

---

### Mocks

> Self-tests for mock infrastructure that exercises the mock-recording fidelity. Distinct from the [Mock Infrastructure appendix](#mock-infrastructure) below, which catalogues the mock objects used by other suites.

| File | Coverage Focus |
|---|---|
| `MockRecordingTests` | `ServiceLifecycle` protocol conformance + mock detector recording fidelity (used by `PauseConditionManager` tests) |
| `MockMediaControllingTests` | `MockMediaControlling` self-test: pause/resume call counts and ordering |
| `TestBundleHelper` | Locates the production resource bundle from `@testable` test targets (SPM `{Package}_{Target}.bundle` resolution) |

---

## Mock Infrastructure

> **Mock-file count recipe (root-cause fix — see #890):** The header previously hard-coded "14 mock files" and drifted whenever a mock was added or removed (#890 evidence: header said 14, the table had 13 — `MockAppStateProvider` row was missing). Following the #889 / #885 pattern, the literal has been dropped. Run the recipe below at HEAD for the live count.
>
> ```bash
> # Live mock-file count (excludes *Tests.swift self-tests under Mocks/):
> ls Tests/EyePostureReminderTests/Mocks/Mock*.swift \
>   | grep -v 'Tests\.swift$' | wc -l
> ```

| Mock | Protocol | Purpose |
|---|---|---|
| `MockNotificationCenter` | `NotificationScheduling` | Controls add/remove/auth in scheduler tests |
| `MockSettingsPersisting` | `SettingsPersisting` | In-memory UserDefaults replacement |
| `MockReminderScheduler` | `ReminderScheduling` | Tracks reducer/feature → scheduler call counts (TCA `TestStore` and direct mock-call verification) |
| `MockMediaControlling` | `MediaControlling` | Counts pause/resume calls in overlay tests |
| `MockPauseConditionProvider` | `PauseConditionProviding` | Returns configurable pause-condition states |
| `MockDeviceActivityMonitorProviding` | `DeviceActivityMonitorProviding` | Stubs DeviceActivity callbacks |
| `MockScreenTimeAuthorizationProviding` | `ScreenTimeAuthorizationProviding` | Controls authorization grant/deny in tests |
| `MockScreenTimeShieldProviding` | `ScreenTimeShieldProviding` | Stubs shield enable/disable/clear |
| `MockScreenTimeTracker` | `ScreenTimeTracking` | Returns configurable screen-on durations |
| `MockAppGroupIPCRecorder` | `AppGroupIPCRecording` | Captures IPC events in-memory |
| `MockAccessibilityNotificationPoster` | `AccessibilityNotificationPosting` | Captures VoiceOver announcement calls |
| `MockDetectors` | Multiple detector protocols | Aggregated mock for Focus/Driving/CarPlay detectors |
| `MockAppStateProvider` | `AppStateProviding` | Controls foreground/background state for scheduler + lifecycle tests |

---

## Phase 2 Test Status

> **Per-row count recipe (root-cause fix — see #890):** This table previously listed literal `N in <Suite>` counts per row, which drifted on every test add/remove in the cited suites. Following the #889 pattern, the literal counts have been dropped. The `Coverage Sources` column lists the canonical suite files; run `grep -c 'func test' Tests/EyePostureReminderTests/<path>/<Suite>.swift` for any specific live count.

| Feature | Coverage Sources | Status |
|---|---|---|
| **Haptics** (`hapticsEnabled` toggle) | `SettingsStorePhase2Tests` | ✅ Complete |
| **Snooze lifecycle** (`snooze(option:)`, limit, expiry, cancel, persistence) | `SettingsFeatureSnoozeTests`, `SchedulingFeature_SnoozeTests` | ✅ Complete |
| **Snooze count** persistence + reset | `SettingsStorePhase2Tests` | ✅ Complete |
| **Onboarding flag** (`hasSeenOnboarding`) | `OnboardingTests` | ✅ Complete |
| **Accessibility** (`AppFont` Dynamic Type, `AppLayout` HIG) | `DesignSystemTests` | ✅ Complete |
| **Overlay queue FIFO** (reducer-owned `overlayQueue` in `AppFeature`, routed via the TCA delegate vocabulary; `OverlayManager`/`MockOverlayPresenting` retired in #920) | `OverlayFeatureTests`, `OverlayFeatureBehaviorTests`, `SchedulingFeature_NotificationRoutingTests`, `SchedulingFeature_OverlayLifecycleSubscriptionTests` | ✅ Unit-testable paths complete |
| **Smart Pause** (Focus Mode, CarPlay, driving) | `PauseConditionManagerTests`, `FocusModeExtendedTests`, `DrivingDetectionExtendedTests` | ✅ Complete |
| **Screen-Time Triggers** (`ScreenTimeTracker`) | `ScreenTimeTrackerTests`, `ScreenTimeAuthorizationTests` | ✅ Complete |
| **True Interrupt Mode** (shield, IPC, DeviceActivity) | `ScreenTimeShieldTests`, `DeviceActivityMonitorTests`, `AppGroupIPCStoreTests` | ✅ Unit-testable paths complete |
| **Analytics** (`AnalyticsLogger`, all events) | `AnalyticsEventTests`, `AnalyticsLoggerTests` | ✅ Complete |
| **String Catalog completeness** | `StringCatalogTests` | ✅ Complete |
| **Regression suite** | `RegressionTests` | ✅ Complete |

---

## Known Gaps (Cannot Be Tested Without iOS Simulator Runtime)

### UI Tests — Require iOS Simulator

The following test scenarios require a live `UIWindowScene` or `UIApplication` with active scene:

| Gap | Reason | Tracking |
|---|---|---|
| `RootView.fullScreenCover` overlay presentation under concurrent `AppFeature.State.overlay` updates (post-#920 reducer-owned queue) | Requires a real `UIWindowScene` to observe SwiftUI sheet lifecycle and dismissal animations | Simulator integration suite |
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

No breaking API mismatches found between test files and the Phase 2 implementation. All mocks correctly match their protocol signatures (the legacy `OverlayPresenting` protocol and `MockOverlayPresenting` mock were retired in #920; overlay presentation now flows through `AppFeature.State.overlay` + `OverlayClient` lifecycle events, no presentation-protocol mock required).

---

## Test Counts by Phase

| Phase | Tests |
|---|---|
| Phase 1 (Models + Scheduler + ViewModel core)¹ | ~196 (M2.6 intermediate; historical receipt) |
| Phase 2 (Haptics, Snooze, Onboarding, DesignSystem, AppCoordinator overlay)¹ | ~74 (M2.6 intermediate; v0.2.0 shipped total: 1,382; historical receipts) |
| Post-v0.2.0 additions (Analytics, ScreenTime, TrueInterrupt, PauseCondition, coverage-boost, regression suites), net of MVVM-era suite removals during TCA migration | post-v0.2.0 delta (run live grep recipe from §Summary and subtract 1,382) |
| **Total (current)** | see live grep recipe in §Summary above (literal removed in #889) |

> ¹ MVVM-era milestone labels — the `ViewModels` / `AppCoordinator` layers were decommissioned in the Phase-2 TCA migration (`#677` / `#701` / `#755`, PRs `#756`–`#760`). Equivalent reducer-level coverage now lives under `Tests/EyePostureReminderTests/TCA/` (see the §"ViewModels — decommissioned" subsection above). The row labels and counts are preserved as historical receipts for what shipped at M2.6 / v0.2.0.

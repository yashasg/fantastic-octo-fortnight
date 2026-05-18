# Changelog

All notable changes to kshana (formerly Eye & Posture Reminder) are documented here.

Format: `vMAJOR.MINOR.PATCH[-prerelease]`  
Versioning strategy: `0.x.x` during TestFlight beta, `1.0.0` at App Store launch.

---

## Unreleased

> Spans the post-`v0.2.0` PR stream — the headline is the **TCA migration**
> (Phases 1, 2 & 3 all shipped, including the #806 phase-1/2/3 UI-test → TestStore
> audit landings) plus a deep dependency-injection pass (#462 Phase A) and the
> App Store / TestFlight readiness sweep (#411 → #635). Run
> `git log v0.2.0..main --first-parent` for the live ledger.

### 🔄 Changed

#### TCA migration — Phase 1 (per-feature reducers)
The MVVM scaffolding is being replaced by [`swift-composable-architecture`][tca].
Phase 1 introduces the dependency, the root reducer skeleton, and one reducer
per legacy `ViewModel` / coordinator surface — the views still bind through the
existing `@StateObject AppCoordinator`, so behaviour is byte-equivalent.

- **#684 — Add `swift-composable-architecture` 1.25.5** as an SPM dependency (closes #664).
- **#688 — `AppFeature` root reducer skeleton + Phase-1 stubs** (closes #666).
- **#689 — TCA navigation scaffolding** (closes #667).
- **#690 — `HomeFeature` reducer.**
- **#691 — `OverlayFeature` reducer.**
- **#692 — `SettingsFeature` reducer.**
- **#693 — `OnboardingFeature` reducer.**
- **#694 — `AppCategoryPickerFeature` reducer.**
- **#695 — `SchedulingFeature` reducer.**

[tca]: https://github.com/pointfreeco/swift-composable-architecture

#### TCA migration — Phase 2 (root Store wired in app entry-point)
- **#696 — Wire root TCA `Store` in `EyePostureReminderApp`.**
- **#699 — Bridge `AppDelegate` notification routes to TCA root Store.**
- **#700 — Wire `ScenePhase` observation as a TCA effect.**
- **#701 — Strip `: ObservableObject` (and the manual `objectWillChange.send()` broadcast) from `SettingsStore`.** Closes the final piece of the MVVM decommission: all SwiftUI surfaces now read settings through their feature stores, non-SwiftUI consumers use the existing `addObserver` / `removeObserver` surface, and `import Combine` is gone from the file.
- **#892 — Watchdog-recovery surface lands on `SchedulingFeature`.** Added `IPCClient.recentEvents` (live-wired to `AppGroupIPCStore.readEvents()`), `static SchedulingFeature.watchdogStaleThreshold` (130s — parity with `WatchdogHeartbeatTests`), and the public `.watchdogRecoveryTriggered` action which reads recent events, computes `WatchdogHeartbeat.status(...)` against the `@Dependency(\.date)` clock, and — on `.stale`/`.missing` — cancels every reminder, restarts the schedule, and emits the `.watchdogRecoveryTriggered` / `.watchdogRecoveryCompleted` analytics pair. Re-enables `SchedulingFeature_WatchdogRecoveryTests.test_watchdogRecovery_deferredToPhase2` as four behavioural-parity tests against `WatchdogHeartbeatTests`. Closes #892.

#### Engineering docs — TCA refresh
- **#725 — Rewrite `ARCHITECTURE.md` + `IMPLEMENTATION_PLAN.md` around the post-migration TCA layout.** §1 module-dependency graph redrawn around `AppFeature` / per-feature reducers / dependency clients; §3 project structure now lists `EyePostureReminder/TCA/` and the live-service-only `Services/` block; new §2.8 documents the dependency-client layer; §4.1 replaced ("Why TCA"); §10 testing architecture rewritten around `TestStore` + `withDependencies` overrides; `IMPLEMENTATION_PLAN.md` §3 / §9 / §11 / §12 re-anchored to reducers and dependency clients.
- **#741 — `ROADMAP.md` header + Phase-2/3 bullets re-anchored to TCA.** L6 header switched from `MVVM + Screen Time APIs` to `TCA (ComposableArchitecture) + Screen Time APIs`; M2.3b Smart Pause bullet rewritten as `SchedulingFeature` → `screenTimeTrackerClient.pauseAll/.resumeAll`; Phase-3 data-flow box `AppCoordinator.handleBreakNeeded()` replaced with `SchedulingFeature .thresholdReached → OverlayClient.show / NotificationClient.deliver`; Decision 1.1 + Final Status Summary updated to describe the post-migration architecture. Phase 0 / Phase 1 "shipped" milestone bullets retain their original MVVM-era wording as historical receipts.
- **#742 — `UX_FLOWS.md` flow diagrams re-anchored to TCA reducers.** §2.1 routing paragraph rewritten around `RootView` + `AppFeature.State.hasSeenOnboarding`; §2.6 Shield-vs-fallback flow box and overlay-suppression contract re-anchored to `SchedulingFeature` + `OverlayClient` / `NotificationClient`; §6.7 snooze cascade re-attributed to `SettingsFeature.snoozeTapped` / `SchedulingFeature` snoozedUntilStream observer (cancel-all pipeline, `internalAction(.scheduleSnoozeWake)`); §6.7 snooze-wake handler attributed to `SchedulingFeature.snoozeWakeFired`; "Cancel snooze" path attributed to `SettingsFeature.cancelSnooze`.

#### #462 Phase A — Dependency-injection seams across services
A long mechanical pass replacing every implicit global / singleton lookup in
`AppCoordinator`, `AppDelegate`, `ReminderScheduler`, `OverlayManager`,
`SettingsStore`, `SettingsViewModel`, `ScreenTimeTracker`, `MetricKit`
plumbing, `LiveCarPlayDetector`, `LiveFocusStatusDetector`,
`LiveDrivingActivityDetector`, `OnboardingView`, `HomeView`, and
`AppGroupIPCStore` with constructor-injected protocol-conforming factory
seams (date providers, notification centers, audio sessions, app-state
providers, calendar, launch-arg / process-env providers, lifecycle / scene
seams, UI-test mode resolvers, exception handler installer, etc.). Required
to make the TCA Phase-1 reducers testable in isolation.

- **PRs #506–#591** (Phase A range) — see `git log --grep '#462 Phase A'` for
  the per-seam diff. Touches no production behaviour; every callsite
  preserves the prior default via `init` defaults.
- Notable callouts:
  - **#535** Inject `NotificationCenter` into `OverlayManager`.
  - **#534** `LiveCarPlayDetector` notification seam.
  - **#533** `ScreenTimeTracker` lifecycle notification-center seam.
  - **#591** `AppDelegate` optional notification factory seam (capstone PR).
- **#560 / #559 / #557 / #556 / #553 / #552 / #551 / #549 / #548 / #547 / #545 / #544 / #543 / #542 / #541 / #540 / #539 / #538 / #537 / #536 / #532 / #531 / #530 / #529 / #528 / #527 / #526 / #525 / #524 / #523 / #522 / #521 / #520 / #519 / #518 / #517 / #516 / #515 / #514 / #513 / #512 / #511 / #510 / #509 / #508 / #507 / #506** — companion DI seams across `AppCoordinator`, `AppDelegate`, `MetricKit`, `OverlayManager`, `ReminderScheduler`, `SelectedAppsState`, `SettingsViewModel`, `SettingsStore`, `ShieldSession`, `ScreenTimeTracker`. Same shape (factory injection with safe default), no runtime delta.

### ✨ New

- **#625 — Empty-state on Home:** when no reminder type is enabled, Home
  surfaces an explicit "no active reminders" placeholder instead of an empty
  list region.
- **#505 / #632 — Hosted privacy-policy link in Settings,** routed through
  the canonical hosted URL added in #185 (sync logic in #686).
- **#629 — Branded App Store support URLs.**
- **#633 — App Store screenshot set captured** under
  `docs/marketing/screenshots/`.
- **#631 — v1 launch release notes** (App Store Connect "What's New" copy).
- **#634 — Legal contact routed through the hosted support page.**

### 🐛 Fixed

- **#415 — App Group container mismatch + App Store SKU** corrected so the
  shared defaults round-trip between main app and ScreenTime extension.
- **#413 — Focus-status distribution entitlement** corrected (signed builds
  now ship with the entitlement embedded).
- **#502 — Remove fixed `sleep`s from `ScreenTimeTrackerTests`** (replaced
  with `awaitCondition`).
- **#463 — Stabilise fallback-notification test synchronisation.**
- **PRs #472–#489 (range)** — CI reliability, accessibility, `onChange`
  deprecation cleanup, and assorted service-layer bug fixes (single
  consolidated commit `41dc663`).
- **PRs #490–#496 (range)** — Phase B audit fixes for services, CI, and UI
  shards (single consolidated commit `dabba48`).
- **#414 / #469 — Trim UI-test wait budgets** in Settings and Overlay
  suites; gives flakier shards more headroom while shortening green-path
  wait time.
- **#461 — Simulator launch bundle ID + Nunito font-weight warnings.**
- **#427 — Settings pickers: `accessibilityIdentifier` for VoiceOver
  navigation:** `ReminderRowView` now sets
  `.accessibilityIdentifier("settings.{type}.intervalPicker")` and
  `.accessibilityIdentifier("settings.{type}.durationPicker")` on both
  reminder-type `Picker` rows so VoiceOver can navigate directly to them and
  UI tests can assert their presence.
- **#428 — Decorative SF Symbol images: explicit accessibility attributes:**
  `IconContainer`'s internal image now carries `.accessibilityHidden(true)`
  (container is always decorative; sibling `Text` or parent label supplies
  meaning). The overlay dismiss-button `Image` is also marked hidden — the
  `Button` itself has the correct
  `.accessibilityLabel`/`.accessibilityHint`/`.accessibilityIdentifier`.

### 🧪 Tests

- **#736 (phase 1) — Retire `DarkModeUITests.swift`.** The seven cases only
  asserted accessibility identifiers (which are color-scheme-independent and
  already covered by light-mode `HomeScreenTests` / `OverlayTests` /
  `OnboardingFlowTests` / `SettingsFlowTests`) — no actual dark-mode rendering
  / color / contrast assertions. Drops the `darkMode:` parameter from the
  `launchWith*` helpers in `UITestHelpers.swift` (sole caller deleted), the
  `appleInterfaceStyle` / `darkAppearance` constants, the `darkmode` shard
  from the disabled `uitest-shard` CI matrix, and the `DarkModeUITests`
  entries in `ARCHITECTURE.md` + `Tests/EyePostureReminderUITests/README.md`.
  The remaining four UI test files are tracked for individual port/retain/delete
  decisions under #736.
- **#708 — `OverlayFeature` behavioural-parity TestStore coverage**
  (`p0-tca-16` Phase 3 of TCA migration).
- **#704 — Phase-3 TestStore expansion** for #679 (`HomeFeature`), #681
  (`SettingsFeature`), and #682 (`OnboardingFeature`).
- **#713 — Bump `awaitCondition` timeout in `trueInterrupt` fallback test.**
- **#706 / #705 / #707 — CI fixes:** actor-isolation cleanup, plus
  `--reset-onboarding` launch arg so onboarding-aware tests can re-enter the
  flow deterministically.
- **#626 — Report UI-test retry failures** as workflow artifacts so flakes
  are diagnosable from CI without local repro.
- **#470 — Single overlay-ready anchor** to reduce wait/flake in Overlay
  shards.
- **#468 — Stabilise Settings UI tests + harden CI coverage parsing.**
- **#501 — Shard-deterministic UI sync + callback isolation follow-ups.**

### 🛠 Internal / CI / Style

- **#745 — Purge SDK-bound `ModuleCache.noindex` / `SDKStatCaches.noindex`
  before each CI build.** The cached `DerivedData` restored across runs
  contained precompiled `SwiftShims-*.pcm` files that recorded an SDK
  `module.modulemap` mtime which drifts between macos-15 runner refreshes,
  causing `xcodebuild` to fail with `error: file '.../SwiftShims-*.pcm'
  has been modified since the module file '...' was built: mtime changed`
  and `exit 65` *before* tests ran (no `TestResults.xcresult` produced).
  Wiping just those two SDK-bound subdirectories preserves the much larger
  `Build/` intermediates for incremental reuse while removing the false
  failure surface that was being mis-attributed to source-compile bugs in
  #746 / #747.
- **#663 — Integrate SwiftLint into CI** per Google Swift Style.
- **#685 — Line-wrap pass** in Views to comply with the 100-char column
  limit (closes #650).
- **#660 — Audit & document IUO usage** per Google Swift Style §Optional
  Types (closes #648).
- **#657 — Google-format doc comments** on public Services + `ReminderRowView` (closes #649).
- **#656 — Tighten access control** per Google Swift Style §Access Levels
  (closes #652).
- **#655 — Fix import ordering** per Google Swift Style §Import Statements.
- **#653 — Coding-standards audit** sweep.
- **#503 — Align Xcode version + harden TestFlight selection** in CI.
- **#418 / #429 — Harden extension signing validation** + clean up
  TestFlight signing temp assets.
- **#460 — Consolidate audit-wave fixes** into `main` (rollup).
- **#411 — Audit cleanup and readiness fixes** (rollup).

### 📚 Docs / Legal

- **#686 — Sync hosted privacy page** with canonical `docs/legal/PRIVACY.md`.
- **#641 — Privacy-policy follow-on edits** (canonical text).
- **#642 / #661 — Add private privacy / legal contact path.**
- **#643 / #659 — Notification-permission tracker correction.**
- **#640 / #658 — App Store screenshot count / dimensions validation.**
- **#628 — Keep IPC slot keys private in logs.**
- **#627 — Hide saved-banner icon from VoiceOver.**
- **#630 — Disclose Focus and CarPlay privacy access** in
  `PRIVACY_NUTRITION_LABELS.md`.
- **#635 — Harden extension privacy-archive checks.**
- **#645 — App Store version guard for signed uploads.**
- **#654 — Validate main-app privacy manifest in signed archives.**
- **#198 — Legal placeholders, TestFlight signing cleanup, True Interrupt
  Mode docs.**
- **#194 — TestFlight readiness:** config, accessibility, docs (v0.2.0
  follow-up).
- **#209 / #417 — Compliance checklist** for Screen Time APIs (legal review
  artefact, since superseded by canonical docs and untracked in #720).
- **#358 / #416 — `DISCLAIMER.md` placeholder cleanup.**
- **#344 / #364 — UITestHelpers doc comment cleanup.**

### 📋 Meta

- **1,801 unit tests** locally on `main` (was 1,382 at v0.2.0; +419 net
  driven mostly by Phase-3 TestStore coverage and the DI-seam test fanout,
  net of MVVM-era suite removals during the TCA migration). Live grep:
  `grep -rc 'func test' Tests/EyePostureReminderTests --include='*.swift'`;
  1,758 executed under `./scripts/build.sh all` (2 intentionally `XCTSkip`-gated
  — `SchedulingFeature_WatchdogRecoveryTests.test_watchdogRecovery_deferredToPhase2`
  and `SettingsStoreSeedTests.test_uiTestOverlayBreakDuration`). Mirrors
  `docs/TEST_REPORT.md` L7 / L15 / L225 (authoritative).
- **Post-`v0.2.0` PR stream** — run `git log v0.2.0..main --first-parent` for the
  full ledger; this section groups the contributor-visible delta. (The literal
  cumulative count was removed in #885 — it drifted by exactly +1 on every
  merge and burnt one dedicated follow-up PR each time; #881–#884 are the
  evidence.)
- **Phase 3 of the TCA migration is in flight** (per-feature `TestStore`
  coverage). The MVVM decommission tracked in #677 and #702 has landed —
  PR #754 deleted the `SelectedAppsState` wrapper (#678 final) and PR #760
  deleted the `AppCoordinator` stack (#755 Phase E); the follow-up
  doc/citation sweep continues in the `#767+` series (run
  `git log --grep='Closes #' v0.2.0..main --oneline` for the live list).

---

## v0.2.0 — Restful Grove (2026-04-27)

The **Restful Grove** release transforms kshana's visual identity and hardens every layer of the app through seven dedicated quality passes.

### ✨ New
- **Restful Grove visual identity:** new Sage (#2F6F5E) + Mint (#EEF6F1) color palette with 10 `RG*` semantic color tokens in Asset Catalog (RGPrimaryRest, RGSecondaryCalm, RGAccentWarm, RGSurface, RGSurfaceTint, RGBackground, RGTextPrimary, RGTextSecondary, RGSeparatorSoft, RGShadowCard)
- **Yin-yang logo animation:** custom SwiftUI `Path` symbol with spin (360°, 2s deceleration) → breathing pulse (4s in/out, infinite); Reduce Motion fallback shows static logo
- **App renamed to kshana** (Sanskrit: क्षण, "a moment, an instant") — all 17 documentation files updated; SPM target remains `EyePostureReminder`
- **`AccessibleToggle.swift`:** reusable accessible toggle component
- **`Components.swift`:** shared UI component library
- **`AppStorageKeys.swift`:** centralized `@AppStorage` key constants
- **`PrivacyInfo.xcprivacy`:** Apple privacy manifest for App Store submission

### 🛠 Improved
- **7 quality passes** (Loops 1–7): core service reliability, UI & accessibility polish, localization & onboarding, analytics & MetricKit, test coverage expansion, CI hardening, completeness sweep
- **Smart Pause cold-start fix:** `PauseConditionManager` re-evaluates conditions on cold start to avoid stuck-pause state
- **CI hardening:** `xcodebuild` timeout cap (25 min), dSYM archiving, coverage thresholds, SwiftLint version pinned, nightly cron job, `CODE_SIGNING_ALLOWED=NO` archive flags
- **Swift 6 concurrency compliance:** `ReminderType`, `ReminderSettings` marked `Sendable`; removed `@unchecked Sendable` workarounds; `@MainActor` isolation fixes
- **Analytics privacy:** two-tier annotation (`.public` for categorical labels, `.private` for user values)
- **`ServiceLifecycle` protocol:** uniform `start()` / `stop()` interface across all services
- **Comprehensive UI/UX text audit:** notification copy, VoiceOver hints, String Catalog consistency
- **WCAG AA contrast:** all text/background pairs verified at 4.5:1; `WarningOrange`/`WarningText` tokens adjusted
- **Tap targets:** all interactive controls verified ≥ 44 × 44 pt

### 🐛 Fixed
- **Overlay double-present guard:** `isDismissing` state prevents duplicate dismiss callbacks
- **Snooze wake reliability:** dual wake mechanism (in-process `Task` + silent notification); stale `snoozedUntil` cleared on foreground
- **Dead color tokens removed:** six unused `AppColor` tokens deleted; `overlayBackground` replaced by `.ultraThinMaterial`
- **`slideOffset` reset** under Reduce Motion corrected
- **`StateObject` lifecycle:** `SettingsViewModel` promoted to `@StateObject` to prevent spurious re-inits
- **Snooze identifiers and dismiss binding** edge cases resolved
- **AppColor bundle resolution:** named colors now loaded from `.module` bundle correctly
- **Notification `repeats: false`** enforced explicitly
- **Overlay timer RunLoop mode** set to `.common` for reliable firing during gestures

### 📋 Meta
- **1,382 unit tests**, **53 UI tests**, **81%+ code coverage**
- 100+ commits across 13 team members
- Inclusive language: test names updated (`master` → `global`/`primary`)
- All legal docs (TERMS, PRIVACY, DISCLAIMER) rendered in-app via `LegalDocumentView`
- `PrivacyInfo.xcprivacy` added for App Store Connect compliance

---

## Rename — "Eye & Posture Reminder" → kshana

- App renamed to **kshana** (Sanskrit: क्षण, "a moment, an instant")
- All documentation updated to reflect new brand name
- SPM module/target remains `EyePostureReminder` (internal technical name)

---

## v0.1.0-beta — TestFlight Beta

### Phase 0: Foundation
- Swift Package Manager project scaffold (iOS 16+, SwiftUI, MVVM)
- CI/CD pipeline: GitHub Actions build, test, lint on `macos-14`
- Architecture established: Models → Services → ViewModels → Views
- Design system: `AppColor`, `AppFont`, `AppSpacing` tokens
- SwiftLint configuration (120-char line length, SwiftUI-friendly ruleset)
- `scripts/build.sh` unified build/test/lint/clean runner

### Phase 1: MVP
- **Settings:** Interval and break duration pickers, haptics toggle, persisted via `UserDefaults`
- **Notifications:** `UNUserNotificationCenter` scheduling with per-type debounce (300 ms)
- **Overlay:** Full-screen UIKit window overlay with countdown ring, swipe-up dismiss, auto-dismiss
- **Integration:** `AppCoordinator` wires services; background/foreground lifecycle management
- **Snooze:** 5 min / 1 hour / rest-of-day options with dual wake mechanism (in-process Task + silent notification); max 2 consecutive snoozes
- **Haptics:** `UIImpactFeedbackGenerator` on overlay appear/dismiss; `UINotificationFeedbackGenerator` on auto-complete
- **Accessibility:** Dynamic Type, Reduce Motion, VoiceOver countdown live region, `accessibilityViewIsModal`
- **Tests:** 65+ unit tests; 80 %+ coverage across Models, Services, ViewModels

### Phase 2: Polish
- **Onboarding:** 4-screen first-launch flow (Welcome → Notification Permission → Schedule Setup → True Interrupt Mode) with `hasSeenOnboarding` persistence
- **Smart Pause:** Automatic reminder pause via Focus Mode detection, CarPlay detection, and CMMotionActivityManager driving detection; `PauseConditionManager` aggregates all conditions
- **Screen-Time Triggers:** `ScreenTimeTracker` replaces wall-clock timers — reminders fire after continuous screen-on time only (M2.7)
- **Snooze UI:** `SnoozeOption` enum with 3 duration options (5m / 1h / rest-of-day), max 2 consecutive snoozes, formatted labels in OverlayView action sheet
- **Data-Driven Configuration:** Asset Catalog color tokens (ReminderBlue, ReminderGreen, WarningOrange, PermissionBanner, PermissionBannerText, WarningText), String Catalog (~35 strings), `defaults.json` seed values (M2.8)
- **Disclaimer UI & Legal Docs:** In-app `LegalDocumentView` rendering bundled TERMS.md, PRIVACY.md, DISCLAIMER.md (M2.4)
- **App Icon & Launch Screen:** Production app icon and branded launch screen (M2.5)
- **Analytics:** `AnalyticsLogger` structured event logging via `os.Logger` with two-tier privacy annotations (`.public` for categorical labels, `.private` for values)
- **MetricKit:** `MetricKitSubscriber` for passive OS-level crash/performance diagnostic payloads
- **ServiceLifecycle:** Uniform start/stop lifecycle protocol for all services
- **Haptics refinement:** Generator lifecycle with `.prepare()` in `onAppear` for instant response
- **Accessibility:** Dynamic Type, Reduce Motion, VoiceOver countdown live region with `accessibilityViewIsModal`; countdown ZStack split into static label + live `.accessibilityValue`
- **Localization:** String Catalog with ~35 user-facing strings; localization-ready
- **Design tokens:** `ReminderType.color` migrated to `AppColor` design system; all colors via Asset Catalog with dark/light variants
- **Bug fixes:** Overlay double-present guard, notification debounce (300 ms), snooze wake reliability (dual wake mechanism)

### Quality Loops 1–7 (post-Phase-2 fix passes)

These loops represent iterative quality passes applied after the main Phase 2 feature work, hardening analytics, MetricKit, accessibility, localization, test coverage, and CI infrastructure.

#### Loop 1 – Core Service Reliability
- **Session lifecycle:** `appSessionStart` emitted correctly in foreground; `AppCoordinator` start/stop ordering fixed
- **Sendable conformance:** `ReminderType`, `ReminderSettings` marked `Sendable`; removed `@unchecked Sendable` workarounds
- **Analytics wiring:** `snoozeExpired` event emitted from `handleForegroundTransition`; `snoozeCount` reset on new reminder cycle
- **Snooze-wake reliability:** Dual wake mechanism (in-process `Task` + silent notification); `snoozedUntil` stale state cleared on foreground
- **CarPlay cold-start:** `PauseConditionManager` re-evaluates conditions on cold start to avoid stuck-pause state

#### Loop 2 – UI & Accessibility Polish
- **WCAG contrast:** All text/background pairs verified at AA (4.5 : 1); `WarningOrange` and `WarningText` tokens adjusted
- **Snooze UX:** Action sheet options reordered; `SnoozeOption` formatted labels localised via String Catalog
- **Overlay animation:** `slideOffset` reset correctly under Reduce Motion; swipe-up dismiss gesture re-added
- **VoiceOver overlay:** `accessibilityViewIsModal = true` enforced; countdown split into static label + live `.accessibilityValue`; plural forms added (`%lld second` / `%lld seconds`)
- **StateObject lifecycle:** `SettingsViewModel` promoted to `@StateObject` in root view; eliminated spurious re-inits
- **Tap target enforcement:** All interactive controls verified ≥ 44 × 44 pt; time-format picker fixed for 24h locales

#### Loop 3 – Localization & Onboarding
- **String Catalog expansion:** ~35 user-facing strings migrated to `Localizable.xcstrings`; all keys follow `screen.component[.qualifier]` convention
- **Localised a11y strings:** VoiceOver hints and labels moved from hardcoded English to String Catalog
- **Onboarding permission view:** `NotificationScheduling` injected for testability; permission card uses catalog strings
- **Notification copy:** Body strings (`reminder.eyes.notificationBody`, `reminder.posture.notificationBody`) finalised; tautological VoiceOver hints removed
- **Design-token localization:** `onboarding.setup.card.label` positional format specifiers (`%1$@`, `%2$@`, `%3$@`) for correct word-order in all locales

#### Loop 4 – Analytics & MetricKit
- **`AnalyticsLogger`:** Structured event schema (`sessionStart`, `overlayShown`, `overlayDismissed`, `snoozed`, `snoozeExpired`, `reminderEnabled`, `reminderDisabled`) logged via `os.Logger`
- **Two-tier privacy:** Categorical labels (`.public`), user-controlled values (`.private`); `old_value`/`new_value` marked `.private`
- **`MetricKitSubscriber`:** Registered at app launch for passive OS-level crash + performance payloads; `MXMetricPayload` and `MXDiagnosticPayload` routed to `os.Logger`
- **`ServiceLifecycle` protocol:** Uniform `start()` / `stop()` interface implemented by `ReminderScheduler`, `OverlayManager`, `PauseConditionManager`, `ScreenTimeTracker`, `MetricKitSubscriber`

#### Loop 5 – Test Coverage
- **Services layer:** `AnalyticsLoggerTests`, `MetricKitSubscriberTests`, `AudioInterruptionManagerTests`, `PauseConditionManagerTests` added (65+ tests total)
- **String Catalog tests:** `StringCatalogTests` expanded to cover all ~35 catalog keys; format-specifier syntactic validation added
- **QA gate tests:** Silent notification path and stale `snoozedUntil` clearing verified by dedicated regression tests
- **Integration tests:** `MultiServicePipelineIntegrationTests` covers `AppCoordinator` ↔ scheduler ↔ overlay full pipeline
- **`repeats: false` coverage:** Notification request non-repeating behaviour asserted explicitly

#### Loop 6 – CI Hardening
- **Timeouts:** `xcodebuild` step capped at 25 min; overall job timeout 40 min
- **dSYM archiving:** `DWARF_DSYM_FOLDER_PATH` captured as CI artefact for crash symbolication
- **Coverage thresholds:** Code-coverage report extracted; build fails below baseline
- **SwiftLint pin:** Version pinned in CI to prevent rule-set drift between local and CI runs
- **`cron` schedule:** Nightly CI run added to catch regressions from Xcode toolchain updates
- **Archive flags:** `CODE_SIGNING_ALLOWED=NO` and `SKIP_INSTALL=NO` set for archive step

#### Loop 7 – Quality Pass & Completeness
- **Legal completeness:** `LegalDocumentView` verified to render TERMS.md, PRIVACY.md, DISCLAIMER.md from bundle; all `legal.*` catalog keys present and tested
- **Dead-token removal:** Six unused `AppColor` tokens deleted; `overlayBackground` usage replaced by `.ultraThinMaterial`
- **Reset-to-defaults a11y:** `settings.resetToDefaults.hint` VoiceOver pre-action hint added; destructive confirmation dialog titles and labels fully localized
- **Inclusive language:** Test method and variable names updated to use `global` / `primary` instead of `master`
- **Docs drift resolution:** `ARCHITECTURE.md`, `CHANGELOG.md`, and `IMPLEMENTATION_PLAN.md` synchronised to implementation; dead `ReminderScheduler` methods documented or removed
- **SwiftLint zero violations:** All 120-char line-length and closure-syntax violations resolved; `// swiftlint:disable` directives minimised and scoped

---

*Build numbers are assigned automatically by CI (`github.run_number`).*  
*Commit hash embedded as `EPRCommitHash` in Info.plist for traceability.*

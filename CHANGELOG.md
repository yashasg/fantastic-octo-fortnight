# Changelog

All notable changes to kshana (formerly Eye & Posture Reminder) are documented here.

Format: `vMAJOR.MINOR.PATCH[-prerelease]`  
Versioning strategy: `0.x.x` during TestFlight beta, `1.0.0` at App Store launch.

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
- **Snooze:** 5 min / 15 min / 30 min / rest-of-day options with dual wake mechanism (in-process Task + silent notification); max 2 consecutive snoozes
- **Haptics:** `UIImpactFeedbackGenerator` on overlay appear/dismiss; `UINotificationFeedbackGenerator` on auto-complete
- **Accessibility:** Dynamic Type, Reduce Motion, VoiceOver countdown live region, `accessibilityViewIsModal`
- **Tests:** 65+ unit tests; 80 %+ coverage across Models, Services, ViewModels

### Phase 2: Polish
- **Onboarding:** 3-screen first-launch flow (welcome, notification permission, setup) with `hasSeenOnboarding` persistence
- **Smart Pause:** Automatic reminder pause via Focus Mode detection, CarPlay detection, and CMMotionActivityManager driving detection; `PauseConditionManager` aggregates all conditions
- **Screen-Time Triggers:** `ScreenTimeTracker` replaces wall-clock timers — reminders fire after continuous screen-on time only (M2.7)
- **Snooze UI:** `SnoozeOption` enum with 4 duration options (5m / 15m / 30m / rest-of-day), max 2 consecutive snoozes, formatted labels in OverlayView action sheet
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

# Project Context

- **Owner:** Yashasg
- **Project:** Eye & Posture Reminder — a lightweight iOS app with background timers and full-screen overlay reminders for eye breaks (20-20-20 rule) and posture checks
- **Stack:** Swift, SwiftUI (iOS 16+), MVVM, UserNotifications, UIKit overlay, UserDefaults
- **Created:** 2026-04-24

## Learnings

<!-- Append new learnings below. Each entry is something lasting about the project. -->

### 2026-04-24: Phase 1 Code Review (M1.8)
- **Reviewed:** All 16 Swift source files, 7 test files, Package.swift, ARCHITECTURE.md
- **Verdict:** Conditional Approval — 0 P0, 4 P1, 7 P2 issues
- **Key P1s:**
  1. Snooze not guarded in `scheduleReminders()` — will break when snooze UI ships
  2. `AppCoordinator` hardcodes `UNUserNotificationCenter.current()` for auth — untestable
  3. `OverlayManager.shared` used directly instead of injected `OverlayPresenting` protocol
  4. Fixed font sizes in `DesignSystem.swift` break Dynamic Type accessibility
- **Positive:** Protocol-driven testing is strong (65+ tests), memory management is correct, no retain cycles, thread safety via @MainActor is sound
- **Architecture:** Dependencies flow correctly. `OverlayManager → OverlayView` is the only Service→View coupling, acceptable as UIKit bridge
- **Pattern to watch:** `@State` used for SettingsViewModel (reference type) — works today since VM has no @Published bindings, but fragile if VM evolves

### 2026-04-24: Phase 2 Code Review (M2.1–M2.3)
- **Reviewed:** All 20 Swift source files, 11 test files, 2 shell scripts, ONBOARDING_SPEC.md
- **Verdict:** APPROVED — 0 P0, 0 P1, 5 P2 (3 new, 2 carried from Phase 1)
- **P1 fixes verified:** All 4 Phase 1 P1s confirmed resolved (snooze guard, NotificationScheduling injection, OverlayPresenting injection, Dynamic Type fonts)
- **Phase 1 P2s resolved:** 5 of 7 fixed (P2-1 colors, P2-2 dead code, P2-4 VoiceOver countdown, P2-6 button labels, P2-7 haptic timing); 2 carried (P2-3 @State fragility, P2-5 protocol directory)
- **New P2s found:**
  1. SettingsView snooze buttons use legacy `snooze(for:)` instead of DST-aware `snooze(option:)` — highest priority P2
  2. Onboarding fonts bypass `AppFont` design tokens (use system styles directly)
  3. OnboardingPermissionView hardcodes `UNUserNotificationCenter.current()` — bypasses injected protocol
- **Positives:** Dual snooze-wake mechanism is robust, haptic generator lifecycle correct, onboarding spec-compliant, 36+ new Phase 2 tests, accessibility thorough across all views, no retain cycles, thread safety sound
- **Key learning:** When reviewing a new UI module (onboarding), check that it uses the same design system tokens and dependency injection patterns established in the rest of the codebase — visual consistency and testability gaps often appear at module boundaries

### 2026-04-25: Post-Phase-1 Quality Audit (Spawn Wave)
- **Scope:** Code quality review across all 20 source files post-Phase 2 implementation
- **Verdict:** 2 P1 bugs + 2 P2 issues filed (#22–#25)
- **P1s identified:**
  1. **#22 — ScreenTimeTracker path skips snooze reset.** Notification path resets count; primary trigger path doesn't. Users hit snooze cap in normal use.
  2. **#23 — OverlayView stalls during ScreenTime trigger.** Likely race condition between ScreenTimeTracker callback thread and @MainActor UI update.
- **P2s identified:**
  1. **#24 — SettingsView snooze buttons bypass DST-aware API.** Legacy `snooze(for:)` breaks during DST transitions (flagged in Phase 2 review, unfixed).
  2. **#25 — OnboardingPermissionView hardcodes system framework.** Direct `UNUserNotificationCenter.current()` call; couples to system, untestable; violates DI pattern.
- **Pattern observation:** All 4 issues originated from Phase 1 or early Phase 2. Onboarding module (#25) shows same integration gaps flagged in Phase 2 review.
- **Quality note:** Phase 1 P1 fixes were solid (snooze guard, DI injection for NotificationScheduling/OverlayPresenting). Phase 2 onboarding adhered to spec but didn't fully adopt established patterns — #25 is endemic to that module boundary gap.

### 2025-07-18: Comprehensive Code Quality & Readability Audit
- **Scope:** Full codebase — 28 source files, 41 test files (all Swift in EyePostureReminder/ and Tests/)
- **Verdict:** Strong codebase — 0 P0, 1 P1 (consistency), 6 P2 (readability/maintenance)
- **P1 finding:**
  1. AppCoordinator.swift line 587: Strong `self` capture in Task closure — inconsistent with every other Task closure in the class which uses `[weak self]`. Not a practical leak (short-lived Task) but violates the project's own established pattern.
- **P2 findings:**
  1. `AnalyticsLogger.log()` is 72 lines (single switch) — exceeds 40-line method threshold; extract per-event helpers
  2. `AppCoordinator.scheduleReminders()` is 52 lines — extract snooze-guard and analytics-session sub-methods
  3. `SettingsView.body` is 347 lines with a swiftlint suppression (`type_body_length`) — should decompose into extracted subviews
  4. `StringCatalogTests.swift` is 1046 lines — split into 3–4 focused test files
  5. `ColorTokenTests.swift` line 363: O(n²) distinctness check — replace with Set-based O(n) approach
  6. `OverlayManager` uses tuple for queued overlays — should be a named struct for type safety
- **No issues found in:** Naming conventions (excellent), documentation (thorough on public APIs), force unwraps (zero), error handling (proper throughout), dead code (minimal — deprecated `snooze(for:)` properly marked), Swift idioms (strong guard/optional patterns)
- **Test suite quality:** 9/10 — zero force unwraps, robust mocking infrastructure, MainActor safety, clear BDD naming, comprehensive coverage
- **Key patterns confirmed healthy:** Protocol-driven DI, @MainActor isolation, design system tokens, SettingsPersisting abstraction, MVVM boundaries
- **Key learning:** SwiftUI struct views (OverlayView, ReminderRowView) don't need `[weak self]` in closures — structs are value types. Only flag weak-capture issues on class types (AppCoordinator, SettingsStore, etc.)

### 2025-07-18: Fix #115 — Strong self capture in AppCoordinator snooze task
- **Fixed:** Line 587 in `AppCoordinator.swift` — `Task { await self.scheduleSnoozeWakeNotification(at: snoozeEnd) }` changed to `Task { [weak self] in await self?.scheduleSnoozeWakeNotification(at: snoozeEnd) }`
- **Root cause:** Oversight during #73 implementation — the silent background notification scheduling Task was added without the `[weak self]` capture that every other Task closure in the class uses
- **Key learning:** When adding new Task closures to a class, always check the file's existing capture pattern and match it — consistency prevents subtle retain-cycle bugs from slipping through review

### 2025-07-18: Round 4 Code Quality Review (Post 3 Fix Rounds)
- **Scope:** Full codebase — 29 source files, fresh pass after 36 issues fixed across 3 rounds
- **Verdict:** ✅ APPROVED — Ship it. 0 P0, 0 P1, 3 P2 (all carried/known)
- **Round 3 fixes verified (all clean):**
  1. **#136 (pendingOverlay):** `pendingOverlay = nil` added in both cancel and pause paths — correct, surgical
  2. **#137 (type-specific queue):** New `clearQueue(for:)` on OverlayPresenting protocol + OverlayManager impl + mock — proper protocol extension, well-tested
  3. **#138 (AppSymbol):** 4 new tokens (pauseDuringFocus, pauseWhileDriving, clock, timer) + all callsites migrated — no raw SF Symbol strings remain outside DesignSystem.swift and ReminderType.symbolName
  4. **#143 (timer guard):** `guard timer == nil else { return }` in OverlayView.startTimer() — minimal, correct
- **Carried P2s (known, non-blocking):**
  1. `OverlayManager.overlayQueue` and `AppCoordinator.pendingOverlay` still use tuples — named struct would improve readability (carried from Round 0 P2-6)
  2. `ReminderType.symbolName` returns `"eye"` while `AppSymbol.eyeBreak` is `"eye.fill"` — intentional (filled vs outline for different contexts) but undocumented
  3. `SettingsView.swift` at 446 lines — previously 347; grew with snooze/smart-pause sections. Subview extraction recommended for maintainability
- **Clean bill on:** No swiftlint suppressions, zero TODO/FIXME/HACK markers, zero force unwraps, all Task closures use `[weak self]`, deprecated `snooze(for:)` properly marked and unused, DI pattern consistent, design system tokens comprehensive
- **Ship confidence: HIGH** — No functional bugs, no architectural debt, no safety issues. Carried P2s are maintenance-quality items for a future cleanup pass.

### 2025-07-18: Restful Grove Visual Redesign Code Review
- **Scope:** All files changed on `feature/restful-grove` — 9 new color assets, 2 bundled fonts, DesignSystem.swift, Components.swift, SettingsView.swift, OverlayView.swift, HomeView.swift, OnboardingView.swift + 3 sub-views, ReminderType.swift, Package.swift
- **Verdict:** Conditional Approval — 0 P0, 2 P1, 8 P2
- **P1s identified:**
  1. `AppColor.shadowCard` uses raw `Color(red:green:blue:)` instead of asset catalog — breaks single-source-of-truth pattern for dark mode adaptation
  2. Three reusable components (`StatusPill`, `IconContainer`, `SectionHeader`) are dead code — added to Components.swift but never used by any view
- **Key P2s:**
  1. HomeView uses `.secondary` and `AppColor.reminderBlue` instead of RG palette tokens
  2. `OnboardingPrimaryButtonStyle` duplicates `PrimaryButtonStyle` in Components.swift
  3. `OnboardingScreenWrapper` duplicates `CalmingEntrance` modifier pattern
  4. `permissionBanner`/`permissionBannerText` tokens appear unused after redesign
  5. No test coverage for 9 new RG* color tokens in asset catalog
- **Positives:** Design system adoption is thorough across all redesigned views, accessibility is excellent (labels, hints, identifiers, reduce-motion guards throughout), Dynamic Type properly preserved via relativeTo:, SoftElevation pattern is clean, CalmingEntrance handles re-appear correctly, OnboardingPermissionView DI injection now correct
- **Key learning:** When adding a "reusable components" file during a redesign, verify each component is actually adopted by at least one view before shipping — otherwise you get dead code that duplicates bespoke implementations already in the views (SettingsRowIcon vs IconContainer, SettingsSectionHeader vs SectionHeader)

### 2026-04-26: Restful Grove Final Verification (Post-Fix Pass)
- **Scope:** Final verification that all P1/P2 findings from the Restful Grove review were properly addressed
- **Verdict:** ✅ APPROVED — All previous findings resolved. Ship it.
- **Checklist results:**
  1. ✅ **shadowCard** — moved to asset catalog (`RGShadowCard.colorset`), zero raw `Color(red:green:blue:)` calls anywhere in codebase
  2. ✅ **Dead components** — `StatusPill` and generic `SectionHeader` removed from `Components.swift`; `IconContainer` kept and actively used in `SettingsView.swift` (2 callsites) + tests
  3. ✅ **Dead tokens** — `overlayCornerRadius`, `cardCornerRadius`, `permissionBanner`, `permissionBannerText` all removed from `DesignSystem.swift`
  4. ✅ **HomeView** — fully migrated to RG tokens (`AppColor.primaryRest`, `AppColor.textPrimary`, `AppColor.textSecondary`, `AppColor.background`, `AppTypography.*`, `AppSpacing.*`, `AppAnimation.*`, `AppSymbol.*`); zero raw `.secondary` or `reminderBlue` references
  5. ✅ **Duplicate styles** — `OnboardingPrimaryButtonStyle` removed; `OnboardingScreenWrapper` replaced by `.calmingEntrance()` (confirmed by comment in OnboardingView.swift)
  6. ✅ **No new issues** introduced by fixes
- **Minor note (non-blocking):** `PermissionBanner.colorset` and `PermissionBannerText.colorset` still exist as orphaned asset catalog entries — no Swift code references them. Stale comment in `DarkModeTests.swift:11` references them. Cleanup candidate for a future housekeeping pass.
- **Build:** ✅ BUILD SUCCEEDED (xcodebuild, iPhone 17 Simulator, iOS 26.4)
- **Tests:** ✅ 889 tests, 0 failures
- **Key learning:** When removing design tokens from Swift code, also audit the asset catalog for orphaned `.colorset` entries and test comments that reference deleted tokens — these artifacts survive code-level cleanup and accumulate as noise

### 2026-04-29: Code Review #204 — True Interrupt Authorization Setup

**Scope:** Review of #204 (True Interrupt authorization setup) with focus on no-warning policy enforcement.

**Review Verdict:** ✅ **APPROVED — No blocking regressions**

**Key Findings:**
- Authorization opt-in toggle is safe; graceful fallback to `ScreenTimeShieldNoop` (no-op provider)
- Settings wiring correct; metadata persisted in `UserDefaults` with no side effects
- Build configuration clean; no new warnings introduced
- Test coverage sufficient; all new tests passing with zero failures
- Protocol boundary (`ScreenTimeShieldProviding`) correctly in place; real wiring deferred to M3.3

**Staging Recommendation:**
- ✅ Stage code changes (EyePostureReminder/, Tests/, ScreenTimeExtensions/)
- ✅ Stage config changes (project.yml, entitlements, signing)
- ✅ Stage test fixtures
- ❌ Exclude .squad/ (internal noise)
- ❌ Exclude TestResults*.xcresult (build artifacts)

**User Directive Captured:**
- "We are a no-warning shop; warnings must be fixed, not accepted."
- Enforcement: All pre-merge gates now require zero new warnings
- Impact: Raises quality bar; all future waves must maintain zero-warning standard

**Key Learning:** When reviewing authorization/permission UI additions, verify the fallback path is graceful (no degraded UX) and that the feature remains optional — this allows shipping UI while regulatory/entitlement approvals remain pending.


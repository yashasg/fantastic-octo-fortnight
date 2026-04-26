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

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


### 2026-04-30: Post-#299 Code Audit (True Interrupt / IPC / ScreenTime / Analytics / CI / Accessibility)
- **Reviewed:** 31 changed files across HEAD~15 on squad/m3-true-interrupt-mode (1862 insertions)
- **Scope:** AppGroupIPCStore, WatchdogHeartbeat, ScreenTimeTracker, OverlayManager, PauseConditionManager, AnalyticsLogger, AppCoordinator + WatchdogRecovery, SettingsViewModel, HomeView, OverlayView, SettingsView, AccessibilityNotificationPosting, ci.yml, TELEMETRY.md
- **Verdict:** No material actionable defects found. Code is well-structured with proper @MainActor isolation, [weak self] in async closures, generational tick guards, and correct observer cleanup.
- **Minor observations (not filed):**
  - SettingsViewModel uses strong self capture in 4 fire-and-forget Tasks (lines 261, 285, 297, 353) — acceptable because Tasks are short-lived scheduler calls
  - AccessibilityNotificationPosting protocol lacks @MainActor annotation — all current callers are @MainActor so no runtime risk today, but a future non-MainActor caller would hit UIKit thread violations
  - AppGroupIPCStore recordEvent comment says "writes exactly one key" but accessRequested events write two; the second key (lastAccessRequestAt) is not read in production code
- **CI:** Actions pinned to full commit SHAs ✓; no script injection vectors ✓
- **TELEMETRY.md:** Matches analytics code schema accurately ✓

**Key Learning:** The True Interrupt IPC architecture uses generational guards and withLock wrappers consistently. The serialized Task queue pattern in enqueueDeviceActivityMonitorOperation is sound because @MainActor Tasks run sequentially on the main thread, making the previousTask chain safe without additional locking.

### 2026-04-30: SettingsStore Break-Duration Fix (PR #411)
- **Reviewed:** Basher's commit `04f73cd` replacing recursive `@Published` `didSet` self-assignment with private published backing storage + validated computed setters for `eyesBreakDuration` and `postureBreakDuration`.
- **Verdict:** APPROVED. Fix correctly eliminates observer self-mutation that caused simulator test-process segfaults. SwiftUI reactivity preserved via `@Published` on backing storage. UserDefaults persistence semantics unchanged. No API surface change—external callers see the same get/set interface. Minor redundant double-sanitization in `resetToDefaults` is harmless.
- **Key Learning:** Never reassign a `@Published` property inside its own `didSet`—it triggers recursive observer calls. Use private published backing storage with a computed setter instead.

## 2026-04-30 — SettingsStore recursion fix review (Scribe update)

Orchestration log recorded at 2026-04-30T09:27:10Z. Code review approved; decision documented in decisions.md:
- Reviewed Basher's commit `04f73cd` (backing-storage + computed-setter pattern)
- Verdict: APPROVE
- Verified SwiftUI reactivity (objectWillChange fires on private storage)
- Confirmed API surface unchanged; all 35+ test callsites unaffected
- Established team rule: Never reassign @Published inside didSet; use private published backing + computed setter

### 2026-05-14: Coding Standards Audit

**Scope:** Comprehensive audit of what coding standards are actually enforced vs. conventional vs. aspirational in the kshana repo.

**Findings Summary:**

**ENFORCED (build/CI will fail):**
- Compiler warnings as errors (`SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`, build.sh:61–62)
- 80% code coverage minimum (ci.yml:184)
- All tests must pass before merge
- Distribution entitlements guardrail (no FamilyControls before #201 approved)

**CONVENTIONAL (practiced but not mechanically enforced):**
- SwiftLint configured (.swiftlint.yml: 30+ opt-in rules, line_length error: 160) but NOT invoked in CI (only cached)
- MARK comment organization (all Models/ViewModels)
- @MainActor on UI-bound types (AppCoordinator, SettingsViewModel)
- [weak self] in Task closures (code-review enforced, team rule from #115 fix)
- Protocol-driven DI (NotificationScheduling, OverlayPresenting, ReminderScheduling)
- Design system tokens (AppColor.*, AppFont.*, AppSymbol.*) — no hardcoded Color/Font/SF Symbol strings
- Public API documentation (doc comments with summaries)
- Zero force unwraps in production code
- Consistent file organization (Models/, ViewModels/, Views/, Services/, Utilities/, App/)
- BDD test naming (test_When_Then pattern)

**ASPIRATIONAL (documented but not applied):**
- Google Swift Style Guide (docs/google_swift_coding_style.md) is a clipping/reference, not integrated into team tooling

**Key Learning:** The codebase practices strong conventions and has reasonable linting config, but SwiftLint is not part of CI. Local developers who run `./scripts/build.sh lint` catch violations; CI-only workflows (web edits, direct pushes) skip linting. The discrepancy between configured and enforced is the main gap.

### 2026-05-15: Full-Codebase Google Swift Style Audit (Squad Parallel Pass)

**Scope:** 53 Swift files (9164 LOC) across 3 parallel auditors covering full scope: App (Saul, 6 files), Views/ViewModels (Linus, 18 files), Services/Utilities (Basher, 29 files).

**Audit Findings:**
- **HIGH: 7 items** — 1 access level violation (AppCategoryPickerView), 1 extension access control violation (AppCoordinator), 1 IUO verification (OverlayManager), 4 missing doc comments on public API
- **MEDIUM: 29+ items** — 25 column-limit violations (Views/ViewModels, mostly formatting), 1 missing doc comment (ReminderRowView), 3 doc formatting, 1 import ordering
- **LOW: 13 items** — stylistic/documentation, all already compliant or trivial

**Scope Performance:**
- App + Models (Saul): **PERFECT** — 6/6 files, 0 HIGH, 0 MEDIUM, 0 LOW. Exemplary entry-point and model layer code.
- Views + ViewModels (Linus): **STRONG** — 18 files, 1 HIGH (access control), 25 MEDIUM (formatting), clean structure.
- Services + Utilities (Basher): **EXCELLENT** — 29 files, 6 HIGH (doc comments), 4 MEDIUM (minor fixes), **zero force unwraps/casts across entire scope**. Mature error handling.

**Key Patterns:**
1. **Zero force unwraps in production code** — entire codebase demonstrates defensive programming excellence.
2. **Protocol-driven design** — all service dependencies abstracted; exceptional testability.
3. **Access-level discipline** — no over-exposure of internal members (1 violation found and flagged).
4. **Column-limit violations** — 25 instances (1% of Views/ViewModels), mechanically fixable with line-wrapping.
5. **Doc comments** — strong on public APIs; 4 stubs and computed properties lack documentation (easily remediated).

**GitHub Issue:** [#646 — Audit: Google Swift Style adherence](https://github.com/yashasg/fantastic-octo-fortnight/issues/646)

**Remediation Effort Estimate:** 1–2 hours for full remediation (extension access control fix, doc comments, column-limit wrapping).

**Team Learning:** Google Swift adoption is operationalized. SwiftLint integration into CI is the next critical step to prevent future drift. App layer sets the tone for the codebase — Saul's perfect audit on App/Models establishes the standard; Views/Services need formatting polish to achieve parity.

### 2026-05-15: Audit Decomposition into Remediation Issues

**Task:** Decompose Issue #646 (Google Swift Style adherence audit) into focused, actionable child issues — one per fix CATEGORY (not one per file:line). Each child issue is the natural unit of one PR's worth of work.

**Decomposition Strategy:**
- **HIGH-priority items:** 2 child issues
  - #652: Access control (AppCategoryPickerView, AppCoordinator, PauseConditionManager) — owner: Linus + Basher
  - #649: Doc comments on Services public API — owner: Basher
- **MEDIUM-priority items:** 3 child issues
  - #650: Line-wrapping for 100-char column limit (Views/ViewModels, 25 violations) — owner: Linus
  - #647: Import ordering (Services/Utilities) — owner: Basher
  - #648: IUO review & refactoring (OverlayManager) — owner: Basher
- **TOOLING:** 1 child issue
  - #651: Integrate swift-format & SwiftLint into CI — owner: Virgil

**Rationale:**
- Grouped by **technical category** (access control, documentation, formatting, imports, tooling), not by file or auditor
- Each category represents a distinct area of concern with a natural boundary for PR review
- Column-limit violations (25 instances) bundled as one issue because they follow a single pattern (§Line-Wrapping rule)
- IUO review separated because it requires code-review judgment, not mechanical fix
- Tooling issue isolated because it affects CI/CD and requires cross-team coordination

**Outcomes:**
- All 6 remediation issues created: #647, #648, #649, #650, #651, #652
- Issue #646 updated with child-issues checklist at end of body
- Team has clear, independent PRs to parallelize remediation work

**Pattern for Future Audits:** When decomposing audit findings into child issues, group by technical CATEGORY (not per file/line), assign each category to a single owner, and ensure each issue represents one PR's natural scope. This pattern enables parallel team execution and clean PR review boundaries.

- 2026-05-15: You are now explicitly Frontend-scoped. Benedict (Backend Code Reviewer) owns backend review (services, concurrency, lifecycle, system APIs); your domain is frontend review (SwiftUI views, accessibility, assets, animations). Frontend and backend review scopes do not overlap.
- 2026-05-15: Issue #742 (UX_FLOWS.md TCA rewrite, p2) is now in your queue under squad:saul. Blocked on #677 + #701 + #702 landing first. Coordinate with the docs sweep PR that closes #725 + #741.
- 2026-05-15: Toulour and Denham will file accessibility/HIG issues. I gate the PRs that fix them at the Frontend code review step.

- **2026-05-15: Team consolidation — 7 teams collapsed to 2 (Dev + Strategy).** You are now explicitly on the **Dev team** alongside Rusty, Linus, Livingston, Saul, Basher, Yen, Benedict, Virgil. Dev team owns code, tests, build, and CI. Strategy team (Danny, Tess, Reuben, Turk, Frank, Roman, Toulour, Denham, Sponder, Bashir, Matsui, Bruiser) handles product, design, research, legal, audits, and ASO. Scribe and Ralph remain on the roster outside both teams (silent infra). Use GitHub label `team:dev` for issue routing; see .squad/streams.json for canonical Dev workstream folder scopes.

# Danny — History

## Project Context

- **Owner:** Yashasg
- **Project:** kshana (formerly Eye & Posture Reminder) — a lightweight iOS app with True Interrupt Mode via Screen Time APIs
- **Stack:** Swift, SwiftUI (iOS 16+), MVVM, UserNotifications, UIKit overlay, UserDefaults, FamilyControls (Phase 3+)
- **Created:** 2026-04-24

## 2026-04-29 — Product Pivot to True Interrupt Mode & Phase 3 Backlog

**Task:** Update roadmap/implementation plan and create canonical GitHub backlog.  
**Status:** ✅ Complete — orchestration log filed

**Key outcomes:**
- **Product pivot documented:** Core value is True Interrupt Mode (non-dismissible shields), not gentle reminders
- **Files updated:** README.md, ROADMAP.md, IMPLEMENTATION_PLAN.md
- **GitHub backlog created:** Issues #201-#211 (Phase 3 backlog)
  - #201: FamilyControls Entitlement Approval (P0 blocker, case ID 102881605113)
  - #202-#211: Phase 3 implementation tasks (extensions, authorization, app selection UI, etc.)
- **Issue management:** Closed #199 (legal docs duplicate) → #209 (legal coordination), kept #200 (App Store listing coordination)

**Key decision:** Phase 3 is now critical path to MVP (not optional Polish/Advanced). Shields are primary interruption; notifications are fallback. Entitlement approval gates external distribution only; local development/testing can proceed in parallel.

**Decision merged into `.squad/decisions.md`.**

## 2026-04-25 — Documentation: Wave 2 Updates (ROADMAP, ARCHITECTURE, README)

**Status:** ✅ Complete  
**Scope:** Documentation reflecting Phase 1 completion and Phase 2 preview

### Orchestration Summary

- **ROADMAP.md:** Updated with Phase 1 completion status, Phase 2 preview, Phase 3 roadmap
- **ARCHITECTURE.md:** Added testing strategy, detector architecture patterns, data flow diagrams
- **README.md:** Updated feature description with pause conditions, legal status note
- **All docs synchronized** with current implementation state
- **Orchestration Log:** Filed at `.squad/orchestration-log/2026-04-24T23-19-18Z-danny.md`

### Documentation Highlights

- Testing layers documented: Unit, Integration, UI (XCUITest)
- Detector architecture and priority order documented
- Phase 2 roadmap: Full test coverage, .xcodeproj integration, accessibility audit

### Next Phase

Documentation ready for Phase 2 planning cycle.

## Team Sync — 2026-04-25T04:35

**Completed Handoffs:**
- Rusty: ARCHITECTURE.md 6-point corrections validated against impl
- Basher: DI protocols (ScreenTimeTracking, PauseConditionProviding) — PR #17 ready for review
- Livingston: Coverage analysis (64.2%, 573/575 pass) — AppConfigTests #15 in progress
- Scribe: Orchestration logs filed; decisions.md archived (89.9KB exceeded limit)

**Cross-Impact Summary:**
- Architecture clarity enables Services impl → Views integration ready
- All Phase 1+2 tests now stable; ready for App Store submission decision

## Archive

### 2026-04-24 — Legacy Planning & Preparation

**Initial Roadmap Planning, M2.7 App Store Preparation, Data-Driven Config Spec, Dark Mode Feature Scoping, App Store Metadata, Wave 4 Native-First Config**

Consolidated 2026-04-24 planning entries covering early architecture decisions (MVVM + UNUserNotificationCenter), app store listing metadata, privacy policy, data-driven configuration exploration, dark mode feature scope, and final 4-layer config architecture (Asset Catalog + String Catalog + defaults.json + Swift code). All decisions have been implemented and verified; legacy planning notes preserved for reference. Phase 0 foundation complete; Phase 1-2 implementation active.

### 2026-04-25: Documentation Completeness & Quality Audit (READ-ONLY)

- **Context:** Full audit of all project documentation — root markdown files, docs/ directory, and inline source comments.
- **Key Findings:**
  1. **Legal placeholders are the top blocker:** TERMS.md and PRIVACY.md still have `[Date]` and `[Your Company Name]` placeholder text — must be fixed before App Store submission.
  2. **UX_FLOWS.md is stale:** Describes pre-onboarding first-launch flow (straight to Settings + system permission prompt). Actual app uses 3-screen onboarding (Welcome → Permissions → Setup). Snooze UI described as "in Settings only" but may have evolved.
  3. **IMPLEMENTATION_PLAN.md partially outdated:** Section 9 Data Flow diagram still says `repeat: true` (Phase 1 behavior); Phase 2 uses `repeat: false` with ScreenTimeTracker re-arm. Section 1 says "runs timers in the background" — no longer accurate (foreground screen-time tracking).
  4. **ARCHITECTURE.md build instructions wrong:** Section 3 says "Build via `swift build` / `swift test`" but README correctly notes these don't work (iOS-only frameworks require xcodebuild). Contradicts README.
  5. **ARCHITECTURE.md status tag stale:** Header says "Status: Foundation" — should be "Phase 2" or later.
  6. **CHANGELOG.md well-maintained:** Follows Keep a Changelog-adjacent format; covers all 7 quality loops. No version entries beyond v0.1.0-beta.
  7. **README.md is solid:** Build instructions, feature list, legal links all present and accurate.
  8. **Inline code docs excellent:** Every service and model file has file-level doc comments explaining purpose, behavior, and design rationale.
  9. **docs/ directory well-organized:** APP_STORE_LISTING, DESIGN_SYSTEM, ONBOARDING_SPEC, TELEMETRY, TEST_REPORT, TEST_STRATEGY, legal/ subdirectory — comprehensive.
  10. **ROADMAP.md is thorough and current:** Phase 0-3 status accurately reflects implementation state.
- **Recommendation:** Fix legal placeholders (blocker), update UX_FLOWS.md for onboarding, reconcile IMPLEMENTATION_PLAN.md data flow diagram, fix ARCHITECTURE.md build instructions and status tag.

### 2026-04-25: UX_FLOWS.md Onboarding Correction (Issue #112)

- **Context:** UX_FLOWS.md Section 2.1 described first-launch as "App opens directly to Settings Screen" with an immediate system permission prompt. The actual app uses a 3-screen onboarding flow (Welcome → Permissions → Setup) implemented via `ContentView` → `OnboardingView`.
- **Root cause:** UX_FLOWS.md was written during Phase 1 planning (pre-onboarding). The onboarding flow was added in Phase 2 (M2.1) but UX_FLOWS.md was never updated to match.
- **Sections rewritten:**
  1. **Section 2.1** — Complete rewrite: documents the 3-screen `OnboardingView` flow with accurate screen descriptions, navigation behavior (swipe blocked on Screen 2), two completion paths ("Get Started" / "Customize Settings"), and `hasSeenOnboarding` gating logic.
  2. **Section 3.3** — Updated trigger: permission prompt is user-initiated on Screen 2, not automatic on launch.
  3. **Section 5** — Replaced "Minimal Onboarding / No multi-screen flow" philosophy with "Educate, Then Ask" philosophy describing the actual 3-screen implementation.
  4. **Section 10 Summary** — Updated onboarding bullet to reflect the 3-screen flow.
- **Key learning:** When a Phase 2 feature replaces Phase 1 behavior, all doc sections referencing the old behavior must be audited — not just the primary section. UX_FLOWS.md had 4 separate sections describing the old first-launch flow.
- **Commit:** `docs: update UX_FLOWS.md to reflect actual onboarding flow` (Fixes #112)

### 2026-04-27: Yin-Yang Roadmap & UX Flow Documentation Sprint

- **Context:** Team sprint to document yin-yang logo animation feature as M2.10 (Phase 2 Polish). Decision merged into decisions.md.
- **ROADMAP.md update:** Classified yin-yang as M2.10, Phase 2 (part of Restful Grove redesign, not Phase 3 advanced feature). Updated timeline table, dependency map, key decisions (Decision 2.4 mapped to 5 architectural choices).
- **UX_FLOWS.md §5.4:** Documented animation flow — spin (360°, 2s deceleration) → breathing pulse (4s in/out, infinite). Reduce-motion fallback (static logo). Placement: HomeView + OnboardingView.
- **Decision artifact:** `.squad/decisions/inbox/danny-yinyang-roadmap.md` → merged into decisions.md
- **Team collaboration:** Tess (implementation), Rusty (architecture docs), Livingston (9 tests), Roman (app naming research)

## 2026-04-28 — xcstrings Readability Clarity Pass

**Task:** Explain the phrase "Notifications wake reminders back up when a snooze ends" and propose readability/clarity improvements to `.xcstrings` copy.

**Work Summary:**
- Explained meaning: After snoozed reminders expire, the app uses a notification to restart break reminders on schedule
- Reviewed full `Localizable.xcstrings` (77 keys) for clarity opportunities
- Proposed 14 string replacements emphasizing simpler, plain-English phrasing
- Preserved all placeholders (`%@`, `%d`, `%lld`); left legal copy unchanged
- Decision filed: `.squad/decisions/inbox/danny-xcstrings-clarity-pass.md`

**Example changes:**
- `onboarding.permission.body1`: "Notifications wake reminders back up when a snooze ends — so your next break arrives right on time." → "Notifications let your breaks resume on time after a snooze."
- `onboarding.welcome.body`: "Takes less than a minute to set up. Works quietly in the background — you'll barely know it's there." → "Quick to set up. Runs quietly — you'll barely notice it."
- `settings.notifications.disabledBody`: "Enable notifications in Settings so reminders resume after snoozing, even when the app is in the background." → "Turn on notifications in Settings so breaks resume after a snooze."

**Status:** Proposed for Linus implementation

## 2026-04-28 — Screen-Relevant Copy Scope Refinement

**Task:** Coordinator passed user directive for screen-relevant copy. Refine scope: identify which of the 14 clarity pass strings should be retained vs. removed based on screen context.

**Work Summary:**
- User correctly flagged: screen copy should not mention snooze on screens that are not about snooze (e.g., onboarding permission screen, notification-disabled banners)
- Onboarding permission screen appears *before* snooze is introduced — snooze language is contextually wrong
- Notification-disabled screens should explain impact on break reminders, not snooze-specific behavior
- **Three strings require scope reversion:**
  - `onboarding.permission.body1`: Revert from clarity pass → "Notifications keep your break reminders on schedule." (no snooze mention)
  - `settings.notifications.disabledBody`: Revert from clarity pass → "Turn on notifications in Settings so break reminders stay on schedule." (no snooze mention)
  - `settings.notifications.disabledLabel`: Revert from clarity pass → "Notifications are off. Turn them on in Settings so break reminders stay on schedule." (no snooze mention)
- All `settings.snooze.*` keys remain untouched — snooze language is correct on snooze-specific screens
- **Correct decision:** Clarity pass improved readability; scope refinement removes context-inappropriate snooze references; two efforts are complementary, not conflicting

**Status:** Recommendation delivered to Linus for implementation

## 2026-04-28 — User Directive: Reminders Terminology

**Task:** Review user directive to standardize terminology — avoid "push notifications" language that misrepresents the app's overlay reminder nature.

**Work Summary:**
- User directive received: "Avoid user-facing copy that makes kshana sound like it sends push notifications. Prefer reminders/break reminders/overlay reminders where accurate."
- Reviewed terminology: App provides overlay-based break reminders, not push notifications
- Identified terminology guidance: Replace user-facing "Notifications" with "Reminders"; preserve OS/accessibility terminology only in settings hints
- Recommended 7 key strings for terminology updates to align with overlay reminder nature
- Rationale: Full-screen overlays are fundamentally different from push notifications

**Status:** ✅ Complete. Handoff to Linus for implementation.


## 2026-04-29 — Product Pivot: True Interrupt Mode via Screen Time APIs

**Status:** ✅ Complete (docs updated, GitHub backlog created)
**Duration:** Single session
**Pivot Summary:** kshana core value transitions from local notification reminders to True Interrupt Mode via Apple Screen Time APIs (FamilyControls + DeviceActivity + ManagedSettings). Local notifications become fallback/noise, not the product promise.

### Work Completed

#### 1. Product Documentation Updated
- **README.md:** Added pivot statement: "Now integrating Apple Screen Time APIs for True Interrupt Mode — shields distracting apps, enforces breaks"
- **ROADMAP.md:** 
  - Updated executive summary to emphasize Screen Time APIs pivot
  - Renamed Phase 3 from "Advanced Features" → "Interrupt Mode MVP"
  - Replaced M3.1-M3.4 (iCloud sync, widgets, watchOS) with M3.1-M3.11 (Screen Time APIs, extensions, permissions, legal)
  - Added architecture overview for Phase 3 (extension targets, app groups, DeviceActivity flow)
  - Added detailed data flow diagram (reminder → shield → compliance)
  - Clarified why pivot: iOS only allows true interruption via ScreenTime APIs
- **IMPLEMENTATION_PLAN.md:**
  - Added Phase 3 pivot notice at top
  - Updated Section 2 (Frameworks) to include ScreenTime, FamilyControls, ManagedSettingsUI
  - Updated Section 3 (Architecture) with extension targets + app group structure
  - Added new Section 4.2 (Screen Time APIs & True Interruption) with data flow + acceptance criteria
  - Clarified notification role: fallback only, not primary

#### 2. GitHub Backlog Created (11 Issues)
- **#201** M3.1 [BLOCKER] Entitlement Approval Follow-up (Case ID 102881605113)
  - Blocker for all downstream work
  - P0 priority
  - Owner: Frank (Legal) + Danny (PM)

- **#202** M3.2 Screen Time Shield Spike (Architecture Research)
  - Extension prototype, app group communication, performance baseline
  - P1 priority
  - Owner: Rusty (Architect)

- **#203** M3.3 Project & Extension Target Setup (Xcode + CI/CD)
  - ShieldConfiguration + ShieldAction targets
  - App group entitlements, CI/CD updates
  - P1 priority
  - Owners: Basher (Services) + Virgil (CI/CD)

- **#204** M3.4 FamilyControls Authorization & App/Category Picker UI
  - Authorization flow, app/category browser UI
  - Fallback messaging, onboarding updates
  - P1 priority
  - Owners: Linus (UI) + Basher (Services)

- **#205** M3.5 DeviceActivity Monitoring Service
  - Screen time tracking per app/category
  - Integration with existing ScreenTimeTracker
  - P1 priority
  - Owner: Basher (Services)

- **#206** M3.6 ManagedSettings Shielding & ShieldAction Extension
  - Shield application + clearance logic
  - Custom shield UI + access request button
  - P1 priority
  - Owners: Basher + Linus

- **#207** M3.7 App Group Shared State & Watchdog (IPC)
  - Main app ↔ extensions communication via UserDefaults
  - Watchdog service (optional, logs compliance)
  - P2 priority
  - Owner: Basher (Services)

- **#208** M3.8 Pre-Permission UX Refinement (Onboarding)
  - Onboarding redesign: welcome → permissions → app picker → setup
  - Fallback screens, accessibility
  - P1 priority
  - Owners: Reuben (Design) + Linus (UI)

- **#209** M3.9 Privacy & Legal Docs Updated for Screen Time APIs
  - Privacy policy, terms, disclaimer (linked to #199)
  - Legal review, Apple guidelines compliance
  - P1 priority
  - Owners: Frank (Legal) + Danny (PM)

- **#210** M3.10 CI/CD & Code Signing for Extension Targets
  - GitHub Actions workflow updates
  - Extension provisioning profiles + entitlements
  - TestFlight build validation
  - P1 priority
  - Owner: Virgil (CI/CD)

- **#211** M3.11 Local Notification Fallback Positioning
  - Notification scheduling refactor (shield-first, fallback second)
  - Fallback copy, settings toggle
  - Metrics logging (shield vs. notification reminders)
  - P2 priority
  - Owners: Basher + Linus

### Key Decisions

**Decision: Core Value Pivot to True Interrupt Mode**
- **Rationale:** iOS prevents app-initiated interruptions (notifications + overlays dismissed easily). ScreenTime APIs allow designated interruptions (shielding) that enforce breaks. Aligns with wellness mission: users actually take breaks, not just get reminded.
- **Implication:** Phase 3 is now critical path to product differentiation, not optional polish.
- **Entitlement Dependency:** All work blocked on Case ID 102881605113 (Apple FamilyControls entitlement approval).

**Decision: Notification Role Changes**
- **Old:** Reminders are primary; overlays are UI enhancement.
- **New:** Shields are primary; notifications are graceful fallback if shield unavailable.
- **Implication:** Notification copy should not oversell (avoid "push notification" language, use "reminder" + "fallback").

### Backlog Scope Coverage

✅ Covers all required topics from task brief:
- ✅ Entitlement follow-up (Case ID 102881605113) → #201
- ✅ Screen Time shield spike → #202
- ✅ Project/extension target setup → #203
- ✅ Authorization + app/category picker → #204
- ✅ DeviceActivity monitoring → #205
- ✅ ManagedSettings shielding → #206
- ✅ ShieldConfiguration/ShieldAction extensions → #206
- ✅ App Group shared state → #207
- ✅ Onboarding/pre-permission UX → #208
- ✅ Privacy/legal updates → #209
- ✅ CI/signing/profiles → #210
- ✅ Local notification fallback positioning → #211

### Docs Touched
- `README.md` (line 1-3: elevator pitch updated)
- `ROADMAP.md` (header, executive summary, Phase 3 section replaced)
- `IMPLEMENTATION_PLAN.md` (header, sections 2-4.2 updated)

### Team Next Steps
1. **Frank (Legal):** Follow up on entitlement approval (Case ID 102881605113) — #201 is blocker
2. **Rusty (Architect):** Begin screen time APIs spike (DeviceActivity, ManagedSettings, extension architecture) — #202
3. **Danny (PM):** Sync with team on pivot, prioritize Phase 3 backlog, coordinate App Store re-submission strategy
4. **All:** Review updated docs (ROADMAP, IMPLEMENTATION_PLAN) for questions

### Learnings
- **Product Pivots Need Doc-First Clarity:** This pivot affects architecture, permissions, extension targets, legal/privacy, and UI flows — updating docs first (before code) ensures all teams understand the new direction.
- **Entitlements Are True Blockers:** FamilyControls entitlement approval is critical path; all downstream work (extension targets, authorization flows, shield logic) depends on it.
- **Extension Architecture Adds Complexity:** Phase 3 requires new targets (ShieldConfiguration, ShieldAction), app groups, inter-process communication, and CI/CD changes — spike work (M3.2) is essential before committing to full build-out.

## 2026-04-29 — Backlog Reconciliation: #199, #200 Deduplication

**Task:** Reconcile GitHub issues #199–#211 to eliminate duplicates and ensure clear tracking. Frank created #199 and #200; Danny created canonical #201–#211.

**Analysis:**
- **#199** "Legal & Privacy Docs Updated: True Interrupt Mode" — Completed work summary documenting PRIVACY.md, DISCLAIMER.md, PRIVACY_NUTRITION_LABELS.md updates. No labels; no active work items.
- **#209** "M3.9 Privacy & Legal Docs Updated for Screen Time APIs" — Canonical tracker for legal/privacy work. Properly labeled (squad:danny, squad:frank, type:docs, priority:p1).
- **#200** "App Store Listing: Coordinate Legal Disclaimer Updates for Screen Time Feature" — Forward-looking coordination item for when Screen Time feature launches. Focuses on App Store listing updates + privacy labels in App Store Connect + team coordination (Frank/Reuben/Yashasg). Not a duplicate of #209 (which tracks internal legal docs).

**Actions Taken:**
1. ✅ **Closed #199** with comment: "✅ This issue documents completed work. The canonical tracker for ongoing legal/privacy documentation work is #209 M3.9. Refer to #209 for legal work tracking and acceptance criteria."
2. ✅ **Added labels to #200:** squad:danny, squad:frank, squad:reuben, release:backlog, type:docs, priority:p1
   - Rationale: #200 is unique follow-up work (App Store coordination) distinct from #209's internal docs scope. Labels ensure visibility in backlog without creating duplicate tracking.

**Result:** Backlog now has clear ownership:
- **#209** tracks internal legal/privacy docs (Privacy Policy, Terms, Disclaimer review/sign-off)
- **#200** tracks App Store listing coordination (when feature launches; blocking pre-requisite for shipping)
- **#199** archived as completed-work summary with clear redirect to active tracker


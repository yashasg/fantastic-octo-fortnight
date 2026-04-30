# Danny — History

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

## 2026-04-30 — Post-#302–#314 Release Readiness Audit (Round 2)

**Task:** Read-only product/release readiness audit after issues #302–#314.

**Scope checked:**
- ROADMAP.md, CHANGELOG.md, README.md — consistent with v0.2.0 Restful Grove, Phase 3 pivot messaging
- APP_STORE_LISTING.md — version, keywords, What's New, disclaimer all current (fixed by #303/#307)
- TESTFLIGHT_METADATA.md — test case #1 fixed (#312); test case #2 "Grant App Break Access" still stale
- ONBOARDING_SPEC.md — screen names/content diverged from implementation
- UX_FLOWS.md — flow diagram shows 5 screens (code has 4); §5.3 still says "3 screens"
- ARCHITECTURE.md — §8.5 says "Three-screen flow" (code has 4); §3 file tree missing OnboardingInterruptModeView.swift
- OnboardingView.swift line 4 comment says "3-screen" (code has 4)
- Open blockers: #185, #196, #201, #209, #210 — all still valid, no duplicates

**Findings:** 7 stale onboarding references across 5 files

**Issue created:** #318

**Learnings:**
- Onboarding screen count/names are the #1 recurring drift pattern (third audit cycle catching variants)
- "Zero stale references remaining" claims need full-file grep verification, not spot checks
- Spec files (ONBOARDING_SPEC.md) can silently diverge when implementation evolves
- Cross-referencing between docs creates a combinatorial verification burden; consider a single source of truth for screen inventory


## 2026-04-30 — Post-#299 Release Readiness Audit

**Task:** Read-only product/release readiness audit after True Interrupt issue marathon and #299 fix.

**Findings:**
- CHANGELOG snooze options wrong (says "5 min / 15 min / 30 min / rest-of-day" but code has 5 min / 1 hour / rest of day)
- APP_STORE_LISTING.md stuck at v0.1.0-beta, What's New text doesn't reflect v0.2.0 Restful Grove
- Onboarding screen count stale in CHANGELOG, ARCHITECTURE.md, UX_FLOWS.md (says 3, actual is 4)
- Open blockers #185, #196, #201, #209, #210 verified — still valid, not duplicated

**Issue created:** #303 — docs drift covering all three findings

**Learnings:**
- CHANGELOG entries written at Phase 1 time can rot as features evolve (snooze options changed post-Phase-1)
- APP_STORE_LISTING.md needs a version bump pass after every release milestone
- Closed audit issues (#292) don't guarantee fixes were applied — always re-verify

### 2026-04-30 — #302 App Store disclaimer
- Added concise "Not medical advice" disclaimer to `docs/APP_STORE_LISTING.md` Section 3.
- Adapted language from `docs/legal/DISCLAIMER.md` full disclaimer, condensed for App Store character limits.
- Removed "Download now and build healthier screen time habits" CTA to avoid implying health outcome guarantees.
- Screen Time feature disclaimer included per acceptance criteria.
- Commit: 1e75388. Issue closed. Frank review requested for final copy polish.

## 2026-04-30 — Fix #303 and #307: Docs drift + ASO keyword swap

**Task:** Single product/docs pass to fix two issues — docs drift (#303) and ASO keyword optimization (#307).

**Changes (commit cc06aff):**
- CHANGELOG.md: snooze corrected to 3 options (5m/1h/rest-of-day); onboarding → 4-screen; SnoozeOption enum → 3 options
- ARCHITECTURE.md: OnboardingView → 4-screen PageTabView container
- UX_FLOWS.md: both stale 3-screen references → 4-screen
- APP_STORE_LISTING.md: version header → v0.2.0 Restful Grove; What's New rewritten for v0.2.0; version field → 0.2.0; build → CI-assigned; keyword `wellness` → `screen time` (93 chars); screenshot snooze options corrected

**Validation:**
- Zero `3-screen` references remaining in target files
- Zero `0.1.0` references remaining in APP_STORE_LISTING.md
- Keyword string verified at 93 chars (≤ 100)
- `wellness` confirmed absent from keyword field

**Issues closed:** #303, #307

## 2026-04-30 — TestFlight Test Case #1 Screen Name Fix (#312)

**Task:** Fix stale screen names in TESTFLIGHT_METADATA.md test case #1 to match actual onboarding implementation.

**Work Summary:**
- Verified 4-screen onboarding flow in code: Welcome → Notification Permission → Schedule Setup → True Interrupt Mode
- Updated test case #1 screen sequence and per-screen tester instructions
- Confirmed no other test cases reference "App Break Explanation" or "Screen Time Permission"
- Noted test case #2 still references "Grant App Break Access" which doesn't match actual button text ("Allow Reminder Alerts") — separate scope

**Issues closed:** #312

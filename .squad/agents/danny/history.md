# Danny — History

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

## 2026-04-30 — TestFlight Blocker Status Audit (#201, #196, #185, #410)

**Task:** Drive remaining TestFlight/external blockers and dependency status.

**Findings:**

1. **#201 — Entitlement Approval (BLOCKER):** External Apple Developer Support case (102881605113). Owner checklist posted 2026-04-30 11:52 UTC. Requires:
   - Follow-up on Apple case status
   - If approved: record approval date and entitlement enabled status
   - If rejected: post rejection reason verbatim + remediation plan
   - Unblock criteria: approval OR actionable rejection with documented remediation

2. **#196 — Upload Custom EULA:** External App Store Connect manual task. Owner checklist posted 2026-04-30 11:52 UTC. Requires:
   - Navigate ASC → App Information → License Agreement
   - Paste content from `docs/legal/TERMS.md` (confirmed present, v1.0, dated 2026-04-26)
   - Save and verify in app metadata
   - Post screenshot/completion evidence

3. **#185 — Host Privacy Policy HTTPS URL:** External dependency. Owner checklist posted 2026-04-30 11:52 UTC. Requires:
   - Publish `docs/legal/PRIVACY.md` at stable public HTTPS URL (e.g., GitHub Pages)
   - Verify reachable without auth in private/incognito browser
   - Update ASC Privacy Policy URL field to match
   - Verify in-app Settings link targets same URL
   - Post final URL + verification note

4. **#410 — ShieldAction Phase 2 (BLOCKED on #201):** Dependency comment posted 2026-04-30 11:52 UTC confirming blocker status. Will remain blocked until #201 resolved.

**Assessment:** All four issues are in the correct external/manual state. Checklists are clear, actionable, and prioritized by unblock dependencies. No code fixes available for these—all require manual Apple approval, ASC uploads, or hosting setup. Blocked chain is correct: #410 → #201 (external). Recommend: Yashas execute checklist items in parallel (#196 and #185 are independent and can proceed immediately while awaiting #201 Apple response).

**Outcome:** All issues remain BLOCKED/PENDING external action. Status verified, checklists active, dependency chain is clear.

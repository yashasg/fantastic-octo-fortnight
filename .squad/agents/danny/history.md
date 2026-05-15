# Danny — History

## 2026-05-01 — Apple Developer Support Reply: Entitlement Business Need (Case 102881605113)

**Task:** Draft reply to Apple Developer Support request for business need justification for FamilyControls/DeviceActivity/ManagedSettings entitlement approval.

**Context:** Apple support asked for "business need" (deadline or significant impact on distribution) to justify entitlement grant. This is the first substantive Apple correspondence requiring product narrative + distribution impact framing.

**Approach:**
- Reframe request from "feature flag" to "core product promise" (enforceable break-time boundaries without entitlements is incomplete)
- Lead with *what* (privacy-first wellness app, Digital Wellbeing aligned)
- Explain *why* (only Apple-sanctioned path, private APIs explicitly disallowed)
- State *impact* (TestFlight → App Store gating, every week = delayed go-to-market)
- Offer escalation (technical detail, demo video, architecture specs)
- Tone: professional, human (solo indie dev authenticity), no desperation or pleading

**Deliverable:** Draft + notes in `.squad/decisions/inbox/danny-apple-entitlement-reply.md` for Frank (Legal) review before sending.

**Learnings:**
- **Apple Developer Support correspondence pattern:** Product narrative + distribution gating + sanctioned-path-only + offer to escalate with technical/design detail. Reusable for TestFlight review feedback, App Store review appeals, and future entitlement follow-ups.
- **Business-need framing:** "Core product promise" > "nice-to-have feature" with Apple. Completeness and alignment matter. Privacy/compliance positioning builds reviewer trust.
- **Concision wins:** Apple reviewers process dozens of cases. Short paragraphs (what/why/impact) outperform longer justifications. Four focused paragraphs hit all beats.

---

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

**Issues closed:** #312

---

## 2026-05-14 — Apple Developer Support Reply: Entitlement Business Need (Case 102881605113) — APPROVED & MERGED

**Task:** Draft reply to Apple Developer Support request for business need justification for FamilyControls/DeviceActivity/ManagedSettings entitlement approval. Work reviewed by Frank (Legal), approved with 2 surgical edits, merged into decisions.md.

**Strategic approach:**
- Reframe request from "feature flag" to "core product promise" (enforceable break-time boundaries; without entitlements, incomplete)
- Lead with *what* (privacy-first wellness app, Digital Wellbeing aligned, no tracking/ads/accounts)
- Explain *why* (only Apple-sanctioned path; private APIs explicitly disallowed)
- State *impact* (TestFlight → App Store gating; every week = delayed go-to-market, user acquisition friction, credibility positioning)
- Offer escalation (technical architecture, demo video, design specs)
- Tone: professional, human (solo indie dev authenticity), no desperation or pleading

**Key learnings:**
- Apple correspondence pattern: Product narrative + Distribution gating + Sanctioned-only approach + Offer to escalate. Reusable for TestFlight review, App Store appeals, future entitlements.
- Business-need framing: "Core product promise" > "nice-to-have feature" with Apple. Completeness and alignment matter.
- Concision wins: 4 focused paragraphs outperform longer justifications. Apple reviewers process dozens of cases.
- Privacy/compliance positioning early builds reviewer trust (no tracking/ads/accounts signals responsible Screen Time API use, not ad-tech or surveillance)

**Deliverable:** Decision merged to `.squad/decisions.md` (section: "Apple Developer Support Reply on FamilyControls/DeviceActivity/ManagedSettings Entitlement Request"). Inbox files deleted post-merge. Frank's review approval + edits now part of permanent record.

**Follow-up:** Yashas to edit and send; coordinate copy archival to `.squad/log/apple-case-102881605113-sent-{date}.md` post-send.

## Learnings

- **External correspondence must be plain prose, no markdown.** Markdown syntax (e.g., `**bold**`, `- bullets`, numbered lists) renders as literal characters in most email clients and web forms (Apple Developer Support, customer email platforms). Labeled section headers ("What X is:") read as obviously LLM-generated. Solo indie developer voice uses natural paragraphs with varying sentence length and rhythm, contractions, and conversational phrasing ("I can send that over" beats "I would be delighted to provide"). This applies to all future Apple Developer Support replies, customer emails, marketing correspondence, or any human-facing written communication outside the codebase. Substance stays the same; formatting and tone shift to sound authentic and human-readable.


---

## 2026-05-14 — Apple Developer Support Reply v2: Plain-Prose Rewrite (Case 102881605113)

**Task:** User-driven revision of v1 send-ready draft. Yashasg rejected v1 for sounding "AI-generated" due to markdown formatting.

**Feedback:** "Sounds like an AI wrote it because you used markdown."

**Revision scope:** Rewrite v1 with identical substance and factual claims, but plain prose with natural paragraphs, no markdown, varied sentence length, contractions, and conversational phrasing. Formatting/voice change only; Frank's legal review remains valid.

**Changes from v1 to v2:**
- Removed markdown formatting (no `**bold**`, no section headers)
- Replaced four labeled sections with natural flowing paragraphs
- Opening: "I'm happy to clarify..." → "Thanks for following up... I wanted to clarify..."
- "I'm happy to provide" → "I can send that over"
- Added contractions (`can't`, `it's`)
- Varied sentence length (short + long mix)
- Tightened body from ~230 to 165 words
- All factual claims identical to v1

**Deliverable:** `.squad/decisions/inbox/danny-apple-reply-v2.md` (merged to decisions.md as new send-ready draft; v1 marked SUPERSEDED).

**Status:** ✅ Complete. v2 is send-ready. Frank's legal review of v1 remains valid — substance unchanged.

**Learnings:**
- **Rewrite pattern:** When substance/accuracy is correct but tone/format read as AI-generated, rewrite in natural voice without markdown. Preserve factual accuracy; shift only formatting and rhythm.
- **External correspondence style:** No markdown for email/web forms (renders as literal characters). Labeled sections read as LLM-generated. Use conversational paragraphs with varied length, contractions, authentic phrasing.
- **Indie dev voice markers:** "I can send that over" (not "I would be delighted"), contractions (`can't`, `it's`), varied sentence rhythm, natural opening ("Thanks for the follow-up" not "Dear Sir, Thank you for the follow-up").

---

## 2026-05-14 — Apple Developer Support Reply: Final Send-Ready Edition (Case 102881605113)

**Status:** ✅ User sent with minor edits

**Revision:** v2 plain-prose rewrite approved and sent. Legal review by Frank remains valid (substance unchanged).

### User Edits (v2 → Sent)

Yashasg took the v2 draft and made three targeted edits before sending:

1. **Warmer opener:** "Thanks for getting back to me. I can share the business need..." (vs. v2's "Thanks for following up...")
2. **NEW product detail:** "Unless the phone is in focus mode or driving mode" — reveals app respects iOS DND signals
3. **Specificity:** "Once every 20 minutes the app triggers a visual, eye-resting, wellness break for the user by shielding..." — clearer timing and nature
4. **Streamlined closing:** Removed redundant check-in instructions; kept conversational

**Validation:** Plain-prose pattern drafted → user accepted → user sent with only minor warmth/specificity edits. **Zero formatting reverts. End-to-end pattern successful.**

### Follow-Up

- Expect response 5–14 business days
- Check-in ~May 28 if silent
- Archive: `.squad/log/apple-case-102881605113-sent-2026-05-14.md`

### Skill Confidence Bump

**external-correspondence-style:** `low` → `medium`

The plain-prose, no-markdown pattern for external correspondence was successfully applied end-to-end:
- Drafted v2 per skill guidelines
- User accepted (no formatting complaints in v2)
- User sent with only warmth/specificity edits (no markdown reverts, no structure complaints)

This is the first real-world validation of the pattern. Future external correspondence (customer support, App Store appeals, etc.) should follow the same model. **Next validation:** Apply to 2–3 more external emails. If pattern holds, bump confidence to high.


## 2026-05-14: Google Swift Style Guide Adopted (Audit #646)

**Event:** Full-codebase audit completed against docs/google_swift_coding_style.md. Results: 53 files audited, 7 HIGH violations, 29+ MEDIUM, 13 LOW. App + Models scope (danny's product layer) achieved perfect compliance (0 violations).

**Key for Danny:** Google Swift Style is now the canonical coding standard for kshana. Future product/spec work should reference this when discussing engineering quality bar (e.g., "let's ensure this feature adheres to Google Swift Style"). Replaces the previously aspirational status.

**Related:** GitHub Issue #646 contains full audit findings, violation tracker, and remediation roadmap. Branch: chore/coding-standards-audit.

**Reuse:** When scoping product features, mention Google Swift Style as a quality gate. Example: "This feature must land with full documentation per Google Swift Style §5" (a requirement most developers will now recognize).


---

## Learnings — Cross-Agent Directives

2026-05-15: Pinned to `claude-opus-4.7-xhigh` via `.squad/config.json` agentModelOverrides (per yashasg directive).

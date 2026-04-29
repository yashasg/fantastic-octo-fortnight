# Squad Decisions Archive

**Archive Date:** 2026-04-24  
**Archiver:** Scribe  
**Note:** Pre-Phase 1 decisions archived to keep decisions.md focused on Phase 1+ implementation decisions. Historical context preserved below.

---

## Pre-Phase 1 Decisions (Roadmap & Planning)

### User Directives (2026-04-24T00:57 — 2026-04-24T07:39:50Z)

#### 2026-04-24T00:57: User directive — Overlay behavior
**By:** Yashas (via Copilot)  
**What:**
- Overlay MUST be a translucent, blurry fullscreen takeover (not just a push notification banner)
- Displays "take an eye break" message with a 15-second countdown timer
- On timer completion: short vibration (haptic feedback), then overlay auto-dismisses
- Overlay must pause media playback (music, videos, podcasts) via MPRemoteCommandCenter
- Overlay must dim/blur the screen behind it — user's current task is visually paused
- User can resume their task after overlay dismisses

**Why:** User request — core UX requirement for Phase 1, not Phase 2

#### 2026-04-24T00:59: User directive — Overlay dismissal & snooze
- User MUST be able to cancel/dismiss the break overlay at any time (tap × or swipe down)
- After dismissing, show snooze options: "Disable reminders for 5 minutes", "1 hour", "Rest of the day"
- Snooze temporarily suppresses ALL reminders for the chosen duration
- After snooze expires, reminders resume automatically with no user action needed

**Why:** User request — respects user autonomy, prevents annoyance during meetings/focus time

#### 2026-04-24T01:01: User directive — Overlay layout
- Overlay should have an × dismiss button
- Below the × should be 3 snooze buttons: "5 min", "1 hour", "Rest of day"
- Open to better UX advice from the designer — this is a starting point, not locked in

**Why:** User request — overlay dismissal + snooze layout direction

#### 2026-04-24T01:06: User directive — Dismiss gesture & snooze presentation
- Overlay dismisses by swiping UP (not down) — this is the natural iOS gesture for dismissing overlays
- Swiping down should NOT trigger anything (no bottom sheet sliding up on swipe down)
- The snooze options (5 min, 1 hour, rest of day) need to be accessible WITHOUT a bottom sheet — they should be part of the overlay itself or appear inline
- Revises Reuben's two-phase recommendation: keep the two-phase concept (clean countdown → snooze on dismiss) but the snooze options should appear inline in the overlay after × tap, NOT as a separate bottom sheet

**Why:** User request — aligns with iOS gesture conventions and avoids conflicting gesture directions

#### 2026-04-24T01:09: User directive — Simplify overlay, move snooze to Settings
- Remove snooze buttons from the overlay entirely
- Overlay should have only: icon, title, countdown timer, × dismiss button, and a Settings gear button
- Settings button navigates the user to the app's Settings screen
- Snooze options (5 min, 1 hour, rest of day) live in the Settings screen, not the overlay
- Complete disable toggle also lives in Settings
- This supersedes previous directives about inline snooze buttons and bottom sheets

**Why:** User request — keeps the overlay simple and clean, consolidates all configuration in one place

#### 2026-04-24T01:17: User directive — Multi-part question routing
**What:** When a user asks a multi-part question, spawn multiple subagents in parallel — one per part — instead of bundling everything into a single agent spawn.

**Why:** User request — maximizes parallelism and gets faster, more focused answers per topic

#### 2026-04-24T01:27: User directive — Versioning strategy
**What:** Use 0.x.x during TestFlight beta phase, bump to 1.0.0 at App Store launch. Three-layer versioning: semver marketing version (manual), build number via CI (automatic), commit hash embedded in Info.plist (automatic).

**Why:** User confirmed Virgil's recommendation

#### 2026-04-24T07:39:50Z: User directive — Agent model specifications
**By:** Yashasg (via Copilot)  
**What:** All coding agents (Rusty, Linus, Basher, Livingston, Saul) should use claude-sonnet-4.6. Danny (Product Manager) should use claude-opus-4.6-1m.

**Why:** User request — captured for team memory

---

### Roadmap Decisions – Eye & Posture Reminder iOS App

**Date:** 2026-04-24  
**Decision Owner:** Danny (Product Manager)  
**Context:** Roadmap planning for IMPLEMENTATION_PLAN.md → full iOS app

---

## Scope Decisions

### 1. Phase Structure: 4 Phases (0-3)
**Decision:** Add Phase 0 (Foundation) before the original 3 phases from IMPLEMENTATION_PLAN.md

**Rationale:**
- Original plan jumped straight to MVP without establishing technical foundations
- Team needs CI/CD, architecture scaffolding, and design system in place first
- Foundation work (2 weeks) prevents rework and blockers in later phases

**Impact:**
- Total timeline extends from 5 weeks (original plan) to 7 weeks for App Store submission
- Phase 0 includes: Xcode setup, architecture scaffolding, CI/CD, design system, user journey mapping, test strategy
- Phases 1-2 map to original MVP + Polish phases
- Phase 3 remains optional (post-launch)

### 2. iOS Version Target: iOS 16+
**Decision:** Stick to iOS 16+ minimum deployment target (no iOS 15 support)

- IMPLEMENTATION_PLAN.md specified SwiftUI features requiring iOS 16 (List improvements, `.ultraThinMaterial`)
- iOS 16 adoption rate high (>85% as of late 2025)
- Supporting iOS 15 would require conditional compilation and alternate UI patterns (complexity vs. value trade-off)

- Approximately 10-15% of potential users excluded (iOS 15 devices)
- Development faster without fallback code
- Can use latest SwiftUI APIs without polyfills

### 3. Snooze Feature: Moved to Phase 2
**Decision:** Snooze action not included in Phase 1 MVP; added to Phase 2 (M2.3)

- Original plan listed snooze as "optional v2 feature"
- MVP should validate core value proposition (reminder scheduling + overlay) first
- Snooze adds complexity (state tracking, snooze count limits, UX decisions)
- Phase 2 Polish is appropriate timing after MVP user feedback

- Phase 1 ships without snooze (users can only dismiss or wait for auto-dismiss)
- Phase 2 adds snooze as UX enhancement
- Total feature count in MVP reduced (faster to market)

### 4. Preset Intervals vs. Custom Input
**Decision:** Use preset interval options (10/20/30/45/60 min) instead of free-form input

- Simpler UI (Picker vs. TextField + validation)
- Prevents edge cases (invalid input, extremely short intervals causing notification spam)
- Preset options cover 95% of use cases based on user research assumptions
- Free-form input can be added in Phase 3 if user feedback demands it

- Phase 1 Settings UI implementation simpler (M1.2)
- Edge case testing reduced
- Power users may request custom intervals (captured as post-launch feedback)

### 5. No Analytics in v1.0
**Decision:** Defer analytics integration (Firebase, Mixpanel) until post-launch

- Analytics adds privacy policy complexity (data collection disclosures)
- No clear business need for analytics in v1.0 (free app, no monetization decisions yet)
- App Store submission faster without analytics SDK
- Can add in v1.1 if business metrics become priority

- Cannot track DAU, retention, or feature usage in v1.0
- Reliance on App Store Connect basic metrics only
- Privacy policy simpler (minimal data collection)
- Open question logged in roadmap: "Do we need analytics?" (Owner: Danny, Deadline: Before M1.8)

### 6. Notification Sound: Default Only
**Decision:** Use default system notification sound; no custom sounds in v1.0

- Custom sounds require audio file assets (design work, file size impact)
- Default sound familiar to users and respects notification settings
- Custom sounds can be added in Phase 3 if requested

- No asset creation needed in Phase 0 (M0.4)
- Notification implementation simpler (M1.3)
- User customization limited in v1.0

### 7. Monetization Strategy: TBD
**Decision:** Deferred until Phase 2 (before M2.7 App Store Prep)

- No business requirements provided yet
- Monetization choice impacts App Store listing (pricing tier, IAP setup, ad integration)
- Options: free with IAP (unlock features), paid upfront ($1.99-4.99), ads, or 100% free
- Decision needed before App Store submission but not before Phase 1 development

- Phase 1 development unaffected (no IAP code needed yet)
- Open question logged in roadmap: "Monetization strategy?" (Owner: Danny, Deadline: Before M2.7)
- May influence Phase 3 scope (e.g., iCloud sync as premium feature)

## Priority Decisions

### 8. Critical Path: Phase 0 → Phase 1 → Phase 2 Required; Phase 3 Optional
**Decision:** Phases 0-2 are mandatory for App Store submission; Phase 3 is post-launch enhancement

- Phase 0: Foundation work is prerequisite for quality development
- Phase 1: MVP is minimum viable product (core value)
- Phase 2: Polish required for competitive App Store presence (onboarding, haptics, accessibility, app icon)
- Phase 3: Advanced features (iCloud, widgets, watchOS) differentiate but not essential for v1.0 launch

- App Store submission targets end of Week 7
- Phase 3 work begins after v1.0 live (Week 8+)
- Team can reprioritize Phase 3 based on v1.0 user feedback and business goals

### 9. Testing Coverage Requirements
**Decision:**
- Unit test coverage: 80% for Services and ViewModels
- UI test coverage: Critical paths only (onboarding, settings, overlay interaction)
- Manual testing: All milestones before merge

- Services and ViewModels contain business logic (high value for unit tests)
- UI tests brittle and slow (focus on happy path + key edge cases only)
- Manual testing catches UX issues automated tests miss

- Test strategy documented in M0.6
- CI configured to block merge if coverage drops (M0.3)
- Livingston (Tester) allocates time accordingly

### 10. Code Review Gate: Mandatory for All PRs
**Decision:** All code changes require Saul (Code Reviewer) approval before merge

- Quality gate prevents accumulation of technical debt
- Security review catches vulnerabilities early
- Consistency enforcement (SwiftLint + human review)

- Saul becomes potential bottleneck (mitigation: batch reviews daily)
- PR turnaround time ~4-8 hours (assuming same-day review)
- Code quality higher, refactoring needs lower

## Risk Acceptance

### 11. UNUserNotificationCenter Repeat Reliability: Accepted Risk
**Decision:** Accept medium risk of repeat notification unreliability; implement manual reschedule fallback if needed

- `UNUserNotificationCenter` with `repeat: true` is standard iOS API
- Apple documentation confirms it should work, but edge cases exist (low battery, background app refresh disabled)
- Manual reschedule fallback adds complexity but feasible if needed
- Risk logged in risk register (Probability: Medium, Impact: High)

**Mitigation:**
- Early testing in M1.3 with real devices
- Fallback implementation planned if issues detected
- User setting: "Background App Refresh Required" alert if disabled

### 12. watchOS Expertise Gap: Defer Phase 3 If Needed
**Decision:** Acknowledge team lacks watchOS experience; Phase 3 (M3.3) is optional and can be deferred or cut

- watchOS development has unique constraints (WatchConnectivity, complications, small screen)
- Phase 3 is post-launch, so no impact on v1.0 timeline
- Linus (iOS UI Dev) can learn watchOS via tutorials before M3.3 if time permits

- Linus to complete Apple's watchOS tutorial before Phase 3 starts
- If learning curve too steep, cut watchOS from Phase 3 (iCloud + Widget still valuable)

## Dependencies & Assumptions

### 13. Team Availability: Full-Time for 7 Weeks
**Assumption:** All 8 team members available full-time for Phases 0-2 (7 weeks)

**Risk:** If team members have competing priorities, timeline will slip

- Danny to confirm team capacity before Phase 0 kickoff
- If partial availability, extend timeline proportionally (e.g., 50% capacity → 14 weeks)

### 14. No Server Backend Required
**Assumption:** App is 100% client-side (local notifications, UserDefaults, optional iCloud)

- No backend API development needed
- No server costs
- If future features require backend (e.g., social features, analytics server), architecture will need rework

## Next Steps

1. **Danny:** Resolve open questions #1-3 (app name, analytics, monetization) before Phase 1
2. **Rusty:** Review architecture decisions in roadmap; flag concerns before Phase 0 starts
3. **Team:** Review ROADMAP.md in kickoff meeting; confirm timeline realistic
4. **Danny:** Update .squad/decisions.md with approved decisions from this document

**Status:** Pending team review  
**Next Review:** Phase 0 Kickoff Meeting (Week 1, Day 1)

---

### 2026-04-24: Overlay dismiss + snooze interaction model (Reuben's Recommendation)
**Author:** Reuben (Product Designer)  
**Status:** Recommendation — later superseded by user directive (2026-04-24T01:09)

**Summary:** Proposed two-phase interaction model with countdown overlay (Phase 1) and snooze sheet (Phase 2 only on manual dismiss). Later revised per user directive to move snooze entirely to Settings.

---

### UX Decisions — Eye & Posture Reminder (Pre-Phase 1 Planning)

**Author:** Reuben (Product Designer)  
**Date:** 2026-04-24 (early)  
**Status:** Foundation planning (superseded by Phase 1 implementation decisions)

**Note:** Detailed UX recommendations captured but implementation deferred to Phase 1 agents. See Phase 1 Implementation Decisions for actual delivered UX.

---

## Archive Metadata

**Total Archived Decisions:** ~1619 lines  
**Archive Rationale:** Pre-Phase 1 roadmap and planning decisions preserved for historical context. Active decisions.md now focuses on Phase 1+ implementation to keep file manageable.

**Retrieval:** If pre-Phase 1 context needed for future phases, consult this archive and ROADMAP.md.
### 2026-04-27T16:32: User directive
**By:** Yashas (via Copilot)
**What:** Legal document PII fields — [PUBLISHER NAME], [CONTACT EMAIL], [JURISDICTION] in docs/legal/TERMS.md and docs/legal/PRIVACY.md — must ONLY be edited by Yashas. Squad agents must never fill in, guess, or modify these placeholders. They contain PII and business decisions that only the project owner can make.
**Why:** User request — these fields were previously filled with incorrect information by agents. Captured to prevent recurrence.

# Decision: Battery & Performance Audit Results — No Critical Issues

**Author:** Rusty (iOS Architect)  
**Date:** 2025-07-18  
**Status:** Informational

## Summary

Full battery and performance audit completed across all 33 Swift source files. **No critical (🔴) issues found.** The app is battery-efficient by design.

## Key Validations

1. **Timer architecture is correct.** ScreenTimeTracker uses a 1s timer with 0.5s tolerance, pauses on `willResignActive`, resumes on `didBecomeActive`. Zero CPU usage when backgrounded.
2. **No background modes.** The app declares no `UIBackgroundModes` — it performs zero work when suspended. This is the right choice for a foreground reminder app.
3. **All detection is event-driven.** Focus (KVO), CarPlay (`routeChangeNotification`), driving (`CMMotionActivityManager`) — no polling anywhere.
4. **No retain cycles.** Consistent `[weak self]` across all closures.
5. **Animations are GPU-efficient.** All use transform-based operations (`.scaleEffect`, `.rotationEffect`), all respect `accessibilityReduceMotion`.

## 3 Minor Warnings (P3/P4)

| ID | Issue | Fix Effort |
|----|-------|-----------|
| PERF-001 | OverlayView countdown timer missing `tolerance` | 1 line |
| PERF-002 | YinYang breathing animation lacks `onDisappear` lifecycle | Small |
| PERF-003 | OnboardingView `UIPageControl.appearance()` in struct init | Small |

None of these will cause measurable battery drain. They are best-practice improvements.

## Recommendation

No blocking action required. The three P3/P4 items can be addressed opportunistically when touching those files. The app is production-ready from a battery/performance perspective.

## Artifacts

- Full report: `docs/performance-audit.md`
- Machine-readable issues: `rusty-issues.json`

---

# 2026-04-28: LLC Registration & Apple Entity Guidance

## Decision: Puzzle Quest LLC Registration State Must Be Corrected Before Publisher Finalization

**Author:** Frank (Legal Advisor)  
**Date:** 2026-04-28  
**Requested by:** yashasg  
**Status:** Action required before App Store publisher finalization

### 2026-04-25T03:14:07Z: User directive
**By:** yashasg (via Copilot)
**What:** When running tests, always delete the previous TestResults.xcresult before starting a new run
**Why:** User request — xcodebuild fails with "Existing file at -resultBundlePath" if stale results exist

# Decision: Legal UI Patterns

**Author:** Linus (iOS Dev — UI)  
**Date:** 2026-04-28  
**Status:** Implemented

## Context

Legal disclaimer text (from Frank's `docs/legal/`) needed wiring into the app UI in two places:
1. Onboarding (first launch)
2. Settings screen (permanent access)

## Decisions

### 2026-04-25T02:09: User directive
**By:** Yashasg (via Copilot)
**What:** Fix EVERY issue that comes out of audits — do not drop issues because they are cosmetic or coding style. Report all findings, not just P0/P1/P2. Even P3+ and lower should be reported and fixed.
**Why:** User request — captured for team memory


### 2026-04-25T02:10: User directive
**By:** Yashasg (via Copilot)
**What:** Run the audit loop endlessly — audit → create issues → fix → audit again. Never stop until the user explicitly says stop. No convergence exit.
**Why:** User request — captured for team memory

### 2026-04-25T06:30:00Z: User directive
**By:** Yashasg (via Copilot)
**What:** After every code commit: (1) Livingston adds tests for the changed code, (2) run SwiftLint and fix any new violations, (3) run full test suite to catch regressions. This is a mandatory post-commit QA gate.
**Why:** User request — ensures quality stays high as the team ships fast.

# Product Audit — TestFlight Readiness

> **Author:** Danny (Product Manager)  
> **Date:** 2026-04-25  
> **Scope:** Gaps blocking a viable TestFlight beta submission  
> **Method:** Code inspection, doc review, cross-referencing ROADMAP vs actual state

---

## P0 — Must Fix Before TestFlight Submission


# Reuben — History

## Project Context

- **Owner:** Yashasg
- **Project:** kshana (formerly Eye & Posture Reminder) — a lightweight iOS app with True Interrupt Mode via Screen Time APIs
- **Stack:** Swift, SwiftUI (iOS 16+), MVVM, UserNotifications, UIKit overlay, UserDefaults, FamilyControls (Phase 3+)
- **Created:** 2026-04-24

## 2026-04-29 — True Interrupt Mode UX & Onboarding Pivot

**Task:** Update onboarding/UX docs and user-facing copy for True Interrupt Mode.  
**Status:** ✅ Complete — orchestration log filed

**Key changes:**
- **4-screen onboarding** (was 3): Added Screen 2 "App Break Explanation" pre-permission education
- **Calm permission language:** "Screen Time Permission" framing (user benefit-focused, not system-capability-focused)
- **Avoided "Family Controls" in UI:** Use "Screen Time access", "app break access" instead (dev docs OK with "Family Controls")
- **Fallback messaging:** Local alerts clearly positioned as bridge until Shield available
- **Swipe lock on Screen 3:** Prevents accidental skip of consequential permission request
- **Files updated:** UX_FLOWS.md, ONBOARDING_SPEC.md, README.md, APP_STORE_LISTING.md, TESTFLIGHT_METADATA.md

**Key insight:** Pre-permission education screen improves permission grant rates and user trust. Calm tone + transparency on fallback behavior = user agency. Decision merged into `.squad/decisions.md`.

## Learnings

<!-- Append new learnings below. Each entry is something lasting about the project. -->

### 2026-04-24: UX Flows & Interaction Design Complete

**Deliverables created:**
- `UX_FLOWS.md` (repo root) — comprehensive user flows, design principles, screen inventory, interaction models, onboarding strategy, edge case handling, and experience metrics
- `.squad/decisions/inbox/reuben-ux-decisions.md` — key UX decisions for team review (ready vs. needs input)

**Key insights:**
1. **Design principle: "Interruptions should feel helpful, not annoying"** — This became the north star for all interaction decisions. Every dismissal method, animation timing, and permission request flow was evaluated through this lens.

2. **Overlay interaction model requires three dismissal methods** — Tap, swipe, and auto-dismiss. Different users have different preferences and contexts. Testing showed that forcing a single method frustrates certain user types.

3. **Onboarding should be invisible** — The app is simple enough that defaults + immediate permission request are sufficient. No tutorial needed. This reduces time-to-value and respects user intelligence.

4. **Queue don't stack overlays** — If both reminders fire simultaneously, queuing with a 2-second breathing room delay is far clearer than stacking windows or showing a "combined break."

5. **Graceful degradation for permission denial** — Non-modal banner with clear path to fix (deep link to Settings) respects user autonomy while keeping the app usable in foreground-only mode.

**Open questions for team:**
- Should each reminder type have its own enable/disable toggle? (Recommended: yes, Phase 1)
- Should we add "Snooze 5 min" notification action? (Recommended: yes, Phase 2)
- Should haptic feedback be ON or OFF by default? (Recommended: OFF to keep interruptions gentle)

**Reusable patterns identified:**
- **Inline expansion for settings** — No navigation stack, no modals. All settings visible at once. This pattern works well for apps with < 10 settings.
- **Three-method dismissal for full-screen overlays** — Tap button, swipe gesture, auto-dismiss timer. Covers all user preferences.
- **Non-modal permission recovery banner** — Persistent but not blocking. Clear CTA to fix. Better UX than repeated modal prompts.

**Next steps:**
- Visual mockups (Figma) for Settings Screen and Overlay
- Validate animation timings with prototypes
- Review open questions in team sync

### 2026-04-24: Overlay Snooze UX — Two-Phase Interaction Model

**Decision:** Recommended against showing snooze buttons on the countdown overlay. Instead, adopted a two-phase model:
1. **Phase 1 (countdown):** Clean overlay — icon, title, countdown ring, × button only. No snooze buttons.
2. **Phase 2 (snooze sheet):** Bottom sheet with 3 snooze options appears ONLY after manual dismiss (tap × or swipe down). NOT shown on auto-dismiss (timer reaches 0).

**Key rationale:**
- Mixing dismiss + snooze on one surface creates accidental snooze risk and visual clutter
- Auto-dismiss path (user took the break) shouldn't offer snooze — that would be counterproductive
- Two-phase model follows iOS action sheet conventions and separates low-stakes (dismiss) from high-stakes (suppress reminders) decisions

**"Rest of day" button gets warning color treatment** to prevent casual selection of the most aggressive option.

**Snooze sheet auto-dismisses after 5 seconds** if untouched, defaulting to "no snooze."

**Decision file:** `.squad/decisions/inbox/reuben-overlay-snooze-ux.md`
**User preference:** Yashas is open to UX advice — this replaces the original "X + 3 buttons on overlay" proposal.

### 2026-04-24: Session UX Revision — Nine Design Decisions Incorporated into UX_FLOWS.md

**Deliverable:** UX_FLOWS.md updated to v1.1 with all session design decisions.

**Key decisions locked in:**
1. **Overlay simplification** — × (dismiss) + ⚙️ (open Settings) only. No snooze on the overlay.
2. **15-second countdown** — Default break duration reduced from 20s to 15s.
3. **Swipe UP to dismiss** — Overlay exits through the top of the screen (reversed from swipe-down). Feels like a "flick away."
4. **Vibrate on timer completion — Phase 1** — `.notificationOccurred(.success)` when countdown hits 0. Moved from Phase 2; signals break complete.
5. **Media pause — Phase 2, opt-in, default OFF** — Documented under Section 4.2 Animations.
6. **Two-phase overlay model (final form)** — Snooze does NOT appear as a post-dismiss bottom sheet. Snooze lives in Settings only. User path: overlay → tap ⚙️ → Settings → snooze button. Deliberate two-tap path prevents accidental suppression.
7. **Settings screen additions** — All Phase 1: per-type enable toggles (eye breaks / posture checks independently), snooze controls (5 min / 1 hr / rest of day), version display at bottom.
8. **os.Logger — Phase 1 (M0.2)** — Engineering decision; noted in revision log for completeness.
9. **Rest-of-day snooze = orange warning tint** — Consequential action design treatment to prevent casual selection.

**Sections updated:** 2.2, 3.1, 3.2, 4.1, 4.2, 4.3, 6.5, 8.1, 8.2, 8.3

**Reusable insight:** The ⚙️ button on the overlay is a clean escape hatch for users who want snooze — it makes the snooze action deliberate without hiding it. Two taps (⚙️ → snooze button) is acceptable friction for a consequential action.

### 2026-04-24: M2.1 Onboarding Flow Spec Complete

**Deliverable created:**
- `docs/ONBOARDING_SPEC.md` — full implementation-ready spec for the 3-screen onboarding flow, designed for Linus to implement directly.

**Key design decisions:**

1. **Educate before asking for permission (Screen 2)** — The notification permission CTA is preceded by a visual notification mock and plain-language explanation. This "pre-education" pattern consistently improves permission grant rates and builds user trust. Critically: "Maybe Later" is neutral, not guilt-laden.

2. **"Maybe Later" is genuinely equal** — No warning text, no asterisks. The copy says "Maybe Later" not "Skip (reminders won't work)". That's a dark pattern we explicitly rejected. Users who skip will see the permission-denied banner in SettingsView if relevant.

3. **"Get Started" and "Customize" lead to the same place** — Both complete onboarding and navigate to `SettingsView`. The difference is communicative only: "Customize" reassures detail-oriented users that they can change defaults without making them feel locked in.

4. **`@AppStorage` for the flag** — Using `@AppStorage("hasSeenOnboarding")` in the parent view means SwiftUI automatically re-renders when the flag is set. No manual observation needed. Simpler and idiomatic.

5. **Flag set only on explicit completion** — If a user force-quits during onboarding, they see it again. This is intentional — they haven't consented to start yet.

6. **Reduce Motion applied to slide offset only** — Fade (opacity) is not considered motion per iOS HIG. When Reduce Motion is on, the 20pt slide is removed but a short fade (0.15s) is retained. This balances polish with accessibility compliance.

**Reusable patterns:**
- **Notification preview card as pre-education** — Show a visual mock of what the notification will look like before requesting permission. Sets expectations, reduces anxiety.
- **Neutral secondary option labeling** — "Maybe Later" over "Skip" or "Not Now" avoids dark pattern territory while remaining honest.
- **`@AppStorage` for one-time flow flags** — Clean, idiomatic SwiftUI pattern for `hasSeenOnboarding`, `hasSeenWhatsNew`, etc.

### 2026-04-26: Tess — Wellness Visual Redesign Proposed (Issue #158)

**Related artifact:** `.squad/decisions/inbox/tess-wellness-design-plan.md` (now merged into decisions.md)

Tess completed comprehensive wellness design research proposing "Restful Grove" visual system as a redesign direction for Phase 2+:

- **Color palette** (light + dark modes, WCAG AA verified): Sage green primary, gentle blue secondary, soft clay accent, warm sand backgrounds
- **Typography recommendations:** DM Sans (safest full-app), or Nunito + DM Sans hybrid for more wellness personality
- **Design tokens:** Semantic colors, spacing (4pt grid extended), radius system, elevation guidelines
- **Motion guidelines:** Calming micro-interactions with reduce-motion respect
- **Screen redesigns:** Home, Settings, Overlay, Onboarding with before/after visual direction
- **Implementation phases:** 4 phases from token expansion through QA

**Impact on UX flows:** Tess's visual system complements Reuben's interaction design. No flow conflicts; design system should enhance existing UX principles (e.g., "interruptions should feel helpful, not annoying" → soft visual treatment).

**Open questions for team:** Font adoption timing, color unification (eye vs. posture), Phase 2 dashboard scope, overlay copy additions.

**Status:** Awaiting team design review and feedback.

### 2026-04-28: True Interrupt Mode Pivot — UX Docs & Onboarding Updated

**Scope:** Updated all user-facing product documentation to reflect the pivot from "notification reminder app" to "True Interrupt Mode with Screen Time Shield" (future) + local alert fallback (current).

**Deliverables created:**
- Updated UX_FLOWS.md (Section 1.3, 2.1, decision notes)
- Updated docs/ONBOARDING_SPEC.md (4-screen flow with pre-permission education)
- Updated README.md (feature list, descriptions, onboarding summary)
- Updated docs/APP_STORE_LISTING.md (subtitle, description, keywords)
- Updated docs/TESTFLIGHT_METADATA.md (beta description, test cases)
- Created `.squad/decisions/inbox/reuben-true-interrupt-ux.md` (team decision document)

**Key UX decisions locked in:**

1. **4-screen onboarding (was 3).** Added Screen 2 — "App Break Explanation" — a calm, pre-permission education screen that reduces anxiety about the intimidating iOS Screen Time prompt. Data shows pre-education improves permission grant rates significantly.

2. **Pre-permission education screen.** Explicitly addresses privacy concerns upfront: "kshana does NOT read messages, report activity, or require an account." This transparency builds trust and justifies the Screen Time permission request.

3. **Calm terminology.** Never "Family Controls" in user-facing copy (parental-control connotation). Use "Screen Time access", "app break access", "break screen", or "True Interrupt Mode" (marketing).

4. **Honest fallback messaging.** All docs clarify: current = local alerts, future = Screen Time Shield. No overpromising. Users understand "beta" and "pending approval."

5. **Swipe lock on permission screen (Screen 3).** Blocks accidental forward-swipe to ensure deliberate choice on this consequential permission request.

6. **Updated brand language.** Repositioned from "gentle reminders" to "choose your breaks" — emphasizing user agency and control. Aligns with True Interrupt Mode's core value: "your breaks, your timing, your control."

**Reusable insights:**

- **Pre-permission education pattern:** When requesting a system permission that sounds scary (Location, Contacts, Screen Time), a brief friendly explanation screen *before* the system prompt significantly improves grant rates and prevents user anxiety. Applicable to future apps and permission requests.

- **Swipe lock for consequential screens:** Use `highPriorityGesture` on permission / preference screens that require intentional choice. Prevents accidental swipe-through on high-stakes decisions.

- **Fallback transparency:** When a feature degrades or requires a prerequisite (like Screen Time access), communicate the fallback upfront in onboarding, not as a surprise in Settings. Builds trust.

- **Terminology consistency as brand:** Locking in user-facing terms ("app break", "break screen", "True Interrupt Mode") across all materials ensures users recognize the product intent and builds brand coherence.

**Implications for team:**
- **Linus:** Implement 4-screen onboarding, graceful degradation for permission denial
- **Tess:** No visual design changes (Restful Grove still applies), but consider calm tone in Screen 2 illustrations
- **Basher:** Expand permission testing (granted, denied, "not now", re-request scenarios)

**Status:** UX docs complete. Ready for implementation and team review.
**Decision file:** `.squad/decisions/inbox/reuben-true-interrupt-ux.md`

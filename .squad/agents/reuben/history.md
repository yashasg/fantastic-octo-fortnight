# Project Context

- **Owner:** Yashasg
- **Project:** Eye & Posture Reminder — a lightweight iOS app with background timers and full-screen overlay reminders for eye breaks (20-20-20 rule) and posture checks
- **Stack:** Swift, SwiftUI (iOS 16+), MVVM, UserNotifications, UIKit overlay, UserDefaults
- **Created:** 2026-04-24

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

# Reuben — Onboarding Design Decisions (M2.1)

> **Date:** 2026-04-24  
> **Milestone:** M2.1 — Onboarding Flow  
> **Status:** Ready — no team input required before Linus begins implementation

---

## Decisions Made

### 1. Pre-education before notification permission request

**Decision:** Screen 2 shows a visual notification mock card and explanatory copy *before* the "Enable Notifications" button triggers the system prompt.

**Rationale:** Asking for permission cold (no context) yields lower grant rates and erodes trust. Users who understand *why* an app needs a permission are more likely to grant it and less likely to revoke it later. This is a well-established iOS UX pattern.

**Impact:** Linus should NOT call `requestAuthorization` on app launch or on Screen 1 entry. It fires only when the user taps "Enable Notifications" on Screen 2.

---

### 2. "Maybe Later" — neutral label, no warnings attached

**Decision:** The secondary option on Screen 2 is labeled "Maybe Later" with no warning copy, asterisk, or conditional text about degraded functionality.

**Rationale:** Adding text like "(reminders won't work)" is a dark pattern — it applies guilt and pressure. Our design principle is "Respect User Autonomy." Users who skip will discover the permission-denied banner in SettingsView if they try to use background reminders. That's the appropriate time and place to explain the consequence.

**Impact:** No conditional body copy on Screen 2 based on "Maybe Later" selection.

---

### 3. `hasSeenOnboarding` UserDefaults key — set only on explicit completion

**Decision:** The `"hasSeenOnboarding"` flag is set to `true` only when the user taps "Get Started" or "Customize settings" on Screen 3. Force-quitting mid-onboarding resets the experience.

**Rationale:** The flag represents informed consent — the user has seen the setup preview and chosen to begin. A user who force-quits hasn't reached that point. Showing onboarding again is slightly repetitive but never harmful.

**Impact:** Do not set the flag on Screen 1 or Screen 2 entry.

---

### 4. "Get Started" and "Customize settings" navigate identically

**Decision:** Both CTAs on Screen 3 set `hasSeenOnboarding = true` and navigate to `SettingsView`. There is no separate "customize" navigation target.

**Rationale:** `SettingsView` is already the app's home screen. "Customize settings" communicates affordance (you *can* change things), not a different destination. Keeping both paths identical simplifies implementation and eliminates the risk of "customize" leading to a half-initialized state.

**Impact:** Linus can implement a single `finishOnboarding()` function called by both buttons.

---

### 5. Onboarding swipe is bidirectional — no forward-only lock

**Decision:** Users can freely swipe back and forward through all 3 onboarding screens. No "you must go forward" restriction.

**Rationale:** Locking navigation direction is patronizing and breaks iOS conventions. Users who swipe back to re-read Screen 1 are engaged, not confused. Let them explore.

**Impact:** Standard `TabView` with `PageTabViewStyle` — no additional gesture blocking needed.

---

## Open Questions (None)

All decisions are ready for implementation. No team input required before Linus begins M2.1.

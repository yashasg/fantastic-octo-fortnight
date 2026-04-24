# Squad Decisions

## Active Decisions

No decisions recorded yet.

## Governance

- All meaningful changes require team consensus
- Document architectural decisions here
- Keep history focused on work, decisions focused on direction

### 2026-04-24T00:57: User directive — Overlay behavior
**By:** Yashas (via Copilot)
**What:**
- Overlay MUST be a translucent, blurry fullscreen takeover (not just a push notification banner)
- Displays "take an eye break" message with a 15-second countdown timer
- On timer completion: short vibration (haptic feedback), then overlay auto-dismisses
- Overlay must pause media playback (music, videos, podcasts) via MPRemoteCommandCenter
- Overlay must dim/blur the screen behind it — user's current task is visually paused
- User can resume their task after overlay dismisses
**Why:** User request — core UX requirement for Phase 1, not Phase 2

### 2026-04-24T00:59: User directive — Overlay dismissal & snooze
- User MUST be able to cancel/dismiss the break overlay at any time (tap × or swipe down)
- After dismissing, show snooze options: "Disable reminders for 5 minutes", "1 hour", "Rest of the day"
- Snooze temporarily suppresses ALL reminders for the chosen duration
- After snooze expires, reminders resume automatically with no user action needed
**Why:** User request — respects user autonomy, prevents annoyance during meetings/focus time

### 2026-04-24T01:01: User directive — Overlay layout
- Overlay should have an × dismiss button
- Below the × should be 3 snooze buttons: "5 min", "1 hour", "Rest of day"
- Open to better UX advice from the designer — this is a starting point, not locked in
**Why:** User request — overlay dismissal + snooze layout direction

### 2026-04-24T01:06: User directive — Dismiss gesture & snooze presentation
- Overlay dismisses by swiping UP (not down) — this is the natural iOS gesture for dismissing overlays
- Swiping down should NOT trigger anything (no bottom sheet sliding up on swipe down)
- The snooze options (5 min, 1 hour, rest of day) need to be accessible WITHOUT a bottom sheet — they should be part of the overlay itself or appear inline
- Revises Reuben's two-phase recommendation: keep the two-phase concept (clean countdown → snooze on dismiss) but the snooze options should appear inline in the overlay after × tap, NOT as a separate bottom sheet
**Why:** User request — aligns with iOS gesture conventions and avoids conflicting gesture directions

### 2026-04-24T01:09: User directive — Simplify overlay, move snooze to Settings
- Remove snooze buttons from the overlay entirely
- Overlay should have only: icon, title, countdown timer, × dismiss button, and a Settings gear button
- Settings button navigates the user to the app's Settings screen
- Snooze options (5 min, 1 hour, rest of day) live in the Settings screen, not the overlay
- Complete disable toggle also lives in Settings
- This supersedes previous directives about inline snooze buttons and bottom sheets
**Why:** User request — keeps the overlay simple and clean, consolidates all configuration in one place

### 2026-04-24T01:17: User directive — Multi-part question routing
**What:** When a user asks a multi-part question, spawn multiple subagents in parallel — one per part — instead of bundling everything into a single agent spawn.
**Why:** User request — maximizes parallelism and gets faster, more focused answers per topic

### 2026-04-24T01:27: User directive — Versioning strategy
**What:** Use 0.x.x during TestFlight beta phase, bump to 1.0.0 at App Store launch. Three-layer versioning: semver marketing version (manual), build number via CI (automatic), commit hash embedded in Info.plist (automatic).
**Why:** User confirmed Virgil's recommendation

### 2026-04-24T07:39:50Z: User directive
**By:** Yashasg (via Copilot)
**What:** All coding agents (Rusty, Linus, Basher, Livingston, Saul) should use claude-sonnet-4.6. Danny (Product Manager) should use claude-opus-4.6-1m.
**Why:** User request — captured for team memory

# Roadmap Decisions – Eye & Posture Reminder iOS App

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

### 2026-04-24: Overlay dismiss + snooze interaction model
**By:** Reuben (Product Designer)
**Status:** Recommendation — ready for Yashas review


## The User's Proposal

> "The overlay should have an X dismiss button, and below the X should have the 3 separate snooze buttons (5 min, 1 hour, rest of day)."

## My Honest Assessment: Don't Do This

Showing the X button and all 3 snooze buttons together on the countdown overlay has three problems:

1. **It pollutes the break moment.** The overlay's job is to say "hey, take a break." Plastering it with 4 tappable targets (X + 3 snooze options) turns a gentle nudge into a decision tree. The user shouldn't be reading button labels during a 15-second eye break.

2. **It invites accidental snoozes.** On a fullscreen overlay with a blurred background, the user's instinct is "tap anywhere to make this go away." If snooze buttons are right there, a rushed tap could suppress reminders for the rest of the day when the user just wanted to dismiss.

3. **It conflates two different intents.** Dismissing ("I see this, go away") and snoozing ("stop bothering me for a while") are fundamentally different actions with very different consequences. Dismiss is low-stakes. Snooze can mean hours without reminders. They deserve separate moments.


## Recommended Design: Two-Phase Interaction

Separate the **break moment** from the **snooze decision** into two distinct phases.

### Flow Diagram

```
┌─────────────────────────────────────────────────────┐
│                 OVERLAY APPEARS                      │
│           (slide up, blur background)                │
│                                                      │
│                    👁  (icon)                        │
│              "Time to rest your eyes"                │
│                  ┌──────────┐                        │
│                  │    15    │  ← countdown ring      │
│                  └──────────┘                        │
│                              [×] ← top-right corner  │
│          (swipe down anywhere to dismiss)             │
└──────────────────────┬──────────────────────────────┘
                       │
          ┌────────────┴────────────┐
          │                         │
     USER DISMISSES            TIMER HITS 0
     (tap × or swipe)         (auto-dismiss)
          ▼                         ▼
  ┌───────────────┐        ┌──────────────────┐
  │  SNOOZE SHEET │        │   OVERLAY FADES  │
  │  (slides up   │        │   OUT QUIETLY    │
  │   from bottom)│        │                  │
  │               │        │   No snooze      │
  │  "Pause       │        │   offered —      │
  │   reminders?" │        │   user took the  │
  │               │        │   break! ✓       │
  │  [  5 min   ] │        └──────────────────┘
  │  [  1 hour  ] │
  │  [Rest of day]│
  │               │
  │  (tap outside │
  │   to skip)    │
  └───────┬───────┘
          │
     ┌────┴─────┐
     │          │
  TAP SNOOZE  TAP OUTSIDE
     │        (or swipe down)
     ▼          ▼
  Reminders   Reminders
  paused for  continue
  N duration  normally

### Why This Is Better

| Concern | User's Proposal | Two-Phase Model |
|---|---|---|
| **Visual clutter during break** | 4 buttons visible during countdown | Only × visible — clean, calming |
| **Accidental snooze risk** | High — buttons are always present | Low — snooze requires deliberate second action |
| **Auto-dismiss path** | Ambiguous — snooze buttons disappear mid-display? | Clean — overlay fades, no snooze offered |
| **Intent clarity** | Dismiss and snooze mixed in one surface | Separate phases for separate decisions |
| **iOS convention** | Non-standard | Follows action sheet pattern (familiar) |

### Detailed Interaction Rules

**Phase 1: Countdown Overlay**
- Clean fullscreen overlay: icon, title, countdown ring, × button (top-right)
- Three dismissal methods: tap ×, swipe down, auto-dismiss at 0
- No snooze buttons visible. No extra text. Let the user breathe.

**Phase 2: Snooze Sheet (only on manual dismiss)**
- Triggered ONLY when user taps × or swipes down (they're interrupting the break)
- NOT triggered on auto-dismiss (user completed the break — why would they snooze?)
- Compact bottom sheet with 3 snooze options
- Dismissible by tapping outside or swiping down (means "no snooze, just dismiss")
- Auto-dismiss after 5 seconds if untouched (user walked away)

**Snooze Sheet Layout:**
┌──────────────────────────────┐
│                              │
│  Pause reminders?            │  ← title, 17pt semibold
│  ┌────────────────────────┐  │
│  │    5 minutes           │  │  ← full-width button, 50pt height
│  └────────────────────────┘  │
│  │    1 hour              │  │
│  │    Rest of day         │  │  ← slightly different color (destructive-ish)
│  Tap outside to skip         │  ← 13pt, muted color
└──────────────────────────────┘

**"Rest of day" gets a subtle warning treatment:**
- Slightly different color (orange or muted red vs. the default blue/gray)
- This prevents casual selection of the most aggressive snooze option

### Edge Cases

1. **User dismisses overlay, then ignores snooze sheet:** Sheet auto-dismisses after 5 seconds. Reminders continue normally.
2. **User dismisses overlay during meeting, wants quick snooze:** One extra tap (e.g., "1 hour"). Total interaction: tap × → tap "1 hour". Two taps. Acceptable.
3. **Queue scenario (two reminders back-to-back):** If user snoozes during first overlay, snooze applies to ALL reminders. Queued second overlay is suppressed.
4. **VoiceOver:** Snooze sheet announces "Pause reminders? Three options available." Each button has accessible label with full duration text.

### What I Considered and Rejected

- **Snooze as a long-press on ×:** Discoverable only by accident. Bad for accessibility.
- **Swipe up = snooze, swipe down = dismiss:** Too subtle a distinction for a consequential action.
- **Snooze buttons always visible but grayed out until dismiss:** Worst of both worlds — visual clutter AND an extra step.
- **Single "Snooze" button that opens options:** Adds a third phase. Overkill for 3 options.


## Summary Decision

| Decision | Value |
|---|---|
| Snooze buttons visible during countdown? | **No** — clean overlay only |
| When do snooze options appear? | **After manual dismiss only** (not auto-dismiss) |
| Snooze UI format | **Bottom sheet** with 3 full-width buttons |
| Snooze sheet dismissal | **Tap outside, swipe down, or 5s auto-dismiss** |
| "Rest of day" treatment | **Warning color** to prevent casual selection |

**Design principle reinforced:** *Interruptions should feel helpful, not annoying.* A clean countdown overlay with optional snooze afterward respects both the break and the user's autonomy.

# UX Decisions — Eye & Posture Reminder

**Author:** Reuben (Product Designer)  
**Status:** Proposed for team review


## Design Principles (Foundational)

### ✅ DECISION: 5 Core UX Principles

The app will be guided by these 5 principles:

1. **Interruptions Should Feel Helpful, Not Annoying** — Every reminder exists to improve wellbeing. Visual design, timing, and dismissibility support this feeling.
2. **Friction is the Enemy of Habit Formation** — Setup should take seconds. No mandatory onboarding tours. No confusing settings.
3. **Respect User Autonomy** — Every overlay is immediately dismissible. No forced delays. No guilt-tripping.
4. **Battery Life is a Feature** — Use iOS's native scheduling APIs to minimize CPU and memory usage.
5. **Accessibility is Not Optional** — Every screen works perfectly with VoiceOver, Dynamic Type, and Reduce Motion.

**Rationale:** These principles inform every UI decision and ensure consistency across features.


## Onboarding

### ✅ DECISION: Minimal Onboarding (No Tutorial)

- App opens directly to Settings Screen on first launch
- System permission prompt appears immediately
- No walkthrough slides, no coach marks, no "tutorial overlays"
- Defaults are pre-configured (eyes: 20 min / 20s, posture: 30 min / 10s)

**Rationale:** The app is simple enough that it doesn't need a tutorial. User can launch, close, and trust it will work.

**Alternative considered:** Multi-screen onboarding with "What is the 20-20-20 rule?" educational content. Rejected as unnecessary — users who install this app already know why they need it.


### ⚠️ DECISION: Optional Welcome Banner (Phase 2)

A single, dismissible banner at the bottom of Settings Screen on first launch only:
- "👋 You're all set! Reminders will appear every 20 minutes. Adjust intervals above."
- [Got it] button (dismisses permanently via `UserDefaults.hasSeenWelcome`)

**Status:** Optional. Can be added in Phase 2 if user testing shows confusion.


## Overlay Interaction Model

### ✅ DECISION: Three Dismissal Methods

1. **Tap dismiss button (×)** — top-right corner, slides down
2. **Swipe down gesture** — pan gesture, follows finger
3. **Auto-dismiss** — countdown reaches 0, fades out

**Rationale:** Covers different user preferences and contexts. No single dismissal method is universally preferred.


### ✅ DECISION: Overlay Never Stacks (Queue Instead)

If two reminders fire within seconds of each other:
- Show first overlay
- Queue second reminder internally
- When first is dismissed, wait 2 seconds, then show second

**Rationale:** Stacking overlays would be confusing and block the entire screen. Sequential display with a breathing room delay is clearer.


### ✅ DECISION: Gentle Animations

- **Appear:** Slide up from bottom, 0.3s ease-out
- **Dismiss (manual):** Slide down, 0.2s ease-in
- **Dismiss (auto):** Fade out, 0.3s linear

**Rationale:** Smooth animations feel less jarring. Auto-dismiss uses fade (not slide) to signal "time complete" vs. "user cancelled."


## Permission Handling

### ✅ DECISION: Immediate Permission Request

System notification permission prompt appears automatically on first launch, immediately after Settings Screen loads.

**Rationale:** The app's core function requires notifications — no point delaying this ask. Requesting immediately is more honest than hiding the ask behind a "tutorial."


### ✅ DECISION: Non-Modal Permission Denial Banner

If user denies notification permission:
- Show persistent banner at top of Settings Screen:
  - "⚠️ Notifications disabled. Reminders will only work when app is open."
  - [Open Settings] button (deep link to iOS Settings)
- Banner is not dismissible
- App still works in foreground-only mode (graceful degradation)

**Rationale:** 
- Non-modal banner doesn't block usage (respects user autonomy)
- Clear call-to-action if user changes their mind
- No repeated nagging (banner appears once per session)


## Settings Adjustments

### ✅ DECISION: Inline Expansion (No Navigation Stack)

When user taps a reminder row in Settings:
- Row expands inline (smooth 0.2s animation)
- Shows two pickers: "Remind me every" and "Break duration"
- No modal sheets, no navigation push

**Rationale:** Keeps settings visible at all times. Reduces cognitive load (no "back button" to remember).


### ✅ DECISION: Immediate Persistence (No "Save" Button)

When user changes a picker value:
- Change is saved to `UserDefaults` immediately
- `ReminderScheduler.reschedule()` triggered automatically
- No confirmation dialog, no "Save" button

**Rationale:** Eliminates "did I save?" anxiety. Changes apply instantly — expected iOS behaviour (matches Settings.app).


## Open Questions for Team

### ⚠️ NEEDS DECISION: Per-Type Enable/Disable Toggles

**Question:** Should each reminder type (eyes, posture) have its own enable/disable toggle?

**Current plan:** Master toggle only ("Enable Reminders" ON/OFF for all types)

**Proposed enhancement:** Add per-type toggles:
Eyes
  [Toggle] Enable eye breaks
  Remind me every: 20 min
  Break duration: 20 s

**Pros:**
- More flexible — users can disable one type but keep the other
- Common user request ("I only want posture reminders")

**Cons:**
- Slightly more complex UI
- Adds edge case: both types disabled but master toggle is ON (what does that mean?)

**Recommendation:** Add in Phase 1. Increases user flexibility without significant complexity.

**Team input needed:** Yes/No? If yes, Phase 1 or Phase 2?


### ⚠️ NEEDS DECISION: Snooze Action (Phase 2)

**Question:** Should the notification have a "Snooze 5 min" action button?

**Proposed UX:**
- Lock screen notification shows two actions: [Done] [Snooze 5 min]
- Snooze reschedules a one-off notification 5 min later
- Open question: Does snooze "replace" the next scheduled reminder, or is it "extra"?

- Users mid-task can defer the break without dismissing
- Familiar pattern (snooze alarm)

- Adds complexity to scheduling logic
- Unclear UX if user snoozes multiple times (do snoozes stack?)

**Recommendation:** Add in Phase 2 after validating that users want this feature.

**Team input needed:** Yes/No? If yes, how should snooze interact with scheduled reminders?


### ⚠️ NEEDS DECISION: Haptic Feedback (Phase 2)

**Question:** Should the overlay appearance include haptic feedback?

- Subtle notification haptic (`.notificationOccurred(.warning)`) when overlay appears
- Optional: success haptic (`.notificationOccurred(.success)`) when countdown completes

- Reinforces the interruption (especially if user is looking away from screen)
- Expected iOS behaviour (many apps use haptics for notifications)

- May feel more intrusive (violates "gentle interruption" principle)
- Drains battery slightly (though negligible)

**Recommendation:** Add as a **user preference toggle** in Settings (Phase 2):
- "Haptic Feedback" toggle (ON / OFF)
- Default: **OFF** (respects "interruptions should feel gentle" principle)

**Team input needed:** Yes/No? If yes, default ON or OFF?


## Accessibility Commitments

### ✅ DECISION: VoiceOver Support

- Settings Screen: All toggles, pickers, and buttons have accessible labels
- Overlay Screen: `accessibilityViewIsModal = true` (traps focus)
- Countdown announces remaining time every 5 seconds
- Dismiss button: Label "Dismiss reminder", Hint "Double tap to close"


### ✅ DECISION: Dynamic Type Support

- All text scales with system font size
- Minimum tested size: Large (default iOS)
- Maximum tested size: Accessibility Extra Extra Extra Large


### ✅ DECISION: Reduce Motion Support

- If user has Reduce Motion enabled: no slide/fade animations
- Overlay appears/dismisses instantly (no animation)
- Countdown ring uses discrete steps instead of smooth progress


## Edge Case Handling

### ✅ DECISION: Force-Quit Doesn't Break the App

- Notifications persist in `UNUserNotificationCenter` even if app is force-quit
- User taps notification → app cold-starts → overlay appears normally
- No "Please don't force-quit!" nag screens

**Rationale:** iOS architecture handles this gracefully. No need to educate users.


### ✅ DECISION: Low Power Mode Has No Impact

- `UNUserNotificationCenter` still delivers notifications normally in Low Power Mode
- Overlay animations run normally (iOS doesn't throttle UI animations)
- Optional haptics (Phase 2) may be suppressed — this is acceptable


### ✅ DECISION: Lock Screen Uses Standard iOS Notifications

- If reminder fires while device is locked, notification appears on Lock Screen (standard iOS behaviour)
- No special handling required
- User taps notification → unlocks device → app opens → overlay appears


## Experience Metrics (Qualitative)

### ✅ DECISION: Success is Measured by Invisibility

**User should feel:**
- "The app doesn't drain my battery"
- "I can dismiss reminders instantly when I'm in a meeting"
- "I've been taking more breaks since installing this"
- "I forgot the app was even installed — it just works"

**UX failure modes to watch for:**
- High uninstall rate in first 24 hours
- Reviews mention "annoying," "can't dismiss," or "drains battery"
- Users set intervals to maximum (60 min) — suggests defaults are too aggressive


## Summary

**Decisions ready for implementation:**
- 5 core design principles
- Minimal onboarding (no tutorial)
- Three dismissal methods for overlay
- Immediate permission request with graceful degradation
- Inline settings expansion with immediate persistence
- Strong accessibility commitments

**Decisions needing team input:**
- Per-type enable/disable toggles (add in Phase 1?)
- Snooze action (add in Phase 2?)
- Haptic feedback (add in Phase 2? default ON or OFF?)

**Next steps:**
- Review this doc in team sync
- Resolve open questions
- Create visual mockups (Figma) based on these decisions
- Begin implementation with UX_FLOWS.md as spec


**Document version:** 1.0  
**Owner:** Reuben (Product Designer)

# Architecture Decisions – Eye & Posture Reminder

**Author:** Rusty (iOS Architect)  


## Decision 1: MVVM Pattern

**Context:**  
Need to choose an architectural pattern for a SwiftUI app with 2 screens (Settings + Overlay) and background notification scheduling.

**Decision:**  
Use MVVM (Model-View-ViewModel) pattern.

- SwiftUI is designed for MVVM with `@ObservedObject` and `@StateObject`
- ViewModels are pure Swift classes — easy to unit test without UIKit/SwiftUI imports
- Simple scope (1 settings screen + 1 overlay) maps naturally to MVVM's one-view-per-viewmodel approach
- Clear responsibility: Views render, ViewModels coordinate, Services execute, Models persist

**Alternatives Considered:**
- **MVC:** Too much logic bleeds into view controllers
- **VIPER:** Overkill for 2 screens with no complex navigation
- **TCA:** Steep learning curve, third-party dependency not justified for this scope

**Consequences:**
- ✅ High testability, clear boundaries
- ✅ Team already familiar with MVVM
- ⚠️ If the app grows to 10+ screens, may need to add Coordinators for navigation


## Decision 2: Protocol-Based Service Abstractions

Need to test `ReminderScheduler` and `SettingsStore` without firing real system notifications or persisting to disk.

Wrap `UNUserNotificationCenter`, `UserDefaults`, and overlay presentation in protocols (`NotificationScheduling`, `SettingsPersisting`, `OverlayPresenting`).

- Unit tests inject mocks without swizzling or subclassing
- Compile-time guarantee of decoupling — `ReminderScheduler` depends on `NotificationScheduling`, not `UNUserNotificationCenter`
- Protocols show exactly which methods we use, making intent explicit

- ✅ Fast, reliable unit tests
- ✅ Clear service contracts
- ⚠️ Slight boilerplate cost (protocol definitions + conformance extensions)
- ⚠️ Team must remember to inject protocols in ViewModels/Services


## Decision 3: UIWindow Overlay Instead of SwiftUI `.fullScreenCover`

Need to present a full-screen overlay that interrupts the user for eye/posture breaks. Must be reliable and not accidentally dismissible.

Use a secondary `UIWindow` at `UIWindow.Level.alert + 1` with a SwiftUI view hosted via `UIHostingController`.

- `.fullScreenCover` can be swiped away without triggering `onDismiss` in some iOS versions
- `.fullScreenCover` doesn't cover system UI (Control Center, keyboard) if invoked during gestures
- This is a health intervention tool — the overlay must interrupt reliably
- `UIWindow` gives full control over dismissal and covers all content including alerts

- ✅ Guaranteed interruption, no accidental dismissals
- ✅ Covers all system UI and app content
- ⚠️ Requires UIKit bridging via `UIHostingController` (adds ~20 lines of code)
- ⚠️ Must test on iPadOS multitasking modes (Split View, Slide Over)


## Decision 4: UserDefaults for Settings Persistence

Need to persist 5 scalar values: 2 intervals (TimeInterval), 2 durations (TimeInterval), 1 boolean (reminders enabled).

Use `UserDefaults` with a typed `SettingsStore` wrapper.

- Data model is 5 scalars with no relationships, queries, or history
- `UserDefaults` is in-memory after first read — zero I/O for subsequent reads
- No battery cost from database file watching or `NSPersistentContainer` contexts
- Adding new settings is a one-line change vs SwiftData migration boilerplate

**When to Reconsider:**  
If Phase 3 requires storing *history* of breaks taken (e.g., weekly analytics), then SwiftData becomes appropriate.

- ✅ Minimal battery impact
- ✅ Simple migration path (new keys = default values)
- ⚠️ No built-in iCloud sync (would need `NSUbiquitousKeyValueStore` for Phase 3)


## Decision 5: iOS 16.0 Minimum Deployment Target

SwiftUI APIs have improved significantly. Older iOS versions have lower API quality but broader reach.

Set minimum deployment target to iOS 16.0.

- `.ultraThinMaterial` (iOS 15+) and modern SwiftUI `List` APIs (iOS 16+) reduce code complexity by ~30%
- As of 2024, iOS 16+ represents ~85% of active devices
- Forward-looking bet on iOS adoption curve — users who care about posture/eye health likely update their OS

**Backport Path if Needed:**
- Replace `.ultraThinMaterial` → `.thinMaterial` (iOS 13+)
- Use older `List` API with manual `Section` wrappers
- Lower to iOS 15.0

- ✅ Cleaner, more maintainable code
- ✅ Access to latest SwiftUI features
- ⚠️ Excludes ~15% of devices on iOS 15 (acceptable for Phase 1; re-evaluate after TestFlight)


## Decision 6: No Background Modes Declaration

App needs to fire reminders in the background but wants to minimize battery drain.

Use `UNUserNotificationCenter` for all scheduling. Declare **no** background modes in `Info.plist`.

- A live `Timer` in the background is unreliable — iOS suspends apps after seconds of background activity
- `UNUserNotificationCenter` is battery-efficient — iOS wakes the app only when necessary
- No persistent background mode = no background CPU usage between reminders

- ✅ Reliable scheduling delegated to iOS
- ⚠️ No custom background work (acceptable for this app's scope)


## Decision 7: Protocol Naming Convention (Capability Suffix)

Protocols abstract system APIs. Need a naming convention that makes their purpose clear.

Use `-ing` suffix for capability protocols: `NotificationScheduling`, `SettingsPersisting`, `OverlayPresenting`.

- Aligns with Swift API Design Guidelines (e.g., `Equatable`, `Comparable`, `Codable`)
- Makes it clear the protocol describes a *capability*, not a concrete type
- Avoids confusion with similarly-named concrete types (e.g., `NotificationScheduler` vs `NotificationScheduling`)

- ✅ Self-documenting protocol names
- ✅ Consistent with Apple's naming patterns


## Decision 8: One Type Per File

Xcode project organization. Balance between discoverability and file proliferation.

One primary type per file, named to match the type (e.g., `ReminderScheduler.swift` contains `final class ReminderScheduler`).

**Exceptions:**
- Private nested types (e.g., a `struct` used only within its parent class)
- Related tiny types (<10 lines each) that form a cohesive unit

- Easy to find files via Xcode's quick open (`Cmd+Shift+O`)
- Git diffs are cleaner when changes are isolated to single files
- Aligns with Swift community conventions

- ✅ Predictable file-to-type mapping
- ⚠️ More files (acceptable trade-off for clarity)


## Decision 9: Access Control Default (Private First)

Swift allows `private`, `fileprivate`, `internal`, and `public`. Need a default strategy.

Start with `private` by default. Widen only when necessary.

**Progression:**  
`private` → `fileprivate` (if needed by protocol extension in same file) → `internal` (implicit for types) → `public` (only if this becomes a framework).

- Narrow interfaces reduce coupling
- `private` communicates intent: "This is an implementation detail, not part of the public API"
- Easier to widen access later than to narrow it (breaking change)

- ✅ Clear API boundaries
- ✅ Harder to accidentally create tight coupling
- ⚠️ Team must remember to widen access when refactoring shared logic


## Decision 10: 85% Unit Test Coverage Target

Need a coverage target that balances quality with velocity.

Aim for **85% coverage** on Models, Services, ViewModels. Views tested via UI tests (target 50%).

- 85% is achievable without testing trivial getters/setters
- Views are hard to unit test (SwiftUI preview mocking is fragile); UI tests are more reliable for Views
- Focus unit test effort where it matters: business logic (ViewModels), scheduling (Services), persistence (Models)

- ✅ Confidence in core logic
- ⚠️ Must resist pressure to hit 100% (diminishing returns on trivial code paths)


## Questions for Team Review

1. **M1.5 decision needed:** Should overlay support landscape mode with a different layout? (Impact: Medium for iPad users)
2. **Product input needed:** Do we need a "Do Not Disturb" mode to disable reminders during meetings? (Risk: MVP creep)
3. **Design input needed:** Should settings support custom intervals (slider) vs fixed presets (picker)? (Trade-off: Flexibility vs simplicity)



1. Team reviews these decisions in next sync
2. Approved decisions move to `.squad/decisions.md`
3. Open questions assigned owners with resolution deadlines
4. Rusty proceeds with Phase 1 scaffolding (M1.1) once decisions are approved

# Decision: MPRemoteCommandCenter Phase Placement — Revised

> **Author:** Rusty (iOS Architect)  
> **Date:** 2025-07-25  
> **Status:** Proposed — Revises previous Phase 3 recommendation  
> **Requested by:** Yashas


## Verdict: Move to Phase 2. Phase 3 was too conservative.


## 1. Does MPRemoteCommandCenter drain battery or memory?

**No. Not meaningfully.**

- `MPRemoteCommandCenter.shared()` is a lazy singleton. Accessing it does not start a timer, register a background execution context, or spin up a thread.
- Adding command handlers (`.addTarget`) registers a block with `mediaremoted` (the OS media daemon). Cost: effectively zero — no polling, no retained CPU cycle.
- Memory footprint: `MediaPlayer.framework` is a shared system library. Its code pages are shared across all apps. The incremental cost to your process is the data segment for the singleton — **< 50 KB**.
- Battery: **negligible**. It's a dispatch table. It doesn't do anything until a command arrives.

**The original recommendation oversold battery/memory as a concern. That was imprecise. I should have separated concerns more clearly.**


## 2. What's the ACTUAL risk?

The risks are ranked correctly here:

### Risk 1: AVAudioSession lifecycle — UX risk (the real one)
To interrupt another app's audio and make it pause, you activate `AVAudioSession` without `.mixWithOthers`. The other app detects the interruption and pauses. When your overlay dismisses, you must deactivate with `.notifyOthersOnDeactivation` — this tells the interrupted app it can resume.

**If you get this wrong:**
- Forget to deactivate → the audio session stays active, your app appears in Control Center as a phantom media source, the user's podcast never resumes. This is the failure mode I flagged.
- Crash during overlay → same result. The session stays active until the OS eventually cleans it up (usually within seconds of process death, but not guaranteed instantly).

This is the only genuinely scary part, and it's a **1-line fix**: always deactivate with `.notifyOthersOnDeactivation`.

### Risk 2: Control Center pollution — UX risk
If you also set `MPNowPlayingInfoCenter.default().nowPlayingInfo`, you register as the "now playing" app and get persistent media controls in Control Center. For this feature — where we just want to interrupt audio during a break — **you don't need MPNowPlayingInfoCenter at all**. Don't touch it, don't appear in Control Center.

### Risk 3: App Review — low but real
If you add `UIBackgroundModes: audio`, App Review will expect you to actually play audio. You will fail review. **Don't add it.** You don't need it. This feature only triggers when the app is foreground (overlay is showing). Foreground audio session activation requires no entitlement.

### Risk 4: User consent — product risk
Pausing someone's music without opt-in is aggressive enough to cause app deletions. Must be opt-in, default OFF.

### Summary table

| Risk | Category | Severity | Mitigated by |
|------|----------|----------|--------------|
| AVAudioSession not deactivated | UX/lifecycle | Medium | Always call `.setActive(false, options: .notifyOthersOnDeactivation)` |
| Control Center pollution | UX | Low | Don't touch `MPNowPlayingInfoCenter` |
| App Review rejection | Compliance | Low | Don't add `UIBackgroundModes: audio` |
| User consent | Product | Medium | Opt-in toggle, default OFF |
| Battery/memory | Performance | **None** | N/A — not a real concern |


## 3. How hard is the AVAudioSession lifecycle to get right?

Honest answer: **not hard if you're deliberate**. The full implementation is ~30 lines:

```swift
// OverlayManager or a dedicated AudioInterruptionManager

func pauseMediaIfEnabled() {
    guard settingsStore.pauseMediaDuringBreaks else { return }
    do {
        try AVAudioSession.sharedInstance().setActive(true)
    } catch {
        logger.error("Failed to activate audio session: \(error)")
    }
}

func resumeMediaIfNeeded() {
        // .notifyOthersOnDeactivation is critical — tells the interrupted app to resume
        try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        logger.error("Failed to deactivate audio session: \(error)")

Call `pauseMediaIfEnabled()` when the overlay appears. Call `resumeMediaIfNeeded()` in ALL overlay dismissal paths (user taps dismiss, snooze, timer auto-dismiss, and any error path).

Edge cases to test:
- No audio playing when overlay fires → safe, activating an audio session with nothing to interrupt is a no-op for other apps
- User backgrounds the app during overlay → `DispatchQueue.main.asyncAfter` is suspended, overlay stays up, session stays active until foreground return when auto-dismiss fires
- App crash during overlay → OS reclaims the session; interrupted app may not receive `.notifyOthersOnDeactivation` in this scenario — acceptable, not catastrophic

**Complexity rating: Low.** This is not a complex feature. The Phase 3 deferral was not justified on complexity grounds.


## 4. Revised Recommendation

**Move to Phase 2.**

- ~30 lines of code in a thin `AudioInterruptionManager` or directly in `OverlayManager`
- Opt-in setting (`pauseMediaDuringBreaks`, default `false`)
- No `UIBackgroundModes: audio`
- No `MPNowPlayingInfoCenter`
- Deactivate with `.notifyOthersOnDeactivation` in all dismiss paths
- No `MPRemoteCommandCenter` handler registration needed for this use case (that's for receiving commands, not sending interruptions)

**Why Phase 2, not Phase 1:**
- It's not MVP-critical. The core value proposition works without it.
- Phase 1 should be ruthlessly minimal — get the overlay working and shipped to TestFlight.
- Phase 2 polish pass is the right moment for opt-in UX enhancements.

**Why not Phase 3:**
- The implementation is trivial. Deferring trivial, well-scoped features to Phase 3 inflates the roadmap.
- There's no meaningful technical risk that requires Phase 1 learnings to de-risk.


## What I Got Wrong in the Previous Recommendation

The previous telemetry-battery.md conflated `MPRemoteCommandCenter` (a command dispatch table) with `AVAudioSession` lifecycle concerns. They are related but distinct. `MPRemoteCommandCenter` itself has no battery or memory cost worth discussing. The real concern is `AVAudioSession` activation/deactivation hygiene — which is real, but not complex. I overcautioned on Phase 3 as a result.

# Decision: Telemetry Strategy & Battery/Memory Optimization Audit

> **Status:** Proposed  


## Part 1: Telemetry & Observability — What Apple Gives Us for Free

### The Full Toolkit

| Tool | What It Does | Cost to Integrate | Verdict for This App |
|------|-------------|-------------------|---------------------|
| **`os.log` / `Logger`** | Structured logging with categories and privacy levels. Visible in Console.app and Xcode debug console. Subsystem-filtered. | ~2 hours (replace `print()`) | ✅ **Use in Phase 2** — already planned in ARCHITECTURE.md §7.5 |
| **Xcode Organizer** | Shows crash reports, energy impact, disk writes, hang rate, scroll hitches — aggregated from App Store users | Zero (automatic after App Store release) | ✅ **Use — free, zero-code** |
| **App Store Connect Analytics** | Sessions, retention, devices, OS versions, installs, deletions | Zero (automatic) | ✅ **Use — free, zero-code** |
| **MetricKit** | On-device collection of performance/diagnostic payloads: CPU time, memory peaks, hang diagnostics, disk I/O, cellular data, battery drain. Delivered as `MXMetricPayload` every ~24h. | ~4 hours (add `MXMetricManagerSubscriber`) | ⚠️ **Defer to Phase 3** — see reasoning below |
| **Instruments** | Profiling during development: Time Profiler, Allocations, Leaks, Energy Log, Core Animation | Zero (development tool) | ✅ **Use during development** — already referenced in ROADMAP.md |
| **XCTest Performance Metrics** | Measure wall clock, CPU, memory in unit tests with baselines | ~1 hour per test | ⚠️ **Defer** — meaningful only once we have code |
| **Xcode Memory Graph Debugger** | Visual reference graph for leak detection | Zero (development tool) | ✅ **Use during M1.5 overlay testing** |

### Recommendation: Tiered Adoption

**Phase 1 (MVP) — Zero-effort observability:**
- Use `print()` for debugging (already planned).
- Use Instruments for overlay memory leak validation during M1.5.
- Use Xcode Memory Graph Debugger to verify UIWindow teardown.

**Phase 2 (Polish) — Structured logging:**
- Replace `print()` with `os.Logger` using subsystems:
  ```swift
  private let logger = Logger(subsystem: "com.yashasg.eyeposturereminder", category: "Scheduling")
  logger.info("Scheduled \(type.rawValue) reminder: interval=\(interval)s")
  ```
- This gives us Console.app filtering, privacy redaction, and zero performance cost when not attached (os.log is compiled out at the call site in release builds when below the configured log level).

**Phase 3 (Optional) — MetricKit:**
- Only if we see reports of energy or hang issues in Xcode Organizer after App Store launch.
- MetricKit is ~4 hours to integrate, but the data is meaningless until we have real users generating payloads.
- For 2 repeating notifications and an on-demand overlay, MetricKit would mostly report zeros.

### What's Overkill

- **Third-party analytics (Firebase, Mixpanel, Amplitude):** Adds a dependency, increases binary size, requires privacy manifest declarations. Our data needs are covered by App Store Connect + os.log.
- **MetricKit in Phase 1:** No users = no payloads. Wasted integration effort.
- **Custom telemetry infrastructure:** We have 5 settings and 2 notification types. There's nothing to build a dashboard for.


## Part 2: Battery & Memory Optimization Audit

### Component-by-Component Analysis

#### 1. `UNUserNotificationCenter` for Scheduling

**Verdict: ✅ Optimally designed. No concerns.**

- `UNUserNotificationCenter` is managed entirely by the OS notification daemon (`usernoted`/`notifyd`). **The app process is not kept alive.** iOS can terminate the app immediately after scheduling, and notifications still fire.
- With `repeats: true`, we schedule exactly 2 notification requests. iOS handles the timer internally — no CPU cost to our app between reminders.
- When a notification fires with the app terminated, iOS delivers it as a system banner. The app is only launched (briefly, in background) if the user taps the notification, at which point `UNUserNotificationCenterDelegate.didReceive` fires.
- **Battery impact: effectively zero** between reminders. This is the Apple-blessed pattern for exactly this use case.

#### 2. UIWindow at `.alert + 1` Level

**Verdict: ✅ Well-designed, with one minor recommendation.**

- The overlay UIWindow is created on-demand and released after dismissal. This means **zero memory cost between reminders** — no persistent view hierarchy, no retained hosting controller.
- During display, the memory footprint is: 1 UIWindow + 1 UIHostingController + the SwiftUI OverlayView hierarchy (a blur, an SF Symbol, text, and a circular progress view). Estimated: **~2-4 MB** — negligible.
- The `.alert + 1` window level itself has no performance cost — it's just a `CGFloat` that determines z-ordering.
- **One concern to validate:** The architecture says the window is "released immediately after dismissal." Confirm in implementation that:
  - The UIWindow reference is set to `nil` (not just `isHidden = true`)
  - The UIHostingController is not retained by a closure or delegate cycle
  - Use Xcode Memory Graph Debugger during M1.5 to verify

**Recommendation:** Add a debug assertion in `OverlayManager.dismissOverlay()`:
assert(window == nil, "Overlay window should be deallocated after dismissal")

#### 3. UserDefaults for Persistence

**Verdict: ✅ Perfect choice. No concerns.**

- We store 5 scalar values (~200 bytes total). UserDefaults is backed by a plist file that's memory-mapped after first read. Subsequent reads are in-memory — **no disk I/O**.
- Writes are coalesced by the system and written lazily. Changing a setting doesn't trigger a synchronous disk write.
- Alternatives analysis:
  - **SwiftData/CoreData:** ~5-15 MB memory overhead for the persistent stack. Absurd for 5 values.
  - **Keychain:** Designed for secrets, not preferences. Slower API, encrypted storage.
  - **File-based (JSON/plist):** Manual serialization for no benefit over UserDefaults.
  - **`@AppStorage`:** This is UserDefaults with SwiftUI property wrapper sugar. We could use it in views, but the `SettingsStore` abstraction gives us testability. Either is fine.

#### 4. Background Execution

**Verdict: ✅ No background execution. This is correct.**

- The architecture explicitly declares **no background modes** in Info.plist. This means:
  - iOS will suspend the app within ~5 seconds of entering background
  - No background CPU, no background network, no background location
  - The only thing running is the OS notification scheduler, which is not "our" code
- **The `DispatchQueue.main.asyncAfter` auto-dismiss timer** only runs while the app is active/foreground. If the user switches away during a break, the timer pauses (main queue is suspended). When they return, it resumes. This is correct behavior — no wasted CPU.
- **Battery impact: effectively zero** in background. The app doesn't exist as a running process between reminders.

#### 5. MPRemoteCommandCenter (Media Pause) — Proposed Feature

**Verdict: ⚠️ Needs careful design. Potential battery/UX concern.**

This feature isn't in the current architecture docs, but Yashas asked about it. Here's the analysis if we were to add "pause media during eye breaks":

**How it works:**
- `MPRemoteCommandCenter.shared().pauseCommand` lets you send a pause event to the now-playing app.
- Requires importing `MediaPlayer` framework and becoming the "now playing" app or using `MPNowPlayingInfoCenter`.

**Concerns:**
1. **Audio session overhead:** To control media playback, we'd need to activate an `AVAudioSession`. This registers the app with the media subsystem. If done incorrectly (e.g., not deactivating after the break), iOS keeps the audio session alive and the app appears in Control Center as a media source — confusing and potentially preventing actual media apps from working.
2. **Background audio entitlement trap:** If we add `audio` to `UIBackgroundModes` to support this, we've just given ourselves a background execution mode that iOS will scrutinize during App Review. An app that claims audio background mode but doesn't play audio will be flagged.
3. **User expectation mismatch:** Pausing someone's music/podcast without consent is aggressive. If the user is listening to something during work, a forced pause may cause them to disable the app entirely.
4. **Battery:** The `MPRemoteCommandCenter` itself is lightweight (it's just a command dispatch table). But maintaining audio session state adds marginal overhead.

**Recommendation if we proceed:**
- **Don't** request background audio mode. Only pause media when the overlay is presented (app is foreground).
- Activate audio session → send pause → deactivate audio session immediately. Don't hold it.
- Make this an **opt-in setting**, defaulting to OFF. Most users won't want forced media pausing.
- **Phase 3 at earliest.** This is feature creep for MVP.


## Summary: Architecture Battery/Memory Grade

| Component | Grade | Notes |
|-----------|-------|-------|
| UNUserNotificationCenter scheduling | A+ | Textbook battery-efficient design |
| UIWindow overlay lifecycle | A | Verify deallocation in M1.5 with Memory Graph Debugger |
| UserDefaults persistence | A+ | Perfect fit for this data size |
| No background modes | A+ | Correct — no ambient battery drain |
| DispatchQueue auto-dismiss timer | A | Only runs foreground, negligible cost |
| MPRemoteCommandCenter (if added) | B- | Needs opt-in design and careful audio session management |

**Overall: The architecture is well-optimized.** The design delegates all background work to the OS, retains no view hierarchy between reminders, and uses the lightest persistence layer available. No gaps identified for the current MVP scope.


## Action Items

| Item | Owner | Phase | Priority |
|------|-------|-------|----------|
| Replace `print()` with `os.Logger` | Implementation | Phase 2 | Medium |
| Validate UIWindow deallocation with Memory Graph Debugger | Implementation | M1.5 | High |
| Validate overlay memory with Instruments Allocations | Implementation | M1.5 | High |
| Review Xcode Organizer data post-launch | Rusty | Post-launch | Medium |
| If media pause is desired, design opt-in audio session management | Rusty | Phase 3 | Low |
| MetricKit integration (only if Organizer shows issues) | Implementation | Phase 3+ | Low |

# Decision: TestFlight Telemetry Strategy



## Context

We previously decided on a tiered telemetry adoption: Instruments in Phase 1, `os.Logger` in Phase 2, MetricKit deferred to Phase 3+. This decision revisits that plan specifically for the **TestFlight beta phase** — the window between internal MVP completion and App Store launch — where real testers on real devices generate real data, but the app is not yet public.

This matters because Eye & Posture Reminder is a health intervention tool. Battery drain, notification reliability, and overlay interruption behavior are all critical to get right *before* users give a 1-star review on day one.


## Q1: Does App Store Connect Analytics work for TestFlight builds?

**Yes, with limitations.**

App Store Connect shows a dedicated **TestFlight section** with:
- ✅ Number of testers invited / accepted
- ✅ Session count (how often the app was opened)
- ✅ Crash count and crash rate per build
- ✅ Device models and OS versions of testers
- ✅ Installs and uninstalls per build version

**Not available during TestFlight:**
- ❌ Retention / Day 1, Day 7, Day 30 curves (App Store Analytics only)
- ❌ Revenue data
- ❌ Ratings and reviews
- ❌ Funnel analysis or custom events

**Verdict for us:** Crash rate per build is the killer feature here. We'll know immediately if a new build introduced a regression. Session count lets us verify testers are actually using the app vs. just installing it.


## Q2: Does MetricKit deliver payloads for TestFlight users?

**Yes. This is the most important thing I got wrong in my previous recommendation.**

MetricKit payloads **are delivered for TestFlight builds**, just like App Store builds. The ~24-hour delivery window applies identically. If you have `MXMetricManagerSubscriber` implemented, your TestFlight testers will generate:

- ✅ `MXCPUMetric` — CPU time (total vs. foreground vs. background)
- ✅ `MXMemoryMetric` — peak memory footprint
- ✅ `MXDiskIOMetric` — logical writes
- ✅ `MXBatteryMetric` — drain rate during active use
- ✅ `MXHangDiagnostic` — main thread hang details (>250ms)
- ✅ `MXCrashDiagnostic` — crash call stacks with symbolication
- ✅ `MXLaunchMetric` — cold and warm launch time
- ✅ `MXAppExitMetric` — normal exits vs. jetsam kills vs. crashes

**Caveats:**
- Small tester pool (10–50 users) means low statistical significance. One tester with a hot device skews battery data.
- Payloads only arrive if the app was foregrounded in the past 24h — our app is mostly background, so CPU/battery data will correctly reflect near-zero usage, which is the right signal.
- You need the subscriber registered before the payload arrives — no retroactive collection.

**Revised recommendation: Move MetricKit to Phase 2 (not Phase 3).** The cost is ~4 hours, the data starts arriving the moment we have TestFlight testers, and `MXCrashDiagnostic` alone is worth it. For a health app where battery drain complaints would be fatal, getting MXBatteryMetric data from beta is risk mitigation.

### Minimal MetricKit Integration

// AppDelegate.swift
import MetricKit

extension AppDelegate: MXMetricManagerSubscriber {
    func setupMetricKit() {
        MXMetricManager.shared.add(self)

    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            let json = payload.jsonRepresentation()
            logger.info("MetricKit payload: \(String(data: json, encoding: .utf8) ?? "nil")")
            // Phase 2: log to os.Logger; Phase 3: ship to backend if needed
        }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
            logger.error("MetricKit diagnostic: \(String(data: json, encoding: .utf8) ?? "nil")")

This requires zero backend infrastructure — just os.log output that we can collect from tester devices via Console.app if needed, and that appears in crash reports.


## Q3: Do crash reports from TestFlight show up in Xcode Organizer?

**Yes. This works automatically and is one of TestFlight's most valuable features.**

- Crashes from TestFlight testers appear in **Xcode Organizer → Crashes** within minutes to a few hours.
- They are **fully symbolicated** — provided your CI/CD pipeline uploads dSYMs to App Store Connect (our GitHub Actions workflow should do this via `xcodebuild -exportArchive` with `uploadBitcode` or via Xcode Cloud).
- Crash reports are grouped by stack signature, so you see "X testers hit this crash" not N separate entries.
- You can filter by build version.

**Action required:** Ensure our GitHub Actions pipeline either:
1. Uses `xcodebuild -exportArchive` with App Store Connect upload (dSYMs uploaded automatically), OR
2. Explicitly uploads the `.dSYM` bundle to App Store Connect after each TestFlight upload.

If dSYMs are missing, crash reports will be unsymbolicated (hex addresses only) — nearly useless.


## Q4: TestFlight-specific feedback tools

**Built into the TestFlight app — not our app.**

TestFlight provides a native feedback mechanism:
- Testers **long-press the TestFlight app icon** → "Send Beta Feedback"
- Or shake the device while running our app → TestFlight intercepts and shows feedback UI
- Testers can write a note, attach an auto-screenshot, and mark it as positive/negative

This feedback appears in **App Store Connect → TestFlight → Feedback** and includes:
- ✅ Screenshot of the app at the time of feedback
- ✅ Device model, OS version, app version
- ✅ Battery level (!) at time of feedback
- ✅ Tester's written note
- ✅ App logs from the past few minutes (if enabled in TestFlight app settings)

**Key insight:** TestFlight *can* collect app logs automatically if the tester enables "Share App Data" in the TestFlight settings. These logs include `os.log` output from your app's subsystem. This is another strong reason to have `os.Logger` active during TestFlight — the logs become part of the feedback package without any extra work.

**No programmatic API** for accessing this feedback from within our app. We can't trigger the feedback sheet manually or attach custom data to it.


## Q5: Should we move os.Logger to Phase 1?

**Yes. Recommendation revised: move os.Logger to Phase 1.**

**Reason:** You cannot attach Xcode to a tester's phone. If a tester reports "the overlay appeared at the wrong time" or "I got two overlays at once" or "I never got a notification after a force quit," you have no way to reproduce or diagnose it without logs. Print statements don't survive a release build, and you can't reproduce every device state.

With `os.Logger` active from Phase 1:
1. **TestFlight crash reports** include the last N os.log entries before the crash — rich diagnostic context.
2. **TestFlight feedback submissions** include recent os.log output (if tester has "Share App Data" enabled).
3. **Power-user testers** can plug into Console.app on Mac and stream your logs live.
4. **Zero performance cost in production** — os.log calls below the configured level are compiled to near-zero overhead.

### Suggested Logger Setup (Phase 1, Day 1)

// Logger+App.swift
import OSLog

extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.yashasg.eyeposturereminder"

    static let scheduling = Logger(subsystem: subsystem, category: "Scheduling")
    static let overlay    = Logger(subsystem: subsystem, category: "Overlay")
    static let settings   = Logger(subsystem: subsystem, category: "Settings")
    static let appLife    = Logger(subsystem: subsystem, category: "AppLifecycle")

// Usage
Logger.scheduling.info("Scheduled \(type.rawValue, privacy: .public) at interval \(interval)s")
Logger.overlay.debug("UIWindow created, level=\(windowLevel.rawValue)")
Logger.overlay.info("Overlay dismissed: source=\(source, privacy: .public)")

Cost: ~1–2 hours to set up the extension and replace key `print()` calls. Not worth delaying M1.1 for, but should be done as part of M0.2 architecture scaffolding.


## Q6: TestFlight-specific gotchas

### Notifications
- **Production APNs, not sandbox.** Since Xcode 13, TestFlight builds use production APNs. This means notification behavior is identical to App Store. No gotcha here — this is good news.
- **Notification permission prompt** appears identically to App Store builds. Testers will see the real permission dialog.
- **Scheduled `UNTimeIntervalNotificationRequest`s** fire normally — no differences from App Store.
- ⚠️ **Focus modes / Do Not Disturb** apply to TestFlight builds just like App Store. If a tester has Focus enabled, they won't see banners, but `willPresentNotification` still fires if the app is foregrounded. Our foreground overlay path is unaffected; only the background notification banner is suppressed.

### Background Execution
- TestFlight builds are **release-mode compiled** and have **full production entitlements**. Background behavior is identical to App Store.
- Our architecture (no background modes, all scheduling via `UNUserNotificationCenter`) means this is a non-issue — we intentionally have zero background runtime budget.
- ⚠️ **Jetsam (memory pressure kills):** TestFlight builds can be killed by jetsam if the device is under memory pressure. We'll see these in `MXAppExitMetric.backgroundExitData.cumulativeMemoryResourceLimitExitCount`. This is another reason to add MetricKit in Phase 2.

### Distribution / Signing
- TestFlight uses the **App Store distribution certificate** and an **App Store provisioning profile** (not development). Entitlements are fully production-grade.
- No differences in keychain access, push notification entitlements, or background mode entitlements.

### Receipt / Sandbox
- TestFlight receipts are production receipts with a `receiptType` of `"ProductionSandbox"`. Not relevant for us (no IAP), but worth noting if we ever add subscriptions.

### Bitcode / dSYMs
- ⚠️ **Critical:** If bitcode is enabled (legacy), Apple recompiles the binary and generates new dSYMs. You must download the recompiled dSYMs from App Store Connect and re-upload them for symbolication to work. **Simplest solution: disable bitcode** (it's deprecated anyway since Xcode 14). Our pipeline should set `ENABLE_BITCODE = NO`.

### TestFlight Expiry
- TestFlight builds expire after **90 days**. Any tester running an expired build can't open the app. For a short beta (2–4 weeks), this is irrelevant, but keep it in mind if the beta stretches.

### Overlay-specific risk
- ⚠️ TestFlight builds run on **testers' personal devices with real apps installed.** If a tester is in a video call (FaceTime, Zoom) when a reminder fires, our UIWindow overlay will cover it. This is expected behavior but may generate "the app interrupted my call" feedback. Consider adding `UNNotificationInterruptionLevel.timeSensitive` to our notification request to give us interruption capability while still being deferrable by Focus.


## Revised Telemetry Adoption Plan

| Tool | Previous Plan | Revised Plan | Reason |
|------|--------------|--------------|--------|
| `os.Logger` | Phase 2 | **Phase 1 (M0.2)** | TestFlight crash reports + feedback include logs |
| MetricKit | Phase 3 | **Phase 2** | TestFlight delivers payloads; MXCrashDiagnostic is risk mitigation |
| Xcode Organizer Crashes | After App Store | **Available from first TestFlight build** | Automatic; ensure dSYMs uploaded |
| App Store Connect Analytics | After App Store | **TestFlight section available immediately** | Crash rate per build is immediately useful |
| TestFlight Feedback | N/A | **Available to testers from day one** | No integration needed; brief testers on shake gesture |



1. **M0.2 (Rusty/Basher):** Add `Logger+App.swift` with subsystem extension. ~1 hour.
2. **M0.3 (Basher):** Ensure CI/CD pipeline uploads dSYMs to App Store Connect. Set `ENABLE_BITCODE = NO`. Critical for symbolicated crash reports.
3. **Phase 2 (Basher):** Add `MXMetricManagerSubscriber` to AppDelegate. Log payloads via `Logger.appLife`. ~4 hours.
4. **TestFlight brief (Danny):** Tell testers to enable "Share App Data" in TestFlight settings. Screenshot this in the tester onboarding email.
5. **TestFlight brief (Danny/Livingston):** Instruct testers on shake-to-feedback gesture.

# Decision: iOS Release Versioning Strategy

> **Proposed by:** Virgil (CI/CD Dev)  
> **Date:** 2025-07-17  
> **Triggered by:** Yashas asked about versioning strategy, suggested commit hash



We need a versioning strategy for Eye & Posture Reminder before we ship to TestFlight or the App Store. Yashas suggested using commit hashes. This document explains why that won't work as the primary version, and proposes a concrete scheme.


## 1. Apple's Versioning Constraints

Apple requires **two** version fields in every iOS app:

| Field | Info.plist Key | Rules | Example |
|---|---|---|---|
| **Marketing Version** | `CFBundleShortVersionString` | Must be `MAJOR.MINOR.PATCH` (1–3 dot-separated integers). This is what users see on the App Store. | `1.2.0` |
| **Build Number** | `CFBundleVersion` | Must be a string of dot-separated integers. For TestFlight, **must be strictly increasing** within each marketing version. | `42` or `1.2.0.42` |

**Hard rules:**
- No letters, no hashes, no dashes. `a3f9c2e` is rejected by App Store Connect.
- TestFlight will refuse an upload if the build number isn't higher than the previous upload for the same marketing version.
- The marketing version is what goes on the App Store listing page.


## 2. Why Commit Hash Alone Doesn't Work (But Is Still Useful)

**Can't be the version:** Apple's format is strictly numeric dot-separated integers. A commit hash like `a3f9c2e` or even a full SHA will be rejected at upload time. There's no workaround — this is enforced server-side by App Store Connect.

**Can be embedded for traceability:** We embed the commit hash as a **separate Info.plist key** (e.g., `EPRCommitHash`). This gives us:
- Crash report → exact source code mapping
- TestFlight tester reports → "which build is this?" answered instantly
- No ambiguity between builds with the same version number during development


## 3. Recommended Versioning Scheme

### Marketing Version (`CFBundleShortVersionString`)
**Semantic versioning: `MAJOR.MINOR.PATCH`**

- `MAJOR` — breaking changes, major redesigns (1.0.0 → 2.0.0)
- `MINOR` — new features (1.0.0 → 1.1.0)
- `PATCH` — bug fixes (1.0.0 → 1.0.1)
- **Bumped manually** by the developer when cutting a release. This is intentional — version bumps are product decisions, not automation decisions.

**Starting version: `1.0.0`**

### Build Number (`CFBundleVersion`)
**CI build count, auto-incremented.**

Strategy: **GitHub Actions run number** (`${{ github.run_number }}`).

- Starts at 1, increments every CI run. Guaranteed unique, guaranteed increasing.
- Never needs manual management.
- If we ever reset (e.g., new repo), we offset: `run_number + 1000`.

### Commit Hash (`EPRCommitHash` — custom Info.plist key)
**Short SHA embedded at build time.**

- Set via build script: `git rev-parse --short HEAD`
- Stored as `EPRCommitHash` in Info.plist
- Accessible in-app via `Bundle.main.infoDictionary?["EPRCommitHash"]`
- Displayed in Settings screen as small gray text (e.g., "Build 42 · a3f9c2e")

### Concrete Example

For the 42nd CI build of version 1.1.0 at commit `a3f9c2e`:

CFBundleShortVersionString = "1.1.0"
CFBundleVersion = "42"
EPRCommitHash = "a3f9c2e"
Settings screen: "v1.1.0 (42) · a3f9c2e"


## 4. CI Automation (GitHub Actions)

### What's automated (no human touches these):
- **Build number:** Set from `github.run_number` in the workflow.
- **Commit hash:** Injected via a build phase script.

### What's manual (intentionally):
- **Marketing version bumps.** The developer decides when to go from 1.0.0 → 1.1.0. This is done by editing the Xcode project (or via a `fastlane` lane like `fastlane bump minor`).

### Implementation sketch (GitHub Actions):

```yaml
# In the build workflow
- name: Set build number
  run: |
    cd EyePostureReminder
    agvtool new-version -all ${{ github.run_number }}

- name: Embed commit hash
    COMMIT_HASH=$(git rev-parse --short HEAD)
    /usr/libexec/PlistBuddy -c "Add :EPRCommitHash string $COMMIT_HASH" \
      EyePostureReminder/Info.plist 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Set :EPRCommitHash $COMMIT_HASH" \
      EyePostureReminder/Info.plist

### Fastlane alternative (if we adopt fastlane later):

```ruby
lane :set_build_metadata do
  increment_build_number(build_number: ENV["GITHUB_RUN_NUMBER"])
  set_info_plist_value(
    path: "EyePostureReminder/Info.plist",
    key: "EPRCommitHash",
    value: `git rev-parse --short HEAD`.strip
  )
end


## 5. Git Tags

**Yes, tag every release.** Format:

| Type | Tag Format | Example |
| Production release | `v{MAJOR}.{MINOR}.{PATCH}` | `v1.0.0` |
| TestFlight beta | `v{MAJOR}.{MINOR}.{PATCH}-beta.{N}` | `v1.1.0-beta.1` |

**Rules:**
- Tags are created **after** a successful App Store Connect upload (not before — don't tag broken builds).
- Tags are annotated (`git tag -a`), not lightweight.
- Tag message includes the build number: `"Release 1.0.0, build 42"`.
- CI can auto-tag on successful upload, or the developer tags manually. I recommend **CI auto-tags** to prevent forgetting.



| Concern | Decision |
| Marketing version | Semantic `MAJOR.MINOR.PATCH`, manually bumped |
| Build number | `github.run_number`, fully automated |
| Commit traceability | `EPRCommitHash` in Info.plist, injected by CI |
| Git tags | `v1.0.0` format, annotated, created after successful upload |
| Commit hash as version? | **No** — Apple rejects non-numeric formats. Embedded as metadata instead. |
| Who bumps versions? | Developer bumps marketing version. CI handles everything else. |


## Decision Needed

Team should confirm:
1. Starting version `1.0.0` (vs `0.1.0` for pre-release)
2. Whether to start with `0.x.x` during TestFlight-only phase and go `1.0.0` at App Store launch
3. Custom Info.plist key name (`EPRCommitHash` vs alternatives)
---

## Phase 0 Inbox Decisions (Merged 2026-04-24)

### Decision: Xcode Project Setup via Swift Package Manager
**Author:** Basher  
**Date:** 2026-04-24  
**Status:** Adopted

Use **Swift Package Manager** (`Package.swift`) as the project manifest:
- `Package.swift` at repo root, targeting `.iOS(.v16)`
- Source root: `EyePostureReminder/` (custom `path:` in the executable target)
- Bundle identifier placeholder: `com.yashasg.eyeposture`

**Consequences:**
- ✅ Xcode can open `Package.swift` directly — full IDE support, previews, and signing
- ⚠️ `swift build` on macOS fails (UIKit/SwiftUI are iOS-only). All builds must target a simulator or device inside Xcode
- ⚠️ If a CI pipeline is needed, it must use `xcodebuild` with `-destination 'platform=iOS Simulator,...'`

**Notification Routing Pattern:** All UNUserNotification category identifiers are owned by `ReminderType`:
- `ReminderType.categoryIdentifier` — canonical identifier
- `ReminderType.init?(categoryIdentifier:)` — reverses the mapping in AppDelegate

---

### Decision: Test Coverage Targets and Mock Strategy
**From:** Livingston (Tester)  
**Date:** 2026-04-24  
**Status:** Proposed — needs team acknowledgement  

**Coverage Targets:** Establish as CI gates:
- Models: 90%
- Services: 80%
- ViewModels: 80%
- Views: 60% (via UI tests)

**MediaControlling Protocol:** Add to `Protocols/MediaControlling.swift` if `OverlayManager` interacts with `AVAudioSession`:
```swift
protocol MediaControlling {
    func setActive(_ active: Bool, options: AVAudioSession.SetActiveOptions) throws
    func setCategory(_ category: AVAudioSession.Category) throws
}
extension AVAudioSession: MediaControlling { }
```
**Action:** Rusty to confirm whether `OverlayManager` will interact with `AVAudioSession` in Phase 1.

**2-Second Queue Gap:** The delay between dismissal of first overlay and appearance of queued second should be injectable:
```swift
static let queuedOverlayDelay: TimeInterval = 2.0  // 0.0 in tests
```

---

### Decision: Architecture Scaffolding API Contracts
**Author:** Rusty  
**Date:** 2025-07-25  
**Status:** Informational — no team vote required (architecture milestone)

**SettingsPersisting adds defaultValue parameter:** Methods take explicit `defaultValue:` rather than Foundation's implicit zero/false:
```swift
func bool(forKey key: String, defaultValue: Bool) -> Bool
func double(forKey key: String, defaultValue: Double) -> Double
```

**SettingsPersisting protocol location:** Defined in `SettingsStore.swift`, not in separate `Protocols/` directory. Extract to `Protocols/SettingsPersisting.swift` if second consumer appears in Phase 2+.

**OverlayManager is @MainActor:** Entire class annotated `@MainActor` for thread-safety with UIKit APIs. Callers not `@MainActor` must use `await MainActor.run { ... }`.

**SettingsViewModel updated:** Replaced Basher's placeholder with protocol-based implementation matching architecture.

---

### Decision: Design System
**Author:** Tess (UI/UX Designer)  
**Date:** 2026-04-24  
**Status:** Proposed — for team awareness

**Colors:**
- `reminderBlue` (#4A90D9): Calming, distinct from iOS system blue
- `reminderGreen` (#34C759): Matches iOS system green
- `warningOrange` (#FF9500): Matches iOS system orange
- `permissionBanner` (#FFCC00): Warm yellow = warning, not error

**Overlay Dismiss Gesture:** Swipe UP (not down) — naturally reverses the motion as overlay slides UP to appear. Swipe down reserved for Notification Centre.
**⚠️ Needs confirmation:** Swipe UP (recommendation) vs original spec's swipe DOWN.

**Settings Snooze Section:** Proposed dedicated "Snooze" section separate from overlay snooze sheet.
**⚠️ Needs confirmation:** Should Settings Screen include dedicated Snooze section, or only via post-dismiss sheet?

**DesignSystem.swift structure:** Uses `AppColor` enum as primary token access path. `Color` extension variants also provided for asset catalog setup.

---

### Decision: Telemetry Event Schema & Dashboard Requirements
**Author:** Turk (Data Analyst)  
**Date:** 2025-07-25  
**Status:** Proposed

**Logger Categories:** Four categories under subsystem `com.yashasg.eyeposturereminder`:
- `Scheduling`: UNNotificationRequest lifecycle, snooze activate/expire, auth flow
- `Overlay`: UIWindow show/dismiss/queue, settings tap
- `Settings`: Every SettingsStore write, permission events
- `AppLifecycle`: App state transitions, notification delivery callbacks, MetricKit payloads

**Log Format:** `event_name key1=value1 key2=value2`
- Enum values and numeric: `privacy: .public`
- User-authored text: `privacy: .private`
- No wall-clock timestamps in message body

**MetricKit Payload Storage (Phase 2):** Logged to `Logger.appLife` as JSON string — no separate storage or external server initially.

**Dashboard Metrics:** Key instrumentation requirements:
- Auto-dismiss rate: `overlay_dismissed source=auto|manual|swipe`
- Snooze duration: `snooze_activated duration_sec`
- Permission funnel: `permission_granted` + `permission_denied`
- Interval usage: `interval_changed new_sec`
- Overlay queue: `overlay_queued` count

**Privacy:** Phase 1-2 declare "Data Not Collected" for all user-linked categories in Privacy Nutrition Label.

---

### Decision: CI/CD Pipeline Setup
**Author:** Virgil (CI/CD Dev)  
**Date:** 2025-07-17  
**Status:** Implemented  

**Runner:** `macos-14` (Apple Silicon), Xcode 16.2 pinned.

**No signing in CI:** All builds use `CODE_SIGN_IDENTITY=""`, `CODE_SIGNING_REQUIRED=NO`. Only simulator destinations used.

**ENABLE_BITCODE=NO:** Bitcode deprecated by Apple in Xcode 14.

**DerivedData caching:** Cache key = hash of `project.pbxproj` + `.swift` files. Restores on prefix miss.

**dSYMs as artifacts:** Collected after every build, retained 90 days for crash symbolication.

**SwiftLint configuration:**
- Line length: 120 warning / 160 error
- Disabled: `function_body_length`, `large_tuple`, `opening_brace` (conflict with SwiftUI)
- `force_unwrapping` enabled as warning

**TestFlight job:** Present but commented out in `ci.yml`. Uncomment when Apple Developer account available.

**Tag format:**
- `v0.x.x`: TestFlight beta phase
- `v1.0.0`: App Store launch

**Open Question:** Starting version (`v0.x.x` vs `v1.0.0` for TestFlight) unresolved. CI is neutral.


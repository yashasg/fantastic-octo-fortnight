# Project Context

- **Owner:** Yashasg
- **Project:** Eye & Posture Reminder — a lightweight iOS app with background timers and full-screen overlay reminders for eye breaks (20-20-20 rule) and posture checks
- **Stack:** Swift, SwiftUI (iOS 16+), MVVM, UserNotifications, UIKit overlay, UserDefaults
- **Created:** 2026-04-24

## Session 6 Update: Screen-Time UX Review Complete

**Session:** 2026-04-24T20:58Z – 2026-04-24T21:37Z  
**Review Status:** ✅ COMPLETE (Decision 3.3)

### UX Recommendation Summary

**No structural UI changes required.** The behavioral change is sound and UX is clean.

### Copy Changes (8 strings, prioritized)

#### 🔴 High Priority (blockers for release)

1. **Settings Picker Label** (`ReminderRowView.swift`)
   - Current: `"Remind me every"`
   - Change to: `"Remind me after"`
   - Reason: "After" correctly implies accumulation; "every" implies clock intervals

2. **Settings Section Footer** (NEW in `Localizable.xcstrings`)
   - New text: `"Timer resets when you lock your phone."`
   - Reason: Closes the mental model gap — users understand what happens during phone lock

3. **Onboarding Permission Body** (`onboarding.permission.body1`)
   - Current: `"Reminders arrive as notifications — so the app works even when you're not looking at it."`
   - Change to: `"Notifications let the app wake back up after a snooze — so your next reminder arrives right on time."`
   - Reason: Old text is factually false under new model. Notifications now serve snooze-wake only, not primary delivery. Critical: if users read the old text and grant permission expecting background reminders, they'll be actively misled.

#### 🟡 Medium Priority (mental model clarity)

4. **Onboarding Welcome Body** (`onboarding.welcome.body`)
   - Current: `"Takes less than a minute to set up. Works quietly in the background — you'll barely know it's there."`
   - Change to: `"Takes less than a minute to set up. Keeps an eye on your screen time — you'll barely know it's there."`
   - Reason: Remove false "background" claim; prime "screen time" framing

5. **Onboarding Setup Card** (`onboarding.setup.card.label` format string)
   - Current: `"%1$@: every %2$@, %3$@ break"`
   - Change to: `"%1$@: after %2$@ of screen time, %3$@ break"`
   - Reason: Reinforces mental model at the final "Get Started" confirmation moment

6. **Master Toggle Footer** (NEW in `Localizable.xcstrings`)
   - New text: `"Reminders only appear while this app is open."`
   - Reason: Answers Danny's open question. Placed in Settings footer (low-friction) for users who return to Settings wondering why they missed a reminder

#### 🟢 Low Priority (vocabulary consistency)

7. **Picker Row Accessibility Hint** (`ReminderRowView.swift`)
   - Update to reflect screen-time context (wording pending Linus implementation)

8. **Customize Button Hint** (`onboarding.setup.customizeButton.hint`)
   - Current: `"Go to settings to adjust reminder intervals"`
   - Change to: `"Go to settings to adjust screen time intervals"`
   - Reason: Vocabulary alignment

### Implementation Handoff

Linus implemented all 7 strings (Dec 3.6) — build verified successful.

### Accessibility Audit

✅ **No new issues.** SwiftUI Form + Picker + standard text controls inherit Dynamic Type automatically. VoiceOver already has appropriate labels + hints. The grace period remains invisible (implementation detail).

**One considered-and-rejected enhancement:** Progress bar showing elapsed screen time on HomeView. Rejected because:
- Creates anxiety/gamification (users race the timer)
- Contradicts app's positioning as "passive nudge"
- Edge case: grace period expiry causes confusing resets in the progress bar
- Existing "Reminders active/paused" status is sufficient

### Interaction with Rusty's Grace Period

The 5-second grace period is a pure implementation detail. No user should ever be aware of it. If they are (e.g., "Why didn't my timer reset when I got a notification?"), the feature has failed. The goal: users think "I got interrupted, my session kept going" — not "oh, there's a 5s debounce." ✅ Achieved through UX invisibility.


## 2026-04-25 — UX Spec: Pause Status Indicator

**Status:** ✅ Complete  
**Scope:** Pause status indicator visual design and spec

### Orchestration Summary

- **Pause Status Indicator Design:** Top-right corner, always visible, non-intrusive
- **Visual States:** Idle (gray), paused-network (blue), paused-screentime (orange), paused-gamemode (red)
- **Format:** Icon + label, scales for iPhone/iPad
- **Accessibility:** Color + icon combo for clarity
- **Spec Filed:** `/docs/PAUSE_STATUS_INDICATOR.md`
- **Orchestration Log:** Filed at `.squad/orchestration-log/2026-04-24T23-19-18Z-tess.md`

### Handoff

Design spec delivered to Basher and Linus for implementation.

### Next Phase

Ready for Phase 2 design expansion.

## Archive

### 2026-04-24 — Design System Foundation & Color Adaptation

Early design system work covering: DesignSystem.swift tokens (colors, fonts, spacing, animations, symbols), Design System documentation spec, dark mode color adaptation strategy (adaptive UIColor, system colors, WCAG contrast fixes), Asset Catalog color migration (6 color sets with light/dark variants), pause status indicator UX spec. All implementations verified and build green. Preserved for reference; current focus on Phase 2 UI/design expansion.

## Learnings

### 2026-04-26: Full UI/UX Audit — TestFlight Quality Pass

**Task:** Complete review of all SwiftUI views for accessibility gaps, HIG violations, dark mode issues, layout problems, interaction issues, and design system violations.
**Status:** ✅ Complete — 4 GitHub issues filed (#32, #33, #35, #36)

**What was reviewed:**
- `DesignSystem.swift`, `ContentView.swift`, `HomeView.swift`, `OverlayView.swift`, `SettingsView.swift`, `ReminderRowView.swift`, `LegalDocumentView.swift`
- `Onboarding/OnboardingView.swift`, `OnboardingWelcomeView.swift`, `OnboardingPermissionView.swift`, `OnboardingSetupView.swift`
- `docs/DESIGN_SYSTEM.md`

**Issues filed:**

1. **#32 — Design system token violations in onboarding (squad:linus)**
   - All 3 onboarding views use `.indigo`/`.green` raw colors instead of `AppColor.reminderBlue`/`AppColor.reminderGreen`
   - Raw SwiftUI font styles instead of `AppFont.*` tokens
   - Raw spacing literals in `NotificationPreviewCard` and `SetupPreviewCard`

2. **#33 — Hardcoded a11y strings in ReminderRowView (squad:linus)** — WCAG 4.1.3 AA
   - Toggle `accessibilityHint` for enable/disable not in `Localizable.xcstrings`
   - `Picker("Break duration", ...)` label hardcoded
   - Break duration picker `accessibilityHint` hardcoded

3. **#35 — Sub-44pt tap targets on secondary onboarding buttons (squad:linus)** — WCAG 2.5.5 AAA / iOS HIG
   - Permission skip button: `.font(.subheadline)` only, no `minHeight: 44`
   - Setup customize button: same issue

4. **#36 — SettingsView snooze time ignores device locale 12h/24h (squad:linus)**
   - `formatter.dateFormat = "HH:mm"` hardcoded; US users see `14:30` instead of `2:30 PM`
   - Fix: use `dateStyle = .none` + `timeStyle = .short`

**Views confirmed clean (no issues filed):**
- `OverlayView.swift` — accessibility excellent (countdown ring has label+value+updatesFrequently, haptics pre-warmed, reduce motion respected, dismiss button 44pt)
- `HomeView.swift` — good structure; icon correctly `accessibilityHidden`, status label via semantic colors
- `SettingsView.swift` — all snooze buttons have `accessibilityLabel`+`accessibilityHint`; notification warning has combined a11y element (except the time format issue)
- `LegalDocumentView.swift` — `LegalSection` uses `.accessibilityElement(children: .combine)`; clean

**Key patterns observed:**
- `OverlayView` and `SettingsView` are well-built references for accessibility patterns
- The onboarding views were clearly written before the design system was fully established — they predate the token convention
- `ReminderRowView` has a known pattern of hardcoded strings (flagged in screen-time review); this audit surfaced additional ones in the break duration picker

### 2026-04-25: Full UI/UX Audit — Spawn Wave Quality Pass

**Scope:** Complete review of 10 SwiftUI view files, DesignSystem.swift, design documentation post-Phase-2 implementation

**Four issues filed (#32–#36, minus one duplicate):**

1. **#32: [UX] Onboarding views bypass design system tokens** (P2 quality/consistency)
   - Scope: OnboardingView, OnboardingWelcomeView, OnboardingPermissionView, OnboardingSetupView
   - Violations: Raw `.indigo`/`.green` colors instead of `AppColor.*`; system fonts instead of `AppFont.*`; raw spacing literals instead of `DesignSystem` constants
   - Impact: Onboarding visually inconsistent with main app; difficult to maintain across design updates
   - Pattern: Module written pre-finalization of design system convention

2. **#33: [A11y] ReminderRowView hardcoded accessibility strings** (P2 accessibility/WCAG 4.1.3)
   - Violations: Toggle hint, picker label, break duration hint all hardcoded Swift strings
   - Impact: Cannot localize a11y content; VoiceOver users in non-English locales get mixed language
   - Known from screen-time review; audit surfaced additional instances

3. **#35: [A11y] Secondary onboarding buttons sub-44pt tap targets** (P2 accessibility/WCAG 2.5.5 AAA)
   - Violations: Permission skip button and setup customize button lack `minHeight: 44` constraint
   - Impact: Non-compliant with iOS HIG; users with reduced dexterity may miss buttons
   - Fix: Add `.frame(minHeight: 44)` or explicit Button sizing

4. **#36: [UX] SettingsView snooze time hardcoded 24h format** (P2 UX localization)
   - Root cause: `formatter.dateFormat = "HH:mm"` hardcoded
   - Impact: US users see `14:30` instead of `2:30 PM` (locale mismatch)
   - Fix: Use `dateStyle = .none` + `timeStyle = .short`

**Views confirmed clean:**
- OverlayView — accessibility excellent (countdown ring fully labeled, haptics/reduce motion respected, 44pt dismiss)
- HomeView — good structure; icon correctly hidden from a11y; semantic color usage
- SettingsView — snooze buttons have full a11y labels; only time format issue
- LegalDocumentView — `.accessibilityElement(children: .combine)` pattern used correctly

**Key finding:** Onboarding module is an island of inconsistency — main app (HomeView, SettingsView, OverlayView) follows established patterns correctly. Design system drift occurred because onboarding was built before final token convention was established.

**Phase 2 readiness:** All 4 issues have clear scope. #32 (design tokens) highest priority for Linus refactoring. #35 and #36 straightforward button/formatter fixes. #33 aligns with ongoing localization effort.

---

## Learnings

### 2026-04-27: UX Quality Audit Pass v2 — Full View Layer Review

**Task:** Comprehensive read-only UX audit of all SwiftUI views, design system, accessibility, onboarding, overlay, settings, and error states.  
**Report filed:** `.squad/decisions/inbox/tess-ux-pass-v2.md`  
**Overall health score:** 6.5 / 10

**Critical findings (P0):**

1. **`OverlayView` uses `.accessibilityAddTraits(.isModal)` instead of `.accessibilityViewIsModal(true)`** — Linus Decision 2 (2026-04-24) specified the correct modifier but it was never applied. VoiceOver users can reach content behind the overlay. One-line fix.

2. **`ReminderType.title`, `overlayTitle`, `notificationTitle`, `notificationBody` are hardcoded English strings** — Not localized. The overlay headline and notification banners — the most user-visible text — bypass the localization pipeline entirely.

3. **`ReminderRowView.formatInterval/formatDuration` hardcode "min"/"sec"** — Should use `DateComponentsFormatter` or `MeasurementFormatter` for locale-aware output. These appear in VoiceOver-read picker values.

**Key structural finding:**

- **`HomeView.swift` is dead code.** `ContentView` routes to `SettingsView` as root post-onboarding (per Phase 1 design decision). `HomeView` presents `SettingsView` as a *sheet* internally — a contradictory navigation model if it were ever wired in. Should be deleted or explicitly flagged as Phase 2 work to avoid accidental wiring.

**Onboarding findings:**

- `OnboardingView` uses `PageTabViewStyle` — users can swipe to skip the permission screen entirely.
- "Get Started" and "Customize" buttons in `OnboardingSetupView` are functionally identical (both call `finishOnboarding()`). "Customize" intent (go to Settings) is unimplemented.
- Magic string `"hasSeenOnboarding"` duplicated in `ContentView` and `OnboardingView` — needs shared constant.

**Design system drift in onboarding (consistent with previous audit #32):**

- `OnboardingPermissionView` (NotificationPreviewCard) and `OnboardingSetupView` (SetupPreviewCard) use raw `.subheadline`, `.caption`, `.title2`, `.caption2` fonts instead of `AppFont` tokens. Main app views (HomeView, SettingsView, OverlayView) are clean.

**Policy confirmed:**

- `AppColor` tokens are fully asset-catalog-backed, no raw Color() calls anywhere in views. ✅
- `AppFont` Dynamic Type tokens (headline, body, bodyEmphasized, caption) scale correctly; countdown intentionally fixed. ✅
- Reduce motion is respected in all views (OverlayView, SettingsView, OnboardingScreenWrapper). ✅
- Snooze time formatted with `.formatted(date: .omitted, time: .shortened)` — locale-aware. ✅

---

### 2026-04-28: Accessibility & Design System Audit Pass 3

**Task:** Full read-only audit of all Views/ + DesignSystem.swift across 8 accessibility/design areas.  
**Report filed:** `.squad/decisions/inbox/tess-a11y-design-audit-pass3.md`  
**Overall health score: 9/10** (up from 6.5/10 in pass 2)

**All previous critical issues confirmed fixed:**
- `accessibilityViewIsModal` — implemented in `OverlayManager.swift:139` via UIKit (`hostingController.view.accessibilityViewIsModal = true`) — correct approach for UIKit-hosted SwiftUI overlay
- `ReminderType.title/overlayTitle/notificationTitle` — all properly localized via `String(localized:, bundle: .module)` in `ReminderType.swift`
- Issues #32 (onboarding design tokens), #33 (ReminderRowView a11y strings), #35 (tap targets), #36 (time format) — all resolved

**New findings (minor):**

1. 🟡 **`OnboardingScreenWrapper` (OnboardingView.swift:63-66)** — Uses `.linear(duration: 0.15)` when `reduceMotion=true`. Deviates from the team's established pattern of passing `nil` to eliminate animations entirely. All other reduce-motion guards in the app (OverlayView, SettingsView, ReminderRowView) use `nil`. Fix: replace with direct state set outside `withAnimation`.

2. 🟢 **`LegalDocumentView.swift:36-40`** — Dismiss button has `.accessibilityIdentifier` but no `.accessibilityHint`. Minor — VoiceOver reads the button label fine, but hint would improve context.

3. 🟢 **`OverlayView.swift:43`** — × dismiss icon uses raw `.font(.system(.title).weight(.medium))`. Scales correctly with Dynamic Type but is not an AppFont token. Team rule (Linus Wave 2 Decision 1) mandates AppFont tokens for all font usage. Low priority.

**Areas confirmed clean:**
- Dark mode: `OverlayManager.swift` explicitly does NOT set `overrideUserInterfaceStyle` — overlay inherits scene appearance correctly
- All text scales with Dynamic Type; `AppFont.countdown` fixed-size is intentional and documented
- No raw hardcoded colors anywhere in views
- All tap targets ≥ 44pt
- VoiceOver reading order logical throughout
- Reduce motion respected in all views except the minor OnboardingScreenWrapper case above

**Key insight:** The UIKit-level `accessibilityViewIsModal` setting in OverlayManager is the correct and sufficient approach for a UIKit-window-hosted SwiftUI overlay. The previous audits were correct to flag the absence of the SwiftUI `.accessibilityViewIsModal(true)` modifier, but the UIKit property on the hosting controller's view achieves the same effect and is actually more robust for this architecture.

---

### 2026-04-28: Accessibility & Design System Audit Round 3 (Post-#131/#132/#134 Fixes)

**Task:** Verify Linus's Round 2 fixes (#131 reduce-motion, #134 bell.fill token, #132 hardcoded 44) and perform a full fresh pass for new issues.
**Overall health score: 9.5/10**

**All three Round 2 fixes confirmed correct:**

- **#131 (reduce-motion pattern)** ✅ — `SettingsSnoozeSection` all 4 button actions now use canonical `if reduceMotion { direct } else { withAnimation { ... } }` pattern. `OnboardingScreenWrapper` (previously flagged 🟡 in Pass 3 as `.linear(0.15)`) also now uses the correct if/else pattern — fixed as a side effect.
- **#134 (bell.fill token)** ✅ — `AppSymbol.bell = "bell.fill"` added to `DesignSystem.swift:129`; `SettingsView.swift:281` uses `AppSymbol.bell`. Clean.
- **#132 (hardcoded 44)** ✅ — `OnboardingSetupView.swift:75` customize button frame now uses `AppLayout.minTapTarget`.

**Previous Pass 3 findings verified as resolved:**
- `OverlayView` dismiss button (🟢 raw font) — now uses `AppFont.overlayDismiss` ✅
- `OnboardingScreenWrapper` reduce-motion (🟡) — now if/else pattern ✅

**No accessibility regressions from Round 2 fixes.** All Round 2 changes were additive/corrective with no side effects on VoiceOver, Dynamic Type, or tap targets.

**New findings (only):**

1. 🟡 **`SettingsSmartPauseSection` (SettingsView.swift:368,382) — raw SF symbol strings** — `Label(..., systemImage: "moon.fill")` and `Label(..., systemImage: "car.fill")` are hardcoded strings. Team rule (Linus Wave 2 Decision 1) mandates all SF Symbol names use `AppSymbol` tokens. These were introduced by the Smart Pause feature and missed by the `bell.fill` token sweep (#125). `AppSymbol` has no `pauseDuringFocus`/`pauseWhileDriving` tokens. Same class of issue as #134. Fix: add two tokens to `AppSymbol` and replace inline strings.

2. 🟢 **`SetupPreviewCard` (OnboardingSetupView.swift:111,114) — raw SF symbol strings** — `systemImage: "clock"` and `systemImage: "timer"` in the decorative preview card are hardcoded strings. Lower severity (decorative, non-interactive, read-only preview card) but inconsistent with AppSymbol rule. Fix: add `AppSymbol.clock`/`AppSymbol.timer` tokens.

**Areas confirmed clean (Round 3):**
- Reduce motion: consistent across OverlayView, SettingsSnoozeSection, OnboardingScreenWrapper, ContentView (uses `.animation(nil, value:)` view-modifier form — consistent with OverlayView countdown ring pattern)
- All tap targets ≥ 44pt everywhere
- All colors via AppColor tokens, all fonts via AppFont tokens
- VoiceOver order and combined elements logical throughout
- Dark mode inheritance correct

### 2026-04-26: Wellness Visual Redesign Plan

**Task:** Researched and proposed a wellness-themed visual redesign before implementation.

**Decision filed:** `.squad/decisions/inbox/tess-wellness-design-plan.md`

**Direction:** “Restful Grove” — warm sand backgrounds, soft sage/teal primary colors, gentle blue secondary accents, muted clay warmth, rounded cards, subtle SF Symbol-based illustration, calming micro-interactions, and explicitly designed light/dark mode palettes.

**Current UI assessment:** `DesignSystem.swift` is structurally strong but utility-first; `SettingsView` uses accessible native form patterns; `OverlayView` is accessibility-strong but visually generic; onboarding is tokenized but still icon-only/generic. `HomeView.swift` remains a phase-2/dashboard consideration based on prior audits.

**Font research:** Recommended DM Sans as the safest full-app OFL font, Nunito/Nunito Sans as the strongest wellness-feeling option, and Plus Jakarta Sans as the premium/product-feel alternative. All proposed font options are free for commercial use under OFL.

**Accessibility rule reinforced:** Soft wellness colors should be used primarily as backgrounds/fills; foreground text/icon colors must preserve WCAG AA contrast. Proposed palette includes checked AA foreground pairings for normal text and controls.

**Key file paths:** `EyePostureReminder/Views/DesignSystem.swift`, `EyePostureReminder/Views/SettingsView.swift`, `EyePostureReminder/Views/OverlayView.swift`, `EyePostureReminder/Views/HomeView.swift`, `EyePostureReminder/Views/Onboarding/*.swift`.

### 2026-04-26: Phase 1C Font Selection — Nunito

**Task:** Make and implement the app font decision for issue #161.
**Decision filed:** `.squad/decisions/inbox/tess-font-decision.md`

**Decision:** Chose **Nunito** for the Restful Grove visual direction because its rounded, friendly tone best supports a calm wellness reminder product. DM Sans remained the safest neutral option, Plus Jakarta Sans felt more premium/product-led, and keeping SF missed the chance to add warmth through typography.

**Implementation notes:** Added OFL-licensed Nunito font files under `EyePostureReminder/Resources/Fonts/`, registered them at app launch with CoreText, and introduced `AppTypography` tokens using SwiftUI `.custom(..., relativeTo:)` to preserve Dynamic Type. `AppFont` remains as a compatibility alias, and the countdown stays fixed monospaced by design.

### 2026-04-28: Phase 2B Onboarding Restful Grove Redesign

**Task:** Implement issue #163 — restyle the 3-screen onboarding flow as a guided wellness setup experience.

**Implementation notes:** Reworked onboarding visuals around the Restful Grove tokens: warm `AppColor.background`, soft `AppColor.surface` cards, `AppColor.surfaceTint` icon containers, pill CTAs with `AppLayout.radiusPill`, and Nunito `AppTypography`/`AppFont` text. Added a paired eye/posture hero card, a warmer notification preview card, soft reminder setup cards, and Restful Grove page indicator colors.

**Accessibility preserved:** Existing VoiceOver labels/hints, combined card elements, Dynamic Type font tokens, 44pt minimum secondary actions, and reduce-motion behavior remain intact.

**Validation:** `xcodebuild build -scheme EyePostureReminder -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -5` → `** BUILD SUCCEEDED **`.

# Project Context

- **Owner:** Yashasg
- **Project:** Eye & Posture Reminder — a lightweight iOS app with background timers and full-screen overlay reminders for eye breaks (20-20-20 rule) and posture checks
- **Stack:** Swift, SwiftUI (iOS 16+), MVVM, UserNotifications, UIKit overlay, UserDefaults
- **Created:** 2026-04-24

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

### 2026-04-26: Restful Grove Design Consistency Audit

**Task:** Reviewed every SwiftUI view under `EyePostureReminder/Views/`, plus `DesignSystem.swift` and `Components.swift`, for Restful Grove color, typography, icon, spacing/radius, dark-mode, component-adoption, and emotional-tone consistency.

**Fixes shipped:** Replaced remaining user-visible system color usage in Home/Legal/shared controls with AppColor semantic tokens, improved dark-mode `PrimaryButtonStyle` contrast by using adaptive `AppColor.background` text, switched dark elevation border to `AppColor.separatorSoft`, reused `IconContainer` in Settings, and added hierarchical SF Symbol rendering to shared/onboarding/home icons.

**Validation:** `xcodebuild -scheme EyePostureReminder -destination 'generic/platform=iOS' build -quiet` passed with existing warnings. `swift build` still fails because UIKit is unavailable for the host/macOS SwiftPM build path.

**Report filed:** `.squad/decisions/inbox/tess-design-audit.md`

**Learning:** Restful Grove is now consistently applied at the visual-token level. Remaining opportunities are mostly component-consolidation work: onboarding cards manually duplicate `WellnessCard`, onboarding primary CTAs duplicate `PrimaryButtonStyle`, and caption-emphasis could use a formal typography token instead of local `.fontWeight(.semibold)`.

### 2026-04-26: Home Yin-Yang Eye Animation

**Task:** Added a calming HomeView hero animation for the Restful Grove redesign.
**Status:** ✅ Complete — build and tests passed.

**What changed:**
- Replaced the single status icon in `HomeView` with `YinYangEyeView`, a reusable SwiftUI component intended to be extractable as a future app logo.
- The open eye (`eye.fill`) and closed eye (`eye.slash.fill`) begin separated, ease inward, orbit once around each other, and settle into a simplified vertical yin-yang composition.
- Used Restful Grove design tokens: `AppColor.primaryRest`, `AppColor.secondaryCalm`, `AppColor.surfaceTint`, `AppSpacing`, `AppLayout`, and the new `AppTypography.homeLogoIcon` token.
- Respected `accessibilityReduceMotion` by showing the final resting state immediately.
- Kept existing Home screen UI test hooks (`home.statusIcon`, `home.title`, `home.statusLabel`, `home.settingsButton`).

**Validation:**
- `xcodebuild build -scheme EyePostureReminder -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` ✅
- `xcodebuild test -scheme EyePostureReminder -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` ✅

## Session 8: Yin-Yang SVG-Style Rewrite

**Date:** 2025-07-22
**Task:** Rewrite YinYangEyeView to match approved HTML prototype with proper yin-yang shape

### What Changed

1. **YinYangEyeView.swift** — Full rewrite:
   - Replaced SF Symbol orbiting eyes with SwiftUI Path-drawn yin-yang symbol
   - Created `YinYangHalfShape` (private Shape) using arc-based paths for yin/yang halves
   - Yin half: `AppColor.primaryRest` (sage), Yang half: `AppColor.surfaceTint` (mint)
   - Dots at 25% and 75% vertical positions using opposite colors
   - Border ring with `AppColor.separatorSoft`
   - Two-phase animation: spin (360°/2s deceleration) → breathe (scale 1.0↔1.06, 8s cycle)
   - `accessibilityReduceMotion` skips all animations

2. **OnboardingWelcomeView.swift** — Replaced `WelcomeHeroCard` with `YinYangEyeView()`:
   - Removed dead `WelcomeHeroCard` and `HeroIcon` structs
   - Yin-yang serves as the hero visual on welcome screen
   - Preserved accessibility label for illustration

### Learnings

- SwiftUI `Path.addArc` clockwise parameter is inverted from SVG convention (SwiftUI uses flipped Y-axis coordinates). When converting SVG arc sweeps, flip the clockwise boolean.
- For yin-yang S-curve: the trick is two small arcs (radius = R/2) centered at 25% and 75% of the diameter on the center axis, with opposite sweep directions per half.
- `DispatchQueue.main.asyncAfter` works well for sequencing animation phases (spin then breathe) without complex state machines.

**Build:** ✅ `xcodebuild build` passed

### 2026-04-27: Yin-Yang SwiftUI Implementation — Complete

- **Context:** Six-agent sprint on Restful Grove branding component. Tess implemented custom Path yin-yang logo.
- **Deliverable:** `YinYangEyeView.swift` — custom SwiftUI Shape + Path (no SF Symbols), two-phase animation (Spin → Breathe), full reduce-motion compliance.
- **Integration:** Added to `OnboardingView` and `HomeView` hero areas. Single source of truth for logo.
- **Testing:** 9 comprehensive tests (Livingston) — all passing. Build passing.
- **Decisions:** Merged 5 decisions into `.squad/decisions/decisions.md` (Tess, Danny, Rusty, Roman contributions). Inbox cleared.
- **Session artifacts:** `.squad/orchestration-log/2026-04-27T03-41-00Z-*.md`, `.squad/log/2026-04-27T03-41-00Z-yinyang-implementation.md`

### 2026-04-28: Logo Contrast + App Icon Adaptive Direction

**Task:** Visual direction for improving yin-yang logo visibility across light/dark mode and enabling adaptive app icon variants.

**Root cause identified:** `YinYangEyeView` uses `AppColor.surfaceTint` for the yang (mint) half. `surfaceTint` values (`#EEF6F1` light / `#203128` dark) are designed as card background washes — not filled logo elements. Against the Restful Grove backgrounds (`#F8F4EC` warm white / `#101714` deep forest), contrast ratios are ~1.01:1 and ~1.37:1 respectively — essentially invisible.

**Direction filed:** `.squad/decisions/inbox/tess-logo-contrast-direction.md`

**Key color decisions:**
- New `AppColor.logoMint` token needed: Light `#3CA882` (~3.6:1 on `#F8F4EC` ✅), Dark `#446E58` (~3.8:1 on `#101714` ✅)
- `AppColor.surfaceTint` must NOT change — card surfaces are correct; logo is the wrong use of that token
- `AppColor.primaryRest` (yin half) is correct in both modes — no change needed

**App icon dark/light variants:** iOS 18 / Xcode 16 supports dark appearance entries in `AppIcon.appiconset/Contents.json`. Current asset has no dark variant. Direction given to add dark entries with deep forest background + contrast-boosted logo.

**Key file paths confirmed:**
- `EyePostureReminder/Views/YinYangEyeView.swift` — logo component (surfaceTint → logoMint swap target)
- `EyePostureReminder/Resources/Colors.xcassets/RGSurfaceTint.colorset/Contents.json` — current wrong token values
- `EyePostureReminder/Resources/Colors.xcassets/RGPrimaryRest.colorset/Contents.json` — correct, no change
- `EyePostureReminder/AppIcon.xcassets/AppIcon.appiconset/Contents.json` — no dark variant yet

### 2026-04-28 — Logo Contrast Analysis & Design Direction (Wave 17)

**Task:** Identify and fix yin-yang logo contrast issues in light/dark mode.

**Outcome:** ✅ Direction delivered — design analysis and implementation guidance filed.

**Work completed:**
- Analyzed contrast failure in `YinYangEyeView`: `AppColor.surfaceTint` insufficient for logo fill
  - Light: `#EEF6F1` vs `#F8F4EC` background = ~1.01:1 contrast (invisible)
  - Dark: `#203128` vs `#101714` background = ~1.37:1 contrast (barely visible)
- Root cause: `surfaceTint` is correct for surface washes (card tints), wrong for logo fills
- Recommended `AppColor.logoMint` with values meeting WCAG 1.4.11:
  - Light: `#3CA882` — ~3.6:1 contrast ✅
  - Dark: `#446E58` — ~3.8:1 contrast ✅
- Provided visual rationale and two implementation paths (Option A: clean token; Option B: local private color)
- Dark icon appearance guidance for iOS 18+ (using `appearances` entries in Contents.json)
- Acceptance criteria documented for light/dark visibility and no regression to other surfaces

**Decisions filed:**
- `.squad/decisions/decisions.md` — Design Direction (full analysis + acceptance criteria)

**Coordination:**
- Design direction reviewed by Linus (engineer) for feasibility
- Linus selected Option A (clean token) and implemented with successful outcome

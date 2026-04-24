# Project Context

- **Owner:** Yashasg
- **Project:** Eye & Posture Reminder — a lightweight iOS app with background timers and full-screen overlay reminders for eye breaks (20-20-20 rule) and posture checks
- **Stack:** Swift, SwiftUI (iOS 16+), MVVM, UserNotifications, UIKit overlay, UserDefaults
- **Created:** 2026-04-24

## Learnings

### 2026-04-25 — Asset Catalog Color Migration (Decision 2.18)

- **Deliverable:** 6 color sets in `EyePostureReminder/Resources/Colors.xcassets/`, DesignSystem.swift refactored, UIKit import removed
- **Color tokens:** ReminderBlue (#4A90D9/#5BA8F0), ReminderGreen (#34C759/#30D158), WarningOrange (#E07000/#FF9500), WarningText (#994F00/#FF9500), PermissionBanner (#FFCC00 static), PermissionBannerText (#262626 static)
- **Implementation:** Replaced all `UIColor(dynamicProvider:)` + `Color(red:green:blue:)` with `Color("name")` asset references
- **Result:** DesignSystem.swift now pure SwiftUI (no UIKit import); dark/light adaptation handled by Asset Catalog JSON, not Swift logic
- **Build verified:** `./scripts/build.sh build` → BUILD SUCCEEDED
- **Decision filed:** `.squad/decisions/decisions.md` (Decision 2.18)

## Learnings

### 2026-04-24: Design System Foundation

- Created `EyePostureReminder/Views/DesignSystem.swift` — SwiftUI design tokens (colors, fonts, spacing, animations, SF symbols, layout constants).
- Created `docs/DESIGN_SYSTEM.md` — full human-readable spec with contrast tables, overlay layout ASCII diagrams, accessibility notes, Dark Mode guidance.
- **Color decisions:**
  - `reminderBlue` (#4A90D9) for eye breaks — calming, distinct from system blue.
  - `reminderGreen` (#34C759) for posture — matches iOS system green (familiar).
  - `warningOrange` (#FF9500) for "Rest of day" snooze — communicates consequence without full destructive red.
  - `permissionBanner` (#FFCC00) — warm yellow to signal warning, not error.
- **White text on reminderGreen fails WCAG AA at small sizes** — use dark text on green backgrounds.
- **Overlay uses `.systemUltraThinMaterial`** — handles dark/light automatically; no manual background adaptation needed.
- Snooze flow per Reuben's two-phase model: clean countdown overlay → snooze sheet only after manual dismiss.
- Overlay layout: × top-right, ⚙ bottom-center, icon 80pt centered, 160pt countdown ring with 8pt stroke.
- Swipe UP gesture (not down) to dismiss overlay, matching the slide-up presentation direction.
- All interactive elements at minimum 44pt tap target (iOS HIG).
- Monospaced countdown font (`design: .monospaced`) prevents digit-width jitter as numbers decrease.

### 2026-04-25 — Data-Driven App Configuration (Danny Decision 3.6)

- **Theme values in spec:** Colors (reminderBlue light #4A90D9 / dark #5BA8F0, reminderGreen, warningOrange, permissionBanner, permissionBannerText, onboardingAccent), fonts, spacing (xs–xl), layout (tap targets, overlay icon, countdown ring), animations, SF symbols.
- **Tess ownership:** Validate JSON hex values against current `DesignSystem.swift` tokens; confirm contrast ratios for all color pairs.
- **Future:** Support per-device/per-OS variants in config structure.

### 2026-04-25: Dark Mode Colour Adaptation

- **No in-app colour scheme toggle** — app follows OS appearance exclusively. No `.preferredColorScheme` modifier exists anywhere in the codebase; confirmed clean.
- `reminderBlue` is now adaptive via `UIColor(dynamicProvider:)`: light #4A90D9 → dark #5BA8F0 (brighter for dark-background contrast).
- `reminderGreen` now uses `Color(.systemGreen)` — iOS automatically adapts between #34C759 (light) and #30D158 (dark).
- `warningOrange` is now adaptive: light #E07000 (~3.5:1 on white, meets WCAG 1.4.11 non-text contrast) → dark #FF9500 (6.8:1 on near-black).
- `warningText` was already adaptive (UIColor dynamicProvider) — no change needed.
- `overlayBackground` was already using `Color(.systemBackground)` — no change needed.
- `permissionBanner` (yellow) intentionally static in both modes — warning yellow reads correctly on both backgrounds.
- `permissionBannerText` remains near-black — exclusively used on the yellow banner, where dark text contrast is high regardless of mode.
- No hardcoded `.foregroundColor(.black)` or `.background(.white)` found in any view file — all views were clean.
- OverlayView uses `.ultraThinMaterial` — automatically adapts to dark/light mode.
- **WCAG non-text contrast (1.4.11) requires 3:1** for UI components/icons — warningOrange in light mode was previously #FF9500 at 2.7:1 (below threshold); now fixed to #E07000 at 3.5:1.

### 2026-04-25 — Wave 3: Dark Mode Color Adaptation

**Task:** Design and implement dark mode color system for DesignSystem.swift  
**Status:** ✅ SUCCESS — Implemented, build clean  

**Changes Made:**

1. **`reminderBlue` → Adaptive (UIColor dynamicProvider)**
   - Light: #4A90D9 (unchanged)
   - Dark: #5BA8F0 (brighter, improves dark-background contrast from ~2.9:1 to ~4:1)

2. **`reminderGreen` → System color (Color(.systemGreen))**
   - Light: #34C759 | Dark: #30D158
   - Delegates to iOS system adaptation — zero-risk, automatic future updates

3. **`warningOrange` → Adaptive (UIColor dynamicProvider)**
   - Light: #E07000 (WCAG fix: 2.7:1 → 3.5:1 on white)
   - Dark: #FF9500 (unchanged, 6.8:1 on near-black)
   - Addressed real accessibility bug as part of dark mode work

4. **`permissionBanner` → Static #FFCC00 (both modes)**
   - Yellow "caution" signal intentionally constant across modes

5. **`permissionBannerText` → Static #262626 (both modes)**
   - High contrast (>10:1) on yellow background in both modes

**Policy Decisions:**
- No `.preferredColorScheme` modifier anywhere (permanent — reject future in-app toggle requests)
- All view files were already clean (semantic colors, `.ultraThinMaterial`, `.systemBackground`)
- View files require zero changes — DesignSystem.swift update is the entire implementation

**Verification:**
- ✅ Build succeeded, no warnings
- ✅ No view file modifications needed
- ✅ Integration with Danny's dark mode spec complete
- ✅ Ready for visual QA in next cycle

## Learnings

### 2026-04-26: Color Token Migration to Asset Catalog

**Task:** Migrate all 6 AppColor tokens from hardcoded Swift to `Colors.xcassets`  
**Status:** ✅ SUCCESS — Build clean

**Changes Made:**

1. **`EyePostureReminder/Resources/Colors.xcassets/`** — created with 6 `.colorset` entries:
   - `ReminderBlue`: light #4A90D9 / dark #5BA8F0
   - `ReminderGreen`: light #34C759 / dark #30D158
   - `WarningOrange`: light #E07000 / dark #FF9500
   - `WarningText`: light #994F00 / dark #FF9500
   - `PermissionBanner`: static #FFCC00 (both modes)
   - `PermissionBannerText`: static #262626 (both modes)

2. **`DesignSystem.swift`** — replaced all `UIColor(dynamicProvider:)` and `Color(red:green:blue:)` with `Color("Name")`; removed `import UIKit`

3. **`Package.swift`** — added `.process("Resources")` to SPM target so `.xcassets` is bundled

**Key Learnings:**
- SPM requires explicit `.process("Resources")` in target resources for `.xcassets` to be compiled and bundled
- Static colors (same light/dark) in `.colorset` use a single entry with no `appearances` array
- `import UIKit` can be fully removed from `DesignSystem.swift` once all `UIColor` references are gone
- Asset catalog colors are the canonical iOS pattern — light/dark adaptation is declarative, not imperative
- `Color("Name")` is safe (no crash on miss), but name typos produce invisible failures — treat asset names as stable API

## Learnings

### 2026-04-26: Screen-Time-Based Trigger UX Review

**Task:** UX review of Danny's screen-time trigger spec (Decision: continuous screen-on time vs fixed wall-clock intervals) and Rusty's architecture amendments (grace period, ScreenTimeTracker service).  
**Status:** ✅ Review complete — `tess-screen-time-ux-review.md` filed

**Key findings:**

- **Critical onboarding copy bug:** `onboarding.permission.body1` ("Reminders arrive as notifications — so the app works even when you're not looking at it") is now factually false. Foreground-only delivery is the new model. This string must change before launch.
- **Secondary onboarding bug:** `onboarding.welcome.body` ("Works quietly in the background") also needs updating — background delivery is gone.
- **Settings copy pattern:** `"Remind me every"` → `"Remind me after"` + section footer ("Timer resets when you lock your phone.") is cleaner than appending "of screen time" to every picker row.
- **HomeView: no progress indicator.** Showing elapsed screen time creates anxiety and contradicts the app's "calm nudge" positioning. Keep it as-is.
- **OverlayView: no changes.** Trigger mechanism changed, overlay experience is identical.
- **Grace period: invisible by design.** The 5-second debounce on willResignActive is a pure implementation detail — no user-facing copy needed.
- **ReminderRowView hardcoded strings:** The picker label `"Remind me every"` and its accessibility hint are hardcoded Swift strings, not in `Localizable.xcstrings`. Flag for Linus to migrate before copy changes are made.
- **Notification permission framing:** Notifications now serve snooze-wake only, not primary reminders. The permission screen's urgency must soften accordingly — frame around snooze, not primary delivery.
- **Master toggle footer (new):** Add `"Reminders only appear while this app is open."` to address Danny's open question about foreground-only UX communication — Settings footer is the right low-friction placement.

**Design principles reinforced:**
- iOS users understand "screen time" — lean on Apple's vocabulary rather than inventing terms like "continuous use"
- "After" implies accumulation toward a threshold; "every" implies clock cycles — one word carries the entire mental model difference
- Never surface implementation details (grace periods, timer debounce) as user-facing UX

---

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


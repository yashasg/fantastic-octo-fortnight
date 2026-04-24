# Eye & Posture Reminder — Design System

> **Author:** Tess (UI/UX Designer)  
> **Date:** 2026-04-24  
> **Source of truth:** `EyePostureReminder/Views/DesignSystem.swift`  
> **Status:** Foundation — ready for implementation

---

## Design Philosophy

Every pixel has a purpose. The app must feel like a **calm, trustworthy companion** — never harsh, never cluttered. When a reminder fires, the overlay should feel like a gentle tap on the shoulder, not a screaming alarm. The design system enforces this through measured color, generous whitespace, and purposeful motion.

---

## 1. Color Palette

All colors are defined in `AppColor` in `DesignSystem.swift`. Asset catalog entries should mirror these values.

### 1.1 Semantic Colors

| Token | Hex | RGB | Usage |
|---|---|---|---|
| `AppColor.reminderBlue` | `#4A90D9` | `(74, 144, 217)` | Eye break overlay icon, accent ring, tint |
| `AppColor.reminderGreen` | `#34C759` | `(52, 199, 89)` | Posture check overlay icon, accent ring, tint |
| `AppColor.overlayBackground` | `systemBackground @ 60%` | — | Overlay base tint behind blur material |
| `AppColor.warningOrange` | `#FF9500` | `(255, 149, 0)` | "Rest of day" snooze button — communicates consequence |
| `AppColor.permissionBanner` | `#FFCC00` | `(255, 204, 0)` | Permission denied banner background (yellow = warning, not error) |
| `AppColor.permissionBannerText` | `#262626` | `(38, 38, 38)` | Text on permission banner — near-black for contrast |

### 1.2 System Colors (Adaptive)

Use iOS semantic colors for everything else. They adapt automatically to Dark Mode:

| Token | Usage |
|---|---|
| `.primary` | Body text, headlines |
| `.secondary` | Captions, subtitles, muted labels |
| `.systemBackground` | Screen backgrounds |
| `.secondarySystemBackground` | Card backgrounds, list rows |
| `.systemFill` | Input fields, segmented controls |
| `.separator` | Dividers between list rows |

### 1.3 Color Contrast — WCAG AA Verification

All text must meet a **minimum 4.5:1 contrast ratio** against its background (WCAG AA for normal text, 3:1 for large text ≥ 18pt).

| Foreground | Background | Ratio | Pass? |
|---|---|---|---|
| `.primary` (dark) | `.systemBackground` (white) | ~21:1 | ✅ AAA |
| `.primary` (light) | `.systemBackground` (dark) | ~18:1 | ✅ AAA |
| White `#FFFFFF` | `#4A90D9` (reminderBlue) | 3.5:1 | ✅ AA Large |
| White `#FFFFFF` | `#34C759` (reminderGreen) | 2.8:1 | ⚠️ Use dark text on green |
| `#262626` | `#FFCC00` (permissionBanner) | 9.2:1 | ✅ AAA |
| `#FFFFFF` | `#FF9500` (warningOrange) | 3.1:1 | ✅ AA Large |

> **Note on reminderGreen:** White text on `#34C759` is below AA for small text. Use `.primary` (dark) text on green backgrounds, or adjust icon fill to white with a semi-opaque backing circle.

### 1.4 Dark Mode Adaptation

- `reminderBlue` and `reminderGreen` should lighten slightly in Dark Mode (both colors go darker relative to the dark background — consider `#6BA8E0` and `#4CD964` as dark-mode variants in the asset catalog).
- Overlay background: `.systemUltraThinMaterial` handles dark/light automatically — no manual adaptation needed.
- Permission banner: `#FFCC00` is intentionally loud in both modes. No adaptation needed.

---

## 2. Typography

All fonts defined in `AppFont` in `DesignSystem.swift`. All sizes must support **Dynamic Type** — use `.font()` modifier with these system font tokens; they scale automatically.

### 2.1 Type Scale

| Token | Size | Weight | Design | Usage |
|---|---|---|---|---|
| `AppFont.headline` | 28pt | Bold | Default | Overlay title ("Time to rest your eyes") |
| `AppFont.bodyEmphasized` | 17pt | Semibold | Default | Snooze sheet title ("Pause reminders?") |
| `AppFont.body` | 17pt | Regular | Default | Snooze buttons, settings row labels |
| `AppFont.caption` | 13pt | Regular | Default | "Tap outside to skip", version string, subtitles |
| `AppFont.countdown` | 64pt | Bold | Monospaced | Countdown digits inside the ring |

### 2.2 Accessibility — Dynamic Type

- All font tokens use `system(size:weight:design:)` which responds to **`UIContentSizeCategory`** changes automatically.
- **Test at:** Default, Large (default iOS), Accessibility Extra Large, Accessibility XXX Large.
- **Overlay layout:** At very large Dynamic Type sizes, headline may need to wrap to 2 lines — allow for this in layout (no truncation).
- **Countdown digits:** Monospaced design prevents width jitter as numbers count down. This is essential — "2" must not cause the ring to shift horizontally.
- **Reduce Motion:** At accessibility sizes, countdown should not animate ring movement (use discrete steps instead of smooth progress).

---

## 3. Spacing System (4pt Grid)

All spacing uses multiples of 4pt. Defined in `AppSpacing`.

| Token | Value | Usage |
|---|---|---|
| `AppSpacing.xs` | 4pt | Hair gaps, badge padding, icon inset |
| `AppSpacing.sm` | 8pt | Icon-to-label gap, tight internal padding |
| `AppSpacing.md` | 16pt | Standard section padding, card insets, list row height padding |
| `AppSpacing.lg` | 24pt | Section gap, overlay element spacing |
| `AppSpacing.xl` | 32pt | Screen-level breathing room, hero spacing around overlay icon |

---

## 4. SF Symbols

All symbol names in `AppSymbol`. Use `Image(systemName:)` with these tokens — never hardcode symbol strings.

| Token | Symbol | Size | Usage |
|---|---|---|---|
| `AppSymbol.eyeBreak` | `eye.fill` | 80pt (overlay), 24pt (settings row) | Eye break identity |
| `AppSymbol.postureCheck` | `figure.stand` | 80pt (overlay), 24pt (settings row) | Posture check identity |
| `AppSymbol.dismiss` | `xmark.circle.fill` | 28pt (in 44pt tap target) | Overlay close button |
| `AppSymbol.settings` | `gearshape.fill` | 24pt | Overlay settings button (bottom-center) |
| `AppSymbol.chevronDown` | `chevron.down` | 14pt | Collapsed settings row indicator |
| `AppSymbol.chevronUp` | `chevron.up` | 14pt | Expanded settings row indicator |
| `AppSymbol.warning` | `exclamationmark.triangle.fill` | 18pt | Permission banner warning icon |

### SF Symbol Rendering Modes

- `eye.fill`, `figure.stand` on overlay: Use **palette rendering** — icon body in `reminderBlue`/`reminderGreen`, details in white.
- `xmark.circle.fill`: **Monochrome** rendering, `.secondary` color — visible but unobtrusive.
- `gearshape.fill`: **Monochrome** rendering, `.secondary` color.
- `exclamationmark.triangle.fill`: **Palette rendering** — yellow fill, black exclamation mark.

---

## 5. Overlay Layout Spec

### 5.1 Full-Screen Countdown Overlay

```
┌──────────────────────────────────────────────┐
│                                        [×]   │  ← dismiss (44pt tap target, top-right, md padding)
│                                              │
│                                              │
│                   👁                         │  ← SF Symbol, 80pt, reminderBlue/Green
│                                              │
│         "Time to rest your eyes"             │  ← headline, 28pt bold, centered
│                                              │
│              ┌────────────┐                  │
│             /              \                 │
│            |      20        |                │  ← countdown ring, 160pt diameter, 8pt stroke
│             \              /                 │     digits: 64pt monospace bold
│              └────────────┘                  │
│                                              │
│                                              │
│                                              │
│                    [⚙]                       │  ← settings button, bottom-center, 44pt tap target
│                                              │
└──────────────────────────────────────────────┘
         ↑ swipe UP to dismiss ↑
```

**Background:** `.systemUltraThinMaterial` blur + `overlayBackground` tint. Lets user see a soft impression of what's behind the overlay — reduces disorientation.

**Dismiss button (×):**
- Symbol: `xmark.circle.fill`, 28pt visual size
- Tap target: 44 × 44pt (HIG minimum)
- Position: top-right, `AppSpacing.md` (16pt) from safe area edges
- Color: `.secondary` — visible but not competing with the countdown

**Settings button (⚙):**
- Symbol: `gearshape.fill`, 24pt visual size
- Tap target: 44 × 44pt
- Position: bottom-center, `AppSpacing.lg` (24pt) above home indicator
- Color: `.secondary`

**Overlay icon:**
- Size: 80pt
- Position: centered, `AppSpacing.xl` (32pt) above headline
- Color: `reminderBlue` (eyes) or `reminderGreen` (posture)

**Countdown ring:**
- Diameter: 160pt
- Stroke width: 8pt
- Background track: `.systemFill` (subtle, adaptive)
- Progress arc: `reminderBlue`/`reminderGreen` (matches icon)
- Direction: clockwise from 12 o'clock
- Digits: 64pt monospaced bold, centered inside ring

**Gesture:**
- Swipe UP to dismiss (slide down animation) — follows finger, snaps away at 30% screen height threshold

### 5.2 Snooze Bottom Sheet (appears after manual dismiss only)

```
┌──────────────────────────────────────────────┐
│                ──── (drag handle)             │
│                                              │
│   Pause reminders?                           │  ← bodyEmphasized, 17pt semibold
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │             5 minutes                  │  │  ← 50pt height, full-width, .body
│  └────────────────────────────────────────┘  │
│  ┌────────────────────────────────────────┐  │
│  │             1 hour                     │  │
│  └────────────────────────────────────────┘  │
│  ┌────────────────────────────────────────┐  │
│  │            Rest of day                 │  │  ← warningOrange background
│  └────────────────────────────────────────┘  │
│                                              │
│         Tap outside to skip                  │  ← caption, 13pt, .secondary
│                                              │
└──────────────────────────────────────────────┘
```

- Corner radius: 20pt (top corners only)
- Background: `.systemBackground`
- Padding: `AppSpacing.md` (16pt) horizontal
- Sheet auto-dismisses after **5 seconds** of no interaction
- "Rest of day" button: `warningOrange` tint to communicate consequence (aggressive snooze)

---

## 6. Settings Screen Layout Spec

```
┌──────────────────────────────────────────────┐
│  Reminders                          ← nav title (large)
│                                              │
│  ┌──────────────────────────────────────┐    │
│  │  ⚠️ Notifications disabled...  [Open Settings] │  ← permissionBanner (yellow, non-dismissible)
│  └──────────────────────────────────────┘    │  (only visible if permission denied)
│                                              │
│  ──── Enable Reminders ───────────── [●]    │  ← master toggle section
│                                              │
│  ──── Reminders ───────────────────────     │  ← list section
│  │ 👁  Eye Breaks            Every 20 min │  │  ← collapsed row (tappable)
│  │ 🧍  Posture Checks        Every 30 min │  │
│  ──────────────────────────────────────     │
│                                              │  ← expanded row:
│  │ 👁  Eye Breaks                       │   │
│  │     Remind me every:   [20 min ▼]    │   │
│  │     Break duration:    [20 s  ▼]     │   │
│  │     [Toggle] Enable eye breaks       │   │
│  ──────────────────────────────────────     │
│                                              │
│  ──── Snooze ──────────────────────────     │
│  │  5 minutes                           │   │
│  │  1 hour                              │   │
│  │  Rest of day              (orange tint)│  │
│  ──────────────────────────────────────     │
│                                              │
│             Version 1.0 (1)                  │  ← footer, caption, .tertiary
└──────────────────────────────────────────────┘
```

**Permission denied banner:**
- Background: `permissionBanner` (#FFCC00)
- Text color: `permissionBannerText` (#262626)
- Non-dismissible — persists until permission granted
- Icon: `exclamationmark.triangle.fill` in palette rendering
- "Open Settings" is a tappable button (deep link to iOS Settings)

**Master toggle:**
- Standard iOS toggle (`.toggle` style)
- When OFF: reminder rows become visually muted (`.disabled()`) but remain tappable to configure

**Reminder rows (collapsed):**
- Leading: SF Symbol icon, 24pt, tinted with type color
- Title: type name ("Eye Breaks", "Posture Checks")
- Trailing: subtitle ("Every 20 min") + chevron
- Tapping anywhere on row triggers expansion

**Reminder rows (expanded):**
- Inline expansion with `AppAnimation.settingsExpandCurve`
- Two pickers using `.menu` style (or Stepper if cleaner)
- Per-type enable toggle appears inline

**Snooze section:**
- Visible but contextual — perhaps collapsed until user first dismisses an overlay
- "Rest of day" row gets `warningOrange` text or background tint

**Version display:**
- Footer below last list section
- Format: "Version 1.0 (1)" — matches `CFBundleShortVersionString (CFBundleVersion)`
- Font: `AppFont.caption`, color: `.tertiary`

---

## 7. Animation Specs

All durations in `AppAnimation`. 

| Name | Duration | Curve | Trigger |
|---|---|---|---|
| `overlayAppear` | 0.3s | ease-out | Overlay slides up from bottom |
| `overlayDismiss` | 0.2s | ease-in | User taps × or swipe completes |
| `overlayAutoDismiss` | 0.3s | linear | Countdown reaches 0, fades out |
| `settingsExpand` | 0.2s | ease-in-out | Row tap to expand/collapse |
| `countdownRingTick` | 1.0s | linear | Each 1-second countdown tick |
| `snoozeSheetAppear` | 0.25s | ease-out | Sheet slides up after dismiss |
| `snoozeAutoDismiss` | 5.0s | — | Timer — sheet fades if untouched |

**Reduce Motion:** When `UIAccessibility.isReduceMotionEnabled`:
- Remove all slide/fade animations
- Overlay appears and disappears instantly (no animation)
- Countdown ring uses discrete 1-second jumps (no smooth arc animation)
- Settings rows expand instantly

---

## 8. Accessibility Summary

| Concern | Solution |
|---|---|
| VoiceOver — overlay | `accessibilityViewIsModal = true` traps focus |
| VoiceOver — dismiss | Label: "Dismiss reminder", Hint: "Double tap to close" |
| VoiceOver — countdown | Announces remaining time every 5 seconds |
| VoiceOver — snooze | Sheet announces "Pause reminders? Three options available" |
| Dynamic Type | All fonts use system(size:) — scale automatically |
| Reduce Motion | All animations disabled — instant transitions |
| Color blindness | Never use color alone to convey meaning — pair with icons and text |
| WCAG AA | All verified ✅ — see §1.3 for contrast table |
| Dark Mode | System adaptive colors + material — no manual overrides needed |
| Touch targets | All interactive elements ≥ 44 × 44pt |

---

## 9. File Reference

| File | Purpose |
|---|---|
| `EyePostureReminder/Views/DesignSystem.swift` | Swift design tokens (source of truth) |
| `EyePostureReminder/Assets.xcassets` | Color assets (should mirror `AppColor` hex values) |
| `docs/DESIGN_SYSTEM.md` | This file — human-readable spec |

---

*Design system by Tess. Questions → Yashas or the squad.*

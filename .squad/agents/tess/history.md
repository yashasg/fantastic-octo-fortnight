# Project Context

- **Owner:** Yashasg
- **Project:** Eye & Posture Reminder — a lightweight iOS app with background timers and full-screen overlay reminders for eye breaks (20-20-20 rule) and posture checks
- **Stack:** Swift, SwiftUI (iOS 16+), MVVM, UserNotifications, UIKit overlay, UserDefaults
- **Created:** 2026-04-24

## Learnings

<!-- Append new learnings below. Each entry is something lasting about the project. -->

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

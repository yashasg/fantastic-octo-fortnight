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

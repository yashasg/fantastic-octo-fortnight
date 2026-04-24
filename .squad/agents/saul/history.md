# Project Context

- **Owner:** Yashasg
- **Project:** Eye & Posture Reminder — a lightweight iOS app with background timers and full-screen overlay reminders for eye breaks (20-20-20 rule) and posture checks
- **Stack:** Swift, SwiftUI (iOS 16+), MVVM, UserNotifications, UIKit overlay, UserDefaults
- **Created:** 2026-04-24

## Learnings

<!-- Append new learnings below. Each entry is something lasting about the project. -->

### 2026-04-24: Phase 1 Code Review (M1.8)
- **Reviewed:** All 16 Swift source files, 7 test files, Package.swift, ARCHITECTURE.md
- **Verdict:** Conditional Approval — 0 P0, 4 P1, 7 P2 issues
- **Key P1s:**
  1. Snooze not guarded in `scheduleReminders()` — will break when snooze UI ships
  2. `AppCoordinator` hardcodes `UNUserNotificationCenter.current()` for auth — untestable
  3. `OverlayManager.shared` used directly instead of injected `OverlayPresenting` protocol
  4. Fixed font sizes in `DesignSystem.swift` break Dynamic Type accessibility
- **Positive:** Protocol-driven testing is strong (65+ tests), memory management is correct, no retain cycles, thread safety via @MainActor is sound
- **Architecture:** Dependencies flow correctly. `OverlayManager → OverlayView` is the only Service→View coupling, acceptable as UIKit bridge
- **Pattern to watch:** `@State` used for SettingsViewModel (reference type) — works today since VM has no @Published bindings, but fragile if VM evolves

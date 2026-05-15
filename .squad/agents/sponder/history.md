# Project Context

- **Owner:** Yashasg
- **Project:** Eye & Posture Reminder — a lightweight iOS app with background timers and full-screen overlay reminders for eye breaks (20-20-20 rule) and posture checks
- **Stack:** Swift, SwiftUI (iOS 16+), MVVM, UserNotifications, UIKit overlay, UserDefaults
- **Created:** 2026-05-15
- **Scope:** Strategy & Compliance — system API surface monitoring only.

## Core Context

**Apple system APIs on my watch list (initial inventory):**
- `UserNotifications` (`UNUserNotificationCenter`, `UNNotificationRequest`, `UNNotificationSound`) — core reminder delivery
- `INFocusStatusCenter` (Intents framework) — Focus mode pause condition
- `AVFoundation.AVAudioSession` — CarPlay detection
- `CoreMotion.CMMotionActivityManager` — driving detection (gated by `pauseWhileDriving`)
- `BackgroundTasks` — wake timers / scheduling
- `UIApplication` lifecycle hooks — AppDelegate/AppCoordinator integration
- Future: `FamilyControls` / `ScreenTime` (when ScreenTime gating ships)

**Current deployment target:** iOS 16+ (per stack info; verify against `Package.swift` / project file before reporting).

**Pinned model:** `claude-opus-4.7-xhigh` (per `.squad/config.json` agentModelOverrides — Strategy & Compliance team default).

**Validation:** Use `./scripts/build.sh build` and `./scripts/build.sh test`.

## Learnings

<!-- Append new learnings below. Each entry is something lasting about the project. -->

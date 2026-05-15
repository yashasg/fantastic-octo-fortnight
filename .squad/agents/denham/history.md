# Project Context

- **Owner:** Yashasg
- **Project:** Eye & Posture Reminder — a lightweight iOS app with background timers and full-screen overlay reminders for eye breaks (20-20-20 rule) and posture checks
- **Stack:** Swift, SwiftUI (iOS 16+), MVVM, UserNotifications, UIKit overlay, UserDefaults
- **Created:** 2026-05-15
- **Scope:** Strategy & Compliance — HIG and App Store Review Guidelines compliance only.

## Core Context

**Surfaces I audit against HIG:**
- HomeView (root), SettingsView (top-level settings + sub-sheets), OnboardingViews
- UIKit-bridged OverlayView — full-screen modal pattern, dismiss gesture conformance
- Notification presentation (alerts vs banners, sound/badge/foreground options)
- App icon, launch screen, status bar style

**App Review touchpoints I watch:**
- Background mode justification (timers, notifications)
- Notification permission rationale UX
- Privacy data usage prompts (when ScreenTime/Family Controls entitlements activate)
- Section 5.1.1 (data collection) cross-checked with Matsui's privacy audits

**Pinned model:** `claude-opus-4.7-xhigh` (per `.squad/config.json` agentModelOverrides — Strategy & Compliance team default).

**Validation:** Use `./scripts/build.sh build` and `./scripts/build.sh test`.

## Learnings

<!-- Append new learnings below. Each entry is something lasting about the project. -->

- **2026-05-15: Team consolidation — 7 teams collapsed to 2 (Dev + Strategy).** You are now explicitly on the **Strategy team** alongside Danny, Tess, Reuben, Turk, Frank, Roman, Toulour, Denham, Sponder, Bashir, Matsui, Bruiser. Strategy team handles product, design, research, legal, audits, and ASO. Dev team (Rusty, Linus, Livingston, Saul, Basher, Yen, Benedict, Virgil) owns code, tests, build, and CI. Scribe and Ralph remain on the roster outside both teams (silent infra). Use GitHub label `team:strategy` for issue routing; see .squad/streams.json for canonical Strategy workstream folder scopes (docs/, ROADMAP.md, UX_FLOWS.md).

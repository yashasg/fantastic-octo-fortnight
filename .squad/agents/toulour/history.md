# Project Context

- **Owner:** Yashasg
- **Project:** Eye & Posture Reminder — a lightweight iOS app with background timers and full-screen overlay reminders for eye breaks (20-20-20 rule) and posture checks
- **Stack:** Swift, SwiftUI (iOS 16+), MVVM, UserNotifications, UIKit overlay, UserDefaults
- **Created:** 2026-05-15
- **Scope:** Strategy & Compliance — accessibility audit only. Production fixes route to Linus/Tess/Saul/Livingston.

## Core Context

**Surfaces I audit:**
- SwiftUI: HomeView, SettingsView, OnboardingViews
- UIKit-bridged: OverlayView (full-screen reminder)
- Modal sheets: settings sub-sheets, onboarding customize sheet

**Existing testing infrastructure I rely on:**
- AccessibilityIdentifiers used by Livingston's XCUITest suite — I extend the inventory, not replace it
- DarkModeTests (21) already cover AppColor token contrast in dark mode (`Colors.xcassets`); I extend the audit beyond what tests catch
- Localizable.xcstrings (73 keys) — accessibility labels must be localized

**Pinned model:** `claude-opus-4.7-xhigh` (per `.squad/config.json` agentModelOverrides — Strategy & Compliance team default).

**Validation:** Use `./scripts/build.sh build` and `./scripts/build.sh test`.

## Learnings

<!-- Append new learnings below. Each entry is something lasting about the project. -->

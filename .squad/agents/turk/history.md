# Turk — History

## Core Context

- **Project:** Eye & Posture Reminder — lightweight iOS app with background timers and overlay reminders
- **Stack:** Swift, SwiftUI (iOS 16+), MVVM, UserNotifications, UIKit overlay, UserDefaults
- **Owner:** Yashas
- **Joined:** 2026-04-24
- **Telemetry strategy (from Rusty):** Native Apple tools first — App Store Connect Analytics (free), MetricKit (Phase 3+), os.Logger (Phase 2). No third-party analytics SDKs.
- **Key collaborators:** Tess (UI/UX), Reuben (Product Design)

## Learnings

### 2025-07-25 — Telemetry Schema & Dashboard Requirements

- **Revised phase timeline confirmed:** os.Logger moves to Phase 1 (M0.2), MetricKit moves to Phase 2 (first TestFlight). Rusty's testflight-telemetry decision was the trigger.
- **4 logger categories defined:** Scheduling, Overlay, Settings, AppLifecycle. All under subsystem `com.yashasg.eyeposturereminder`.
- **Log format standard:** `event_name key=value` structured pairs. Dynamic enums and ints use `privacy: .public`. Any string that could be user-authored uses `privacy: .private`.
- **MetricKit target payloads:** MXCrashDiagnostic and MXHangDiagnostic are highest priority for overlay correctness; MXAppExitMetric jetsam count is the memory health signal; MXBatteryMetric is the "health app trust" signal.
- **Dashboard tiers defined:** Tier 1 (App Store Connect — crash/session/energy), Tier 2 (usage patterns — dismissal mode, snooze), Tier 3 (settings patterns — interval combos), Tier 4 (UX health — permission rate, queue rate).
- **Privacy Nutrition Label stance:** "Data Not Collected" for all user-linked categories in Phase 1–2. Only update if Phase 3 introduces server-side MetricKit forwarding.
- **dSYMs critical:** Unsymbolicated crash reports in Xcode Organizer are near-useless. CI/CD must set `ENABLE_BITCODE = NO` and upload dSYMs on every TestFlight build.
- **Tess signal:** Swipe dismiss rate vs. manual dismiss rate reveals close button discoverability.
- **Reuben signal:** Snooze duration distribution validates preset choices and default value.

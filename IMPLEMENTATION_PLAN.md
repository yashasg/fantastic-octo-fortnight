# kshana — iOS App Implementation Plan

> **Scope:** Implementation plan only. No source code is included in this document.

---

## 1. Overview

A lightweight, battery-friendly iOS application that tracks foreground screen-on time via `ScreenTimeTracker` and presents full-screen overlay reminders to:

- **Rest your eyes** (e.g., the 20-20-20 rule – every 20 min, look 20 ft away for 20 s).
- **Fix your posture** (e.g., every 30 min, sit up straight for 10 s).

Users can customise:
- How often each reminder fires (the *reminder interval*).
- How long the break overlay stays on screen (the *break duration*).

The overlay is dismissible at any time. The app minimises CPU, memory, and battery usage by tracking continuous screen-on time in the foreground and using native iOS notification APIs only for snooze wake-ups.

---

## 2. Target Platform & Frameworks

| Concern | Framework / API |
|---|---|
| UI | **SwiftUI** (iOS 16+) |
| Background scheduling | **UserNotifications** (`UNUserNotificationCenter`) |
| Overlay window | **UIKit** – secondary `UIWindow` at `.alert` window level |
| Persistent settings | **UserDefaults** (lightweight key-value store) |
| App lifecycle | **UIApplicationDelegate** / `SceneDelegate` |
| Haptics (optional) | **CoreHaptics** / `UINotificationFeedbackGenerator` |
| Accessibility | **UIAccessibility** APIs |

No third-party dependencies are required.

---

## 3. Architecture

The app follows a simple **MVVM** structure with a single shared service layer.

```
EyePostureApp
├── App
│   ├── EyePostureApp.swift        – @main entry, scene setup
│   └── AppDelegate.swift          – notification delegate, background tasks
├── Models
│   ├── ReminderType.swift         – enum: .eyes / .posture
│   ├── ReminderSettings.swift     – struct: interval + breakDuration per type
│   └── SettingsStore.swift        – UserDefaults persistence
├── Services
│   ├── ReminderScheduler.swift    – schedules / cancels UNUserNotificationCenter requests
│   └── OverlayManager.swift       – creates / tears down the UIWindow overlay
├── ViewModels
│   └── SettingsViewModel.swift    – @ObservableObject bridging store ↔ UI
└── Views
    ├── SettingsView.swift          – main settings screen
    ├── ReminderRowView.swift       – per-reminder interval/duration pickers
    └── OverlayView.swift           – full-screen dismissible break screen
```

---

## 4. Core Feature Design

### 4.1 Reminder Scheduling Strategy

> **Current state (as of Phase 2 / Loop fixes):** The original wall-clock timer approach described below was shipped in Phase 1. In Phase 2 it was superseded by `ScreenTimeTracker`, which gates reminders on *actual screen-on time* rather than elapsed wall time. The scheduling infrastructure (`UNUserNotificationCenter`, `ReminderScheduler`) remains unchanged — only the trigger condition evolved.

**Why `UserNotifications` instead of a background timer?**

- A live `Timer` in the background is unreliable – iOS suspends apps after a few seconds of background activity.
- `UNUserNotificationCenter` is the standard, battery-efficient mechanism for time-based alerts; iOS wakes the app only when necessary.
- When the user taps the notification (or the app is in the foreground), `OverlayManager` presents the overlay instead.

**Phase 2 additions:**

| Component | Role |
|---|---|
| `ScreenTimeTracker` | Accumulates continuous screen-on time; replaces wall-clock intervals as the reminder trigger condition (M2.7) |
| `PauseConditionManager` | Aggregates Smart Pause conditions (Focus Mode, CarPlay, `CMMotionActivityManager` driving detection); automatically suspends scheduling while any condition is active |
| `ServiceLifecycle` | Uniform `start()` / `stop()` protocol implemented by all services; `AppCoordinator` drives the lifecycle |
| `AudioInterruptionManager` | Pauses media playback during break overlays when the user has opted in |

**Flow (current):**

```
App active (foreground)
        │
        ▼
ScreenTimeTracker accumulates screen-on seconds
        │  (PauseConditionManager blocks accumulation
        │   if Focus / CarPlay / Driving detected)
        ▼
Threshold reached → ReminderScheduler.scheduleNext()
  – cancels any pending requests
  – adds UNTimeIntervalNotificationRequest for .eyes or .posture
  – repeat: false (ScreenTimeTracker re-arms after each break)
        │
        ▼
UNUserNotificationCenter fires notification
        │
  ┌─────┴─────────────────────────┐
  │ App in foreground?            │ App in background?
  │                               │
  ▼                               ▼
OverlayManager                 System notification
presents overlay                banner / lock screen
immediately                     (user taps → app opens
                                 → UNUserNotificationCenterDelegate
                                    calls OverlayManager)
```

### 4.2 Overlay Window

- A second `UIWindow` is created at `UIWindow.Level.alert + 1`, placed above all other content including the keyboard and system chrome.
- The root view controller hosts `OverlayView` (SwiftUI via `UIHostingController`).
- A **dismiss button** (and swipe-up gesture) allows the user to cancel at any time.
- The window is torn down after dismissal or after the configured *break duration* elapses (whichever comes first), using a simple `DispatchQueue.main.asyncAfter` for the auto-dismiss timer – this is intentionally short-lived and only runs while the app is active.
- The overlay is **not** shown if the device is locked (the notification appears on the lock screen instead; the user will see the overlay once they unlock and open the app).

### 4.3 Settings Persistence

`SettingsStore` wraps `UserDefaults` with typed properties:

| Key | Type | Default |
|---|---|---|
| `eyes.interval` | `TimeInterval` (seconds) | 1200 (20 min) |
| `eyes.breakDuration` | `TimeInterval` | 20 s |
| `posture.interval` | `TimeInterval` | 1800 (30 min) |
| `posture.breakDuration` | `TimeInterval` | 10 s |
| `remindersEnabled` | `Bool` | `true` |

Changes trigger `ReminderScheduler.reschedule()` automatically via a `didSet` observer.

---

## 5. User Interface

### 5.1 Settings Screen (`SettingsView`)

- **Toggle** – enable / disable all reminders.
- **Two expandable rows** (eyes & posture), each containing:
  - *Remind me every* – `Picker` / `Menu` with options: 10 min, 20 min, 30 min, 45 min, 60 min.
  - *Break duration* – `Picker` / `Menu` with options: 10 s, 20 s, 30 s, 60 s.
- Changes are saved immediately to `SettingsStore` and reminders are rescheduled.

### 5.2 Overlay Screen (`OverlayView`)

| Element | Detail |
|---|---|
| Background | Semi-opaque blur (`UIBlurEffect` / `.ultraThinMaterial`) |
| Icon | SF Symbol (e.g., `eye.fill` / `figure.stand`) |
| Title | "Time to rest your eyes" / "Time to check your posture" |
| Countdown | Remaining seconds displayed with a circular progress ring |
| Dismiss button | `×` in top-right corner; also swipe up to dismiss |
| Auto-dismiss | After *break duration* seconds the overlay fades out automatically |

---

## 6. Background Execution & Battery Optimisation

| Technique | Rationale |
|---|---|
| Use `UNUserNotificationCenter` for scheduling | No background CPU usage between reminders |
| Short-lived `DispatchQueue.asyncAfter` for auto-dismiss timer | Only runs when the app is active; negligible cost |
| `UserDefaults` for persistence | Tiny memory footprint vs CoreData |
| No persistent background mode declared | Avoids draining battery; iOS handles scheduling natively |
| Overlay window created on demand, released immediately after dismissal | No retained view hierarchy between reminders |
| No polling or location services | Removes common battery drain sources |

The app will declare **no** background modes in `Info.plist` except `remote-notification` (if push is later desired). All timing is delegated to the OS notification scheduler.

---

## 7. Permissions & Privacy

| Permission | When requested | Purpose |
|---|---|---|
| `UNAuthorizationOptions` (alert, sound, badge) | First launch | Delivering reminder notifications |
| No microphone / camera / location | N/A | Not required |

If the user denies notification permission, the app falls back to foreground-only overlay reminders (timer runs only while the app is on screen) and shows a settings prompt to re-enable.

---

## 8. Notification Content

```
Eyes reminder
  title:  "👁 Eye Break"
  body:   "Look 20 ft away for 20 seconds."
  sound:  UNNotificationSound.default
  categoryIdentifier: "EYE_REMINDER"

Posture reminder
  title:  "🧍 Posture Check"
  body:   "Sit up straight and roll your shoulders."
  sound:  UNNotificationSound.default
  categoryIdentifier: "POSTURE_REMINDER"
```

Notification actions (optional v2 feature): **"Done"** (dismiss) and **"Snooze 5 min"**.

---

## 9. Data Flow

```
User changes interval picker
        │
        ▼
SettingsViewModel.update(type:interval:)
        │
        ▼
SettingsStore.save()  →  UserDefaults
        │
        ▼
AppCoordinator notifies ScreenTimeTracker of new threshold
        │
        ▼
ScreenTimeTracker accumulates screen-on seconds
  (PauseConditionManager blocks accumulation
   if Focus / CarPlay / Driving detected)
        │
        ▼
Threshold reached → AppCoordinator.handleNotification(for:)
        │
        ▼
OverlayManager.showOverlay(...)
        │
        ▼
OverlayView shown with countdown
        │
  ┌─────┴──────────┐
  │ User taps ×    │ Timer elapses
  ▼                ▼
OverlayManager.dismiss()
  UIWindow removed from hierarchy
  ScreenTimeTracker.reset(for: type) — re-arms for next cycle
```

---

## 10. Edge Cases & Considerations

| Scenario | Handling |
|---|---|
| User force-quits the app | Scheduled notifications still fire; overlay shown on next launch |
| User denies notifications | Foreground-only timer fallback; prompt to re-enable in Settings |
| Multiple reminders firing close together | Scheduler checks active overlay; queues second reminder rather than stacking windows |
| Low Power Mode | No change required – `UNUserNotificationCenter` is unaffected |
| Accessibility (VoiceOver) | Overlay `accessibilityViewIsModal = true`; dismiss button has accessible label "Dismiss reminder" |
| iPad support | Same code path; overlay window fills full screen |
| iOS version minimum | iOS 16 for SwiftUI List-based settings and `.ultraThinMaterial`; could lower to iOS 14 with minor changes |
| Dark / Light mode | `OverlayView` uses semantic colours + `.ultraThinMaterial` which adapts automatically |

---

## 11. Testing Strategy

| Layer | Approach |
|---|---|
| `SettingsStore` | Unit tests with an in-memory `UserDefaults` suite |
| `ReminderScheduler` | Unit tests mocking `UNUserNotificationCenter` via a protocol |
| `OverlayManager` | UI tests asserting window level and dismiss behaviour |
| `SettingsViewModel` | Unit tests verifying picker bindings trigger reschedule |
| End-to-end | Manual testing on simulator with shortened intervals (10 s) |

---

## 12. Phased Delivery

| Phase | Scope |
|---|---|
| **Phase 0 – Foundation** ✅ | Project scaffolding (SPM, Xcode), CI/CD pipeline (GitHub Actions), MVVM architecture scaffolding, design system (Asset Catalog, String Catalog, design tokens) |
| **Phase 1 – MVP** ✅ | Settings screen (interval + duration pickers), local notification scheduling, foreground overlay with countdown and dismiss, haptics, accessibility, ~65 unit tests |
| **Phase 2 – Polish** 🔄 | Onboarding flow, snooze action, smart pause (Focus Mode / CarPlay / driving detection), ScreenTimeTracker replacing wall-clock intervals, data-driven config (Asset Catalog + String Catalog + defaults.json), App Store listing & preparation |
| **Phase 3 – Advanced** 🔄 | Dependency injection refactoring, iCloud sync via `NSUbiquitousKeyValueStore`, Home Screen widget (WidgetKit), watchOS companion app |

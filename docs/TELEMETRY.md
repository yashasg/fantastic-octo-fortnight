# kshana — Telemetry Event Schema & Dashboard Requirements

> **Author:** Turk (Data Analyst)
> **Date:** 2026-04-30
> **Status:** Active
> **Informed by:** Rusty's telemetry-battery and testflight-telemetry decisions

---

## Overview

This document defines the complete telemetry strategy for kshana: every log point, every MetricKit subscription, and every dashboard tile we need to ship a healthy, measurable app.

**Guiding principles:**
- **Native Apple only.** No third-party SDKs and no developer-operated analytics backend. Apple-managed diagnostics, App Store Connect analytics, TestFlight feedback, and user-shared log bundles may process limited diagnostic data through Apple's systems.
- **Privacy first.** Aggregate or operational data only. No user identifiers, no device fingerprinting, no PII in logs.
- **Structured from day one.** `os.Logger` active from Phase 1 (M0.2). MetricKit active from Phase 2. Dashboard requirements defined now so we instrument correctly the first time.

---

## Phase 1 — os.Logger Event Catalog

> **Note:** The Phase 1 category-based `Logger` calls below are the original design document and are partially superseded by the structured `AnalyticsLogger` / `AnalyticsEvent` catalog in the **True Interrupt Analytics Event Catalog** section. The `AnalyticsEvent` schema is the canonical source of truth for all events emitted in the current codebase. The Phase 1 tables are retained here for historical context only.

### Logger Setup

```swift
// Logger+App.swift
import OSLog

extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.yashasg.eyeposturereminder"

    static let scheduling = Logger(subsystem: subsystem, category: "Scheduling")
    static let overlay    = Logger(subsystem: subsystem, category: "Overlay")
    static let settings   = Logger(subsystem: subsystem, category: "Settings")
    static let appLife    = Logger(subsystem: subsystem, category: "AppLifecycle")
}
```

**Log levels:**
- `.info` — normal user flow events (scheduled, shown, dismissed)
- `.warning` — recoverable unexpected states (duplicate schedule attempt, permission denied gracefully)
- `.error` — failures requiring attention (scheduling failed, overlay failed to present)

**Format rule:** All log messages use structured key=value pairs for parseability. Dynamic values that are safe to expose use `privacy: .public`. Values that could be personal (e.g., custom text) use `privacy: .private` (redacted in Console.app unless explicitly unredacted).

---

### Category: Scheduling

| Event | Level | Log Call | Notes |
|-------|-------|----------|-------|
| Reminder scheduled | `.info` | `Logger.scheduling.info("reminder_scheduled type=\(type.rawValue, privacy: .public) interval_sec=\(interval, privacy: .public)")` | Fire when `UNNotificationRequest` is successfully added |
| Reminder rescheduled | `.info` | `Logger.scheduling.info("reminder_rescheduled type=\(type.rawValue, privacy: .public) old_interval_sec=\(oldInterval, privacy: .public) new_interval_sec=\(newInterval, privacy: .public)")` | Fire when settings change causes reschedule |
| Reminder cancelled | `.info` | `Logger.scheduling.info("reminder_cancelled type=\(type.rawValue, privacy: .public) reason=\(reason, privacy: .public)")` | `reason`: `user_disabled`, `permission_revoked`, `app_terminating` |
| Schedule request failed | `.error` | `Logger.scheduling.error("reminder_schedule_failed type=\(type.rawValue, privacy: .public) error=\(error.localizedDescription, privacy: .public)")` | UNError domain errors |
| Snooze activated | `.info` | `Logger.scheduling.info("snooze_activated type=\(type.rawValue, privacy: .public) duration_sec=\(duration, privacy: .public)")` | Fire when user taps snooze on overlay |
| Snooze expired | `.info` | `Logger.scheduling.info("snooze_expired type=\(type.rawValue, privacy: .public) scheduled_duration_sec=\(duration, privacy: .public)")` | Fire when snooze notification fires |
| Notification authorization requested | `.info` | `Logger.scheduling.info("notification_auth_requested")` | Fire before calling `requestAuthorization` |
| Notification authorization result | `.info` / `.warning` | `Logger.scheduling.info("notification_auth_result granted=\(granted, privacy: .public)")` | Warning if denied |
| Pending notifications fetched | `.info` | `Logger.scheduling.info("pending_notifications_count count=\(count, privacy: .public)")` | Useful for diagnosing duplicate-schedule issues |

---

### Category: Overlay

| Event | Level | Log Call | Notes |
|-------|-------|----------|-------|
| Overlay shown | `.info` | `Logger.overlay.info("overlay_shown type=\(type.rawValue, privacy: .public) trigger=\(trigger, privacy: .public)")` | `trigger`: `notification_tap`, `foreground_notification`, `manual_debug` |
| Overlay dismissed (manual) | `.info` | `Logger.overlay.info("overlay_dismissed type=\(type.rawValue, privacy: .public) source=manual display_duration_sec=\(duration, privacy: .public)")` | User tapped dismiss |
| Overlay dismissed (auto) | `.info` | `Logger.overlay.info("overlay_dismissed type=\(type.rawValue, privacy: .public) source=auto display_duration_sec=\(duration, privacy: .public)")` | Timer elapsed |
| Overlay dismissed (swipe) | `.info` | `Logger.overlay.info("overlay_dismissed type=\(type.rawValue, privacy: .public) source=swipe display_duration_sec=\(duration, privacy: .public)")` | Swipe gesture |
| Overlay queued | `.warning` | `Logger.overlay.warning("overlay_queued type=\(type.rawValue, privacy: .public) reason=already_visible")` | Second reminder fired while overlay was active |
| Settings button tapped | `.info` | `Logger.overlay.info("overlay_settings_tapped type=\(type.rawValue, privacy: .public)")` | User tapped settings from overlay |
| Overlay window creation failed | `.error` | `Logger.overlay.error("overlay_window_create_failed type=\(type.rawValue, privacy: .public) error=\(error, privacy: .public)")` | Guard against nil window scene |
| Overlay deallocated | `.info` (debug only) | `Logger.overlay.debug("overlay_window_deallocated type=\(type.rawValue, privacy: .public)")` | Confirm no memory leak; debug level = compiled out in release |

---

### Category: Settings

| Event | Level | Log Call | Notes |
|-------|-------|----------|-------|
| Setting changed | `.info` | `Logger.settings.info("setting_changed key=\(key, privacy: .public) old=\(String(describing: oldValue), privacy: .public) new=\(String(describing: newValue), privacy: .public)")` | Fire for every UserDefaults write via SettingsStore |
| Reminder type toggled | `.info` | `Logger.settings.info("reminder_toggled type=\(type.rawValue, privacy: .public) enabled=\(enabled, privacy: .public)")` | Specific helper for eye/posture enable/disable |
| Interval changed | `.info` | `Logger.settings.info("interval_changed type=\(type.rawValue, privacy: .public) old_sec=\(oldInterval, privacy: .public) new_sec=\(newInterval, privacy: .public)")` | Interval in seconds |
| Overlay duration changed | `.info` | `Logger.settings.info("duration_changed old_sec=\(oldDuration, privacy: .public) new_sec=\(newDuration, privacy: .public)")` | Overlay auto-dismiss duration |
| Snooze duration selected | `.info` | `Logger.settings.info("snooze_duration_selected duration_sec=\(duration, privacy: .public)")` | From picker or preset |
| Permission granted | `.info` | `Logger.settings.info("permission_granted type=\(permType, privacy: .public)")` | `permType`: `notifications` |
| Permission denied | `.warning` | `Logger.settings.warning("permission_denied type=\(permType, privacy: .public)")` | Record for funnel analysis |
| Permission status checked | `.info` | `Logger.settings.info("permission_status_checked type=\(permType, privacy: .public) status=\(status, privacy: .public)")` | On every app foreground |
| Settings loaded from disk | `.info` | `Logger.settings.info("settings_loaded interval_eye=\(eyeInterval, privacy: .public) interval_posture=\(postureInterval, privacy: .public) overlay_duration=\(overlayDuration, privacy: .public)")` | On app launch |

---

### Category: AppLifecycle

| Event | Level | Log Call | Notes |
|-------|-------|----------|-------|
| App launched (cold) | `.info` | `Logger.appLife.info("app_launch type=cold build=\(build, privacy: .public) os=\(os, privacy: .public)")` | `applicationDidFinishLaunching` |
| App launched (warm) | `.info` | `Logger.appLife.info("app_launch type=warm")` | `applicationWillEnterForeground` |
| App backgrounded | `.info` | `Logger.appLife.info("app_background")` | `applicationDidEnterBackground` |
| App foregrounded | `.info` | `Logger.appLife.info("app_foreground")` | `applicationWillEnterForeground` |
| App terminating | `.info` | `Logger.appLife.info("app_terminate")` | `applicationWillTerminate` |
| Notification received (foreground) | `.info` | `Logger.appLife.info("notification_received delivery=foreground type=\(type.rawValue, privacy: .public)")` | `willPresent` delegate |
| Notification received (background) | `.info` | `Logger.appLife.info("notification_received delivery=background type=\(type.rawValue, privacy: .public)")` | `didReceive response` delegate |
| Notification dismissed without tap | `.info` | `Logger.appLife.info("notification_dismissed type=\(type.rawValue, privacy: .public)")` | `.dismiss` action in `didReceive` |
| Onboarding completed | `.info` | `AnalyticsLogger.log(.onboardingCompleted(cta:))` | Fired when user exits onboarding via "Get Started" or "Customize Settings" CTA |

---

## True Interrupt Analytics Event Catalog

> **Updated:** 2026-04-30 — reflects issues #247/#249/#253/#254/#257/#269/#278/#282/#286/#290/#291/#297/#316/#332/#346.
>
> All events are emitted via `AnalyticsLogger.log(_:)` → `os.Logger` (subsystem: `Bundle.main.bundleIdentifier`, category: `Analytics`). No SDK, no network calls. All payload fields use `privacy: .public` unless noted.

---

### Category: Session

#### `app_session_start`

| Field | Log key | Privacy | Notes |
|-------|---------|---------|-------|
| `eyeEnabled` | `eye_enabled` | `.public` | Whether eye break reminders are on |
| `postureEnabled` | `posture_enabled` | `.public` | Whether posture break reminders are on |
| `snoozeActive` | `snooze_active` | `.public` | Whether snooze is currently active |

**Emitted:** when `scheduleReminders()` is called (session start).

#### `app_session_end`

| Field | Log key | Privacy | Notes |
|-------|---------|---------|-------|
| `sessionDurationS` | `session_duration_s` | `.public` | Session length in seconds (1 decimal place) |

**Emitted:** when the app resigns active.

---

### Category: Reminders

#### `reminder_triggered`

Fired when a reminder is triggered. `deliveryPath` indicates whether the reminder was surfaced via the screen-time threshold (True Interrupt path) or the notification fallback.

| Field | Log key | Privacy | Stable raw values |
|-------|---------|---------|-------------------|
| `type` | `type` | `.public` | `eyes`, `posture` (from `ReminderType`) |
| `thresholdS` | `threshold_s` | `.public` | Threshold in seconds (0 decimal places) |
| `deliveryPath` | `delivery_path` | `.public` | See `ReminderDeliveryPath` table |

**`ReminderDeliveryPath` stable raw values:**

| Case | Raw value | Meaning |
|------|-----------|---------|
| `screenTimeThreshold` | `screen_time_threshold` | Reminder surfaced by the foreground Screen Time threshold (True Interrupt path) |
| `notificationFallback` | `notification_fallback` | Reminder surfaced by the notification fallback path |
| `unknown` | `unknown` | Path could not be determined at trigger time |

---

### Category: Schedule Path Selection

#### `schedule_path_selected`

Fired when `scheduleReminders()` selects a delivery path. Emitted after IPC recording — provides the same routing decision in the analytics stream.

| Field | Log key | Privacy | Stable raw values |
|-------|---------|---------|-------------------|
| `path` | `path` | `.public` | See `SchedulePath` table |
| `reason` | `reason` | `.public` | See `SchedulePathReason` table |

**`SchedulePath` stable raw values:**

| Case | Raw value | Meaning |
|------|-----------|---------|
| `shield` | `shield` | True Interrupt path — DeviceActivity shield selected |
| `notificationFallback` | `notification_fallback` | Notification fallback path selected |

**`SchedulePathReason` stable raw values:**

| Case | Raw value | Meaning |
|------|-----------|---------|
| `deviceActivityAvailable` | `device_activity_available` | Screen Time / DeviceActivity is available; shield path chosen |
| `shieldUnavailable` | `shield_unavailable` | Shield is unavailable; fallback chosen |
| `trueInterruptDisabled` | `true_interrupt_disabled` | True Interrupt feature is disabled; fallback chosen |
| `trueInterruptEmptySelection` | `true_interrupt_empty_selection` | No app selection configured; fallback chosen |
| `unexpectedShieldRoutingState` | `unexpected_shield_routing_state` | Defensive path: shield routing state became available between the `shouldScheduleNotificationFallback` check and `fallbackRoutingContext()` |

---

### Category: Shield Lifecycle

#### `shield_activated`

Fired when a DeviceActivity shield session starts successfully.

| Field | Log key | Privacy | Stable raw values |
|-------|---------|---------|-------------------|
| `reason` | `reason` | `.public` | See `ShieldTriggerReason` table |

#### `shield_activation_failed`

Fired when a DeviceActivity shield activation attempt fails. Logged at `.error` level.

| Field | Log key | Privacy | Stable raw values |
|-------|---------|---------|-------------------|
| `reason` | `reason` | `.public` | See `ShieldTriggerReason` table |

#### `shield_deactivated`

Fired when a DeviceActivity shield session is cancelled/deactivated. No payload fields.

**`ShieldTriggerReason` stable raw values** (defined in `Extensions/Shared/ShieldTriggerReason.swift`):

| Case | Raw value | Meaning |
|------|-----------|---------|
| `scheduledEyesBreak` | `eyes` | Scheduled eye-strain break (20-20-20 rule or configured interval) |
| `scheduledPostureBreak` | `posture` | Scheduled posture/movement break |

---

### Category: Overlay

#### `overlay_dismissed`

| Field | Log key | Privacy | Stable raw values |
|-------|---------|---------|-------------------|
| `type` | `type` | `.public` | `eyes`, `posture` |
| `method` | `method` | `.public` | See `DismissMethod` table |
| `elapsedS` | `elapsed_s` | `.public` | Time from display to dismissal in seconds (1 decimal place) |

**`DismissMethod` stable raw values:**

| Case | Raw value | Meaning |
|------|-----------|---------|
| `button` | `button` | User tapped the dismiss button |
| `swipe` | `swipe` | User used a swipe gesture |
| `settingsTap` | `settings_tap` | User tapped the settings shortcut |

#### `overlay_auto_dismissed`

| Field | Log key | Privacy | Notes |
|-------|---------|---------|-------|
| `type` | `type` | `.public` | `eyes` or `posture` |
| `durationS` | `duration_s` | `.public` | Configured display duration in seconds (0 decimal places) |

---

### Category: Snooze

#### `snooze_activated`

| Field | Log key | Privacy | Stable codes |
|-------|---------|---------|--------------|
| `durationOption` | `duration_option` | `.public` | See snooze duration code table |

**Stable snooze duration codes** (from `SettingsViewModel.SnoozeOption.analyticsCode`):

| Preset | Analytics code | Duration |
|--------|---------------|---------|
| `fiveMinutes` | `5m` | 5 minutes |
| `oneHour` | `1h` | 1 hour |
| `restOfDay` | `rest_of_day` | Until midnight / end of day |
| Custom (legacy) | `<N>m` e.g. `30m` | Minute-count string for non-preset values |

#### `snooze_expired`

No payload. Fired when a snooze period expires and normal scheduling resumes.

#### `snooze_cancelled`

No payload. Fired when the user manually cancels an active snooze.

---

### Category: Settings

#### `setting_changed`

| Field | Log key | Privacy | Notes |
|-------|---------|---------|-------|
| `setting` | `setting` | `.public` | Key name of the changed setting (see table below) |
| `oldValue` | `old_value` | `.private` | Previous value — **redacted** in Console unless explicitly unredacted |
| `newValue` | `new_value` | `.private` | New value — **redacted** in Console unless explicitly unredacted |

**Privacy decision:** `old_value` and `new_value` are deliberately `privacy: .private` (redacted) because they may reflect user schedule preferences, which are operationally sensitive even if not PII. Unredacting requires explicit device trust or TestFlight log export. This decision is intentional and should not be changed without a privacy review.

**Instrumented `setting` key values:**

| `setting` value | Type | Emitted from |
|----------------|------|--------------|
| `globalEnabled` | Bool | `SettingsViewModel.globalEnabled` setter (routed via `SettingsView` master toggle `onChange`) |
| `eyesEnabled` | Bool | `SettingsViewModel.eyesEnabled` setter (routed via `SettingsView` `.onChange(of: settings.eyesEnabled)`) |
| `eyesInterval` | TimeInterval | `SettingsViewModel.eyesInterval` setter |
| `eyesBreakDuration` | TimeInterval | `SettingsViewModel.eyesBreakDuration` setter |
| `postureEnabled` | Bool | `SettingsViewModel.postureEnabled` setter |
| `postureInterval` | TimeInterval | `SettingsViewModel.postureInterval` setter |
| `postureBreakDuration` | TimeInterval | `SettingsViewModel.postureBreakDuration` setter |
| `pauseDuringFocus` | Bool | `SettingsViewModel.pauseDuringFocus` setter (routed via `SettingsSmartPauseSection` toggle `onChange`) |
| `pauseWhileDriving` | Bool | `SettingsViewModel.pauseWhileDriving` setter |
| `notificationFallbackEnabled` | Bool | `SettingsViewModel.notificationFallbackEnabled` setter (also triggers reschedule) |
| `hapticsEnabled` | Bool | `SettingsViewModel.hapticsEnabled` setter (custom Binding in `SettingsView` Preferences section) |

---

### Category: Pause

#### `pause_activated`

| Field | Log key | Privacy | Notes |
|-------|---------|---------|-------|
| `conditionType` | `condition_type` | `.public` | Comma-separated sorted list of active pause condition raw values |

**`PauseConditionSource` stable raw values:**

| Case | Raw value | Meaning |
|------|-----------|---------|
| `focusMode` | `focus_mode` | iOS Focus mode is active and `pauseDuringFocus` is enabled |
| `carPlay` | `car_play` | CarPlay connection detected and `pauseWhileDriving` is enabled |
| `driving` | `driving` | CMMotionActivity automotive/high-confidence detected and `pauseWhileDriving` is enabled |

When multiple conditions are active simultaneously, `condition_type` contains a sorted comma-separated list (e.g. `car_play,driving`). `pause_deactivated` always logs `condition_type=all_cleared`.

#### `pause_deactivated`

| Field | Log key | Privacy | Notes |
|-------|---------|---------|-------|
| `conditionType` | `condition_type` | `.public` | Always `all_cleared` — fires when the last active pause condition clears |

---

### Category: Watchdog Recovery

#### `watchdog_recovery_triggered`

Fired when a stale watchdog session is detected and recovery is initiated.

| Field | Log key | Privacy | Notes |
|-------|---------|---------|-------|
| `reason` | `reason` | `.public` | `ShieldTriggerReason.rawValue` or `"unknown"` if nil (no recognisable reason in the stale session) |
| `detail` | `detail` | `.public` | Heartbeat staleness category string (non-PII operational code) |

#### `watchdog_recovery_completed`

Fired at the end of a watchdog recovery attempt.

| Field | Log key | Privacy | Notes |
|-------|---------|---------|-------|
| `sessionCleared` | `session_cleared` | `.public` | `true` if the stale shield session was successfully cleared |
| `fallbackScheduled` | `fallback_scheduled` | `.public` | `true` if a fallback notification was rescheduled after recovery |

---

### Category: IPC Health

#### `ipc_operation_failed`

Fired when an App Group IPC read or write operation fails. Logged at `.error` level. Both fields are enumerated codes — no PII, no bundle identifiers, no raw errors.

| Field | Log key | Privacy | Stable raw values |
|-------|---------|---------|-------------------|
| `operation` | `operation` | `.public` | See `IPCOperation` table |
| `reason` | `reason` | `.public` | See `IPCFailureReason` table |

**`IPCOperation` stable raw values:**

| Case | Raw value | Meaning |
|------|-----------|---------|
| `readShieldSession` | `read_shield_session` | Reading the active shield session from App Group |
| `readEvents` | `read_events` | Reading IPC event history from App Group |
| `clearShieldSession` | `clear_shield_session` | Clearing the shield session record in App Group |
| `writeEvent` | `write_event` | Writing an IPC event to App Group |
| `writeShieldSession` | `write_shield_session` | Writing a shield session record to App Group |
| `readSelection` | `read_selection` | Reading the app selection from App Group |

**`IPCFailureReason` stable raw values:**

| Case | Raw value | Meaning |
|------|-----------|---------|
| `unavailable` | `unavailable` | App Group container or UserDefaults was unavailable |
| `corrupt` | `corrupt` | Stored data failed to decode (corrupt or schema mismatch) |
| `writeFailed` | `write_failed` | Write operation returned a failure |
| `unknown` | `unknown` | Unclassified failure |

---

### Event: `onboarding_completed`

Fired when the user finishes onboarding. The `cta` parameter records which exit button was tapped.

**Format:** `event=onboarding_completed cta=<OnboardingCTA>`

**Associated type:** `AnalyticsEvent.OnboardingCTA`

| Case | Raw Value | Description |
|------|-----------|-------------|
| `.getStarted` | `get_started` | User tapped "Get Started" — proceeds with defaults |
| `.customize` | `customize` | User tapped "Customize Settings" — opens Settings on first launch |

**Privacy:** `cta` uses `privacy: .public` — enumerated code, no PII.

**Emission points:**
- `OnboardingView.finishOnboarding()` → `.onboardingCompleted(cta: .getStarted)`
- `OnboardingView.finishOnboardingAndCustomize()` → `.onboardingCompleted(cta: .customize)`

---

## Phase 2 — MetricKit Event List

### Why Phase 2

MetricKit delivers payloads ~every 24h from devices running the app. Zero payload value until testers generate data, but the subscriber must be registered before the first payload arrives — there's no retroactive collection. Add in Phase 2 alongside the first TestFlight distribution.

### Subscription Setup

```swift
// AppDelegate.swift
import MetricKit
import OSLog

extension AppDelegate: MXMetricManagerSubscriber {

    func setupMetricKit() {
        MXMetricManager.shared.add(self)
        Logger.appLife.info("metrickit_subscriber_registered")
    }

    // Performance payloads — delivered every ~24h
    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            guard let json = String(data: payload.jsonRepresentation(), encoding: .utf8) else { return }
            Logger.appLife.info("metrickit_payload received=\(payload.timeStampBegin, privacy: .public) json=\(json, privacy: .public)")
            // Do not forward to a backend without a privacy-label review.
        }
    }

    // Diagnostic payloads — delivered on next launch after crash/hang
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            guard let json = String(data: payload.jsonRepresentation(), encoding: .utf8) else { return }
            Logger.appLife.error("metrickit_diagnostic received=\(payload.timeStampBegin, privacy: .public) json=\(json, privacy: .public)")
        }
    }
}
```

### MetricKit Payload Types

| Type | Class | What It Measures | Relevance |
|------|-------|-----------------|-----------|
| Crash diagnostic | `MXCrashDiagnostic` | Full crash call stack with thread info | **Critical** — symbolicated crash details beyond what Organizer shows |
| Hang diagnostic | `MXHangDiagnostic` | Main thread call stack during hang (>250ms) | **High** — overlay presentation must not hang |
| App exit metrics | `MXAppExitMetric` | Normal exits, jetsam kills, crashes, watchdog kills | **High** — jetsam kills signal memory pressure |
| Battery metric | `MXBatteryMetric` | Drain rate during active and background use | **High** — health app with battery drain = 1-star reviews |
| CPU metric | `MXCPUMetric` | CPU time (foreground / background / cumulative) | **Medium** — validate near-zero background CPU |
| Memory metric | `MXMemoryMetric` | Peak memory footprint | **Medium** — overlay window alloc/dealloc validation |
| Launch metric | `MXAppLaunchMetric` | Cold and warm launch histograms | **Medium** — first impression |
| Disk I/O metric | `MXDiskIOMetric` | Logical writes | **Low** — we only write UserDefaults |

### Key Fields to Track Per Payload

**`MXCrashDiagnostic`**
- `callStackTree` — symbolicated crash stack
- `exceptionType` / `exceptionCode` — crash classification
- `terminationReason` — OS-level reason string
- `virtualMemoryRegionInfo` — useful for memory access crashes

**`MXHangDiagnostic`**
- `callStackTree` — what the main thread was doing during hang
- `hangDuration` — how long the hang lasted

**`MXAppExitMetric`**
- `foregroundExitData.cumulativeBadAccessExitCount` — signal 11 (SIGSEGV)
- `foregroundExitData.cumulativeAbnormalExitCount` — signal 6 (SIGABRT)
- `backgroundExitData.cumulativeMemoryResourceLimitExitCount` — jetsam kills
- `backgroundExitData.cumulativeNormalAppExitCount` — clean exits

**`MXBatteryMetric`**
- `cumulativeFingerprints` — baseline comparison
- Look for `drain` values during active overlay display windows

**Storage:** For Phase 2, MetricKit summaries are written to `os.log` only. If aggregate diagnostic history is needed later, keep it local and bounded (for example, last 7 payload summaries in `UserDefaults` or a simple file in the app's Library directory). Do not add external transmission without updating the privacy policy, Privacy Nutrition Labels guide, and App Store/TestFlight copy first.

---

## Dashboard Requirements

What Turk, Tess (UX), and Reuben (Product) need to see. These drive the instrumentation decisions above.

### Tier 1 — TestFlight Health (App Store Connect)

**Source:** App Store Connect → TestFlight section (free, zero-code)

| Metric | What It Tells Us | Action Threshold |
|--------|-----------------|-----------------|
| Crash rate per build | Regression detection | Any increase vs. prior build |
| Top crash signatures | What's breaking | Address before next TestFlight |
| Session count per tester | Are testers actually using it? | <2 sessions/tester/week = inactive |
| Device + OS distribution | Coverage gaps | If >20% on unsupported OS, investigate |
| Battery impact percentile (Xcode Organizer) | Energy regression | Yellow = investigate; Red = ship fix |

**Responsible:** Rusty watches this post-build. Turk tracks trends across builds.

---

### Tier 2 — Usage Patterns (os.log derived)

**Source:** Console.app analysis on tester devices, or TestFlight feedback log bundles

| Metric | Derived From | Formula |
|--------|-------------|---------|
| Average dismissal time | `overlay_dismissed elapsed_s` | Mean of `elapsed_s` across all dismiss events |
| Auto-dismiss rate | `event=overlay_auto_dismissed` vs total dismissals | `auto_count / (auto_count + dismissed_count)` |
| Manual dismiss rate | `event=overlay_dismissed method=button` | `button_count / total_dismiss_count` |
| Swipe dismiss rate | `event=overlay_dismissed method=swipe` | `swipe_count / total_dismiss_count` |
| Settings-tap-from-overlay rate | `event=overlay_dismissed method=settings_tap` | `settings_tap_count / total_dismiss_count` |
| Snooze frequency by duration | `event=snooze_activated duration_option` | Count grouped by `duration_option` value (`5m`, `1h`, `rest_of_day`) |
| Delivery path split | `event=reminder_triggered delivery_path` | `screen_time_threshold` vs `notification_fallback` ratio |

**Tess needs:** Swipe dismiss rate and method breakdown — if swipe >> button, the dismiss button is hard to find or reach.

**Reuben needs:** Snooze frequency by duration — validates the snooze preset options. Delivery path split — confirms True Interrupt path adoption rate.

---

### Tier 3 — True Interrupt Health (os.log derived)

**Source:** Console.app / TestFlight log bundles — filter `category:Analytics event=schedule_path_selected`, `event=shield_*`, `event=watchdog_*`, `event=ipc_operation_failed`

| Metric | Derived From | What It Tells Us |
|--------|-------------|-----------------|
| Schedule path selection rate | `event=schedule_path_selected path` | Ratio of `shield` vs `notification_fallback` paths chosen |
| Shield path reason distribution | `event=schedule_path_selected reason` | Why shield is or isn't selected (DeviceActivity availability, feature flags, empty selection) |
| Shield success rate | `event=shield_activated` / (`event=shield_activated` + `event=shield_activation_failed`) | How reliably shields activate when chosen |
| Shield failure reason | `event=shield_activation_failed reason` | Which shield trigger reasons fail most |
| Watchdog recovery rate | `event=watchdog_recovery_triggered` per session | Frequency of stale-session recovery needed |
| Watchdog recovery success | `event=watchdog_recovery_completed session_cleared=true` / total recovery events | Whether recovery clears stale sessions |
| Fallback after recovery | `event=watchdog_recovery_completed fallback_scheduled=true` | Whether fallback notification rescheduling succeeds after recovery |
| IPC failure rate | `event=ipc_operation_failed` per session | App Group IPC health; distinguish by `operation` and `reason` |
| Notification fallback attribution | `event=reminder_triggered delivery_path=notification_fallback` | Reminder count surfaced by fallback rather than True Interrupt |
| Unexpected shield routing | `event=schedule_path_selected reason=unexpected_shield_routing_state` | Frequency of defensive race-condition path — should be near zero |

**Turk monitors:** Shield success rate and IPC failure rate as primary True Interrupt health KPIs.

---

### Tier 4 — Settings Patterns (os.log derived)

| Metric | Derived From | What It Tells Us |
|--------|-------------|-----------------|
| Most common eye interval | `event=setting_changed setting=eyesInterval new_value` (requires log unredaction) | Is 20 min the right default? |
| Most common posture interval | `event=setting_changed setting=postureInterval new_value` (requires log unredaction) | Is 30 min the right default? |
| Per-type enable/disable rate | `event=setting_changed setting=eyesEnabled\|postureEnabled` (requires unredaction) | Which reminder type do people disable? |
| Global toggle rate | `event=setting_changed setting=globalEnabled` (requires unredaction) | How often do users disable all reminders? |
| Break duration preferences | `event=setting_changed setting=eyesBreakDuration\|postureBreakDuration` (requires unredaction) | Are the default break durations appropriate? |

---

### Tier 5 — UX Health Signals (os.log derived)

| Signal | Derived From | Healthy | Investigate If |
|--------|-------------|---------|---------------|
| Permission grant rate | `permission_granted` / (`permission_granted` + `permission_denied`) | >85% | <70% — onboarding copy unclear |
| Permission revoke rate | `permission_denied type=notifications` after prior grant | <5% | >10% — overlay is too intrusive |
| Force-quit / jetsam rate | `MXAppExitMetric backgroundExitData` | <2% of exits | >5% — memory issue |
| Cold launch after terminate | `app_session_start` following `app_session_end` vs. no end event | Baseline | Spikes = crash loop |
| Settings-from-overlay funnel | `overlay_dismissed method=settings_tap` → `setting_changed` | >50% | <30% — settings navigation broken |
| IPC write failure rate | `event=ipc_operation_failed operation=write_event\|write_shield_session` | <1% | >5% — App Group degraded |

---

## Privacy Checklist

### No PII in Logs

- [ ] **No usernames, emails, or account identifiers** — app has no accounts
- [ ] **No device identifiers** — never log `UIDevice.current.identifierForVendor`
- [ ] **No timestamps that could identify a user's schedule** — log relative durations (`elapsed_s`, `session_duration_s`), not wall-clock times of user actions
- [ ] **All user-facing string values use `privacy: .private`** — `setting_changed old_value` and `new_value` are redacted; all other AnalyticsEvent fields are enumerated codes or numeric durations
- [ ] **All structural values (type names, raw-value codes, durations, counts) use `privacy: .public`** — these are enum raw values and integers, not personal data
- [ ] **IPC health events contain no bundle identifiers or raw error descriptions** — `ipc_operation_failed` uses only enumerated `IPCOperation` and `IPCFailureReason` codes
- [ ] **Watchdog recovery events contain no raw session data** — `watchdog_recovery_triggered` logs only the `ShieldTriggerReason` raw value or `"unknown"`, and a staleness category code
- [ ] **Shield lifecycle events contain no app selection data** — `shield_activated`/`shield_activation_failed` log only the `ShieldTriggerReason` raw value (`eyes` or `posture`)
- [ ] **Log calls in release builds** — `os.log` is safe in release; debug-only calls use `.debug` level which is compiled to near-zero overhead

### No Device Identifiers

- [ ] Never log `identifierForVendor` (IDFV)
- [ ] Never log `advertisingIdentifier` (IDFA) — we have no AdServices entitlement
- [ ] MetricKit payloads carry no app-defined user or device identifier — they are aggregate/diagnostic and processed through Apple's systems
- [ ] App Store Connect Analytics is aggregate-only; individual tester data is not accessible programmatically

### App Privacy Report Compliance

- [ ] **No tracking domains** — no third-party network calls
- [ ] **No entitlement requests beyond notifications** — no location, contacts, photos, health data
- [ ] App Privacy Report (Settings → Privacy → App Privacy Report) will show zero network destinations for our app
- [ ] No use of `ATTrackingManager` — no App Tracking Transparency prompt needed

### App Store Privacy Nutrition Label

For the App Store submission, declare:

| Category | Data Type | Collected? | Linked to Identity? | Used for Tracking? |
|----------|-----------|-----------|--------------------|--------------------|
| Diagnostics | Crash data | Yes (via MetricKit/App Store Connect, Apple-managed) | No | No |
| Diagnostics | Performance data | Yes (via MetricKit, Apple-managed) | No | No |
| App Usage | Other usage data | No (local os.log and App Group IPC history stay on device unless included in user-shared Apple/TestFlight diagnostics) | N/A | N/A |
| Contact Info | Any | No | N/A | N/A |
| Identifiers | Any | No | N/A | N/A |

**Correct declaration:** "Not Collected" for user-linked categories and local-only usage/IPC state. Disclose Apple-managed crash and performance diagnostics as described in `docs/PRIVACY_NUTRITION_LABELS.md`. If kshana ever transmits MetricKit payloads, Screen Time data, or local IPC history to a developer-operated service, reassess the labels before submission.

---

## Implementation Checklist

### Phase 1 (M0.2 — Pre-TestFlight)

- [ ] Add `Logger+App.swift` with subsystem extension (Scheduling, Overlay, Settings, AppLifecycle)
- [ ] Instrument all Scheduling events per catalog above
- [ ] Instrument all Overlay events per catalog above
- [ ] Instrument all Settings events per catalog above
- [ ] Instrument all AppLifecycle events per catalog above
- [ ] Verify in Console.app: filter by subsystem `com.yashasg.eyeposturereminder`
- [ ] Confirm no PII appears in any log line

### Phase 2 (First TestFlight Distribution)

- [ ] Add `MXMetricManagerSubscriber` to AppDelegate
- [ ] Call `MXMetricManager.shared.add(self)` in `applicationDidFinishLaunching`
- [ ] Implement `didReceive(_ payloads: [MXMetricPayload])` — log to `Logger.appLife`
- [ ] Implement `didReceive(_ payloads: [MXDiagnosticPayload])` — log to `Logger.appLife` at `.error`
- [ ] Verify CI/CD pipeline sets `ENABLE_BITCODE = NO`
- [ ] Verify dSYMs are uploaded to App Store Connect (required for symbolicated crashes)
- [ ] Brief TestFlight testers: enable "Share App Data" in TestFlight settings
- [ ] Brief testers: shake gesture triggers feedback with attached logs

### Post-TestFlight (Dashboard Activation)

- [ ] Turk reviews App Store Connect TestFlight crash rate after first beta build
- [ ] Tess reviews dismissal mode distribution after first 2 weeks of beta
- [ ] Reuben reviews settings pattern data (interval combos, snooze duration preferences)
- [ ] Team reviews permission grant rate — target >85%

---

## Appendix: Log Parsing Reference

### Console.app Filters

```
subsystem:com.yashasgujjar.kshana category:Analytics
subsystem:com.yashasgujjar.kshana category:Analytics event=schedule_path_selected
subsystem:com.yashasgujjar.kshana category:Analytics event=shield_activated
subsystem:com.yashasgujjar.kshana category:Analytics event=shield_activation_failed
subsystem:com.yashasgujjar.kshana category:Analytics event=watchdog_recovery_triggered
subsystem:com.yashasgujjar.kshana category:Analytics event=watchdog_recovery_completed
subsystem:com.yashasgujjar.kshana category:Analytics event=ipc_operation_failed
subsystem:com.yashasgujjar.kshana category:Analytics event=reminder_triggered
subsystem:com.yashasgujjar.kshana category:Analytics event=snooze_activated
```

### Key-Value Parsing

All log messages follow the pattern: `event_name key1=value1 key2=value2`

Example grep for dismissal duration analysis from a device log export:
```bash
# From exported .logarchive or Console.app text export:
grep "overlay_dismissed" device.log | grep -oP 'display_duration_sec=\K[0-9.]+'
```

### MetricKit JSON Schema (representative excerpt)

```json
{
  "timeStampBegin": "2025-07-24 00:00:00 +0000",
  "timeStampEnd": "2025-07-25 00:00:00 +0000",
  "appExitMetrics": {
    "foregroundExitData": {
      "cumulativeBadAccessExitCount": 0,
      "cumulativeAbnormalExitCount": 0,
      "cumulativeMemoryResourceLimitExitCount": 0
    },
    "backgroundExitData": {
      "cumulativeNormalAppExitCount": 12,
      "cumulativeMemoryResourceLimitExitCount": 0
    }
  },
  "batteryMetrics": {
    "cumulativeDrain": { "value": 0.8, "unit": "%" }
  }
}
```

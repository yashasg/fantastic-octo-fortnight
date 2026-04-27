# kshana — Telemetry Event Schema & Dashboard Requirements

> **Author:** Turk (Data Analyst)
> **Date:** 2025-07-25
> **Status:** Active
> **Informed by:** Rusty's telemetry-battery and testflight-telemetry decisions

---

## Overview

This document defines the complete telemetry strategy for kshana: every log point, every MetricKit subscription, and every dashboard tile we need to ship a healthy, measurable app.

**Guiding principles:**
- **Native Apple only.** No third-party SDKs. No data leaves the device except through Apple's own channels (os.log → App Store Connect / TestFlight feedback).
- **Privacy first.** Aggregate data only. No user identifiers, no device fingerprinting, no PII in logs.
- **Structured from day one.** `os.Logger` active from Phase 1 (M0.2). MetricKit active from Phase 2. Dashboard requirements defined now so we instrument correctly the first time.

---

## Phase 1 — os.Logger Event Catalog

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
            // Phase 3: forward to lightweight backend if needed
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

**Storage:** For Phase 2, payload JSON is written to `os.log` only. For Phase 3, if aggregate data is needed, write payload JSON to a bounded `UserDefaults` key (last 7 payloads) or a simple file in the app's Documents/Library directory. No external servers required.

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
| Average dismissal time | `overlay_dismissed display_duration_sec` | Mean of `display_duration_sec` across all dismiss events |
| Auto-dismiss rate | `overlay_dismissed source=auto` vs total dismiss | `auto_count / total_dismiss_count` |
| Manual dismiss rate | `overlay_dismissed source=manual` | `manual_count / total_dismiss_count` |
| Swipe dismiss rate | `overlay_dismissed source=swipe` | `swipe_count / total_dismiss_count` |
| Snooze frequency by duration | `snooze_activated duration_sec` | Count grouped by `duration_sec` value |
| Overlay queue rate | `overlay_queued` per session | Ratio of queue events to overlay shown events |
| Notification tap rate | `overlay_shown trigger=notification_tap` vs `notification_received` | Engagement with notification banner |

**Tess needs:** Swipe dismiss rate and manual dismiss rate — if swipe >> manual, that suggests the close button is hard to find or reach.

**Reuben needs:** Snooze frequency by duration — validates the snooze preset options and helps refine the default.

---

### Tier 3 — Settings Patterns (os.log derived)

| Metric | Derived From | What It Tells Us |
|--------|-------------|-----------------|
| Most common eye interval | `interval_changed new_sec` distribution | Is 20 min the right default? |
| Most common posture interval | `interval_changed new_sec` distribution | Is 30 min the right default? |
| Most common overlay duration | `duration_changed new_sec` distribution | Is 10s enough? Are users extending it? |
| Per-type enable/disable rate | `reminder_toggled` events | Which reminder type do people disable? |
| Interval combos | Co-occurrence of eye+posture intervals | Are users tuning both, or just one? |
| Settings-open-from-overlay rate | `overlay_settings_tapped` per session | Navigation pattern: overlay → settings |

---

### Tier 4 — UX Health Signals (os.log derived)

| Signal | Derived From | Healthy | Investigate If |
|--------|-------------|---------|---------------|
| Permission grant rate | `permission_granted` / (`permission_granted` + `permission_denied`) | >85% | <70% — onboarding copy unclear |
| Permission revoke rate | `permission_denied type=notifications` after prior grant | <5% | >10% — overlay is too intrusive |
| Force-quit / jetsam rate | `MXAppExitMetric backgroundExitData` | <2% of exits | >5% — memory issue |
| Double-overlay (queue) rate | `overlay_queued` / `overlay_shown` | <1% | >5% — scheduling logic bug |
| Cold launch after terminate | `app_launch type=cold` following `app_terminate` vs. crash | Baseline | Spikes = crash loop |
| Settings-from-overlay funnel | `overlay_settings_tapped` → `setting_changed` | >50% | <30% — settings navigation broken |

---

## Privacy Checklist

### No PII in Logs

- [ ] **No usernames, emails, or account identifiers** — app has no accounts
- [ ] **No device identifiers** — never log `UIDevice.current.identifierForVendor`
- [ ] **No timestamps that could identify a user's schedule** — log relative durations (`display_duration_sec`), not wall-clock times of user actions
- [ ] **All user-facing string values use `privacy: .private`** — if we ever add custom reminder labels, they must be private
- [ ] **All structural values (type names, durations, counts) use `privacy: .public`** — these are enum values and integers, not personal data
- [ ] **Log calls in release builds** — os.log is safe in release; debug-only calls use `.debug` level which is compiled to near-zero overhead

### No Device Identifiers

- [ ] Never log `identifierForVendor` (IDFV)
- [ ] Never log `advertisingIdentifier` (IDFA) — we have no AdServices entitlement
- [ ] MetricKit payloads carry no user or device identifier — they are aggregate/diagnostic
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
| App Usage | Other usage data | No (os.log stays on device) | N/A | N/A |
| Contact Info | Any | No | N/A | N/A |
| Identifiers | Any | No | N/A | N/A |

**Correct declaration:** "Data Not Collected" for all user-linked categories. The crash/performance data is collected by Apple infrastructure, not by our app sending it to our servers. Select "Crash Data" under Diagnostics only if you forward MetricKit payloads to your own server in Phase 3 — in Phase 2, it stays in os.log and Apple's systems.

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
subsystem:com.yashasg.eyeposturereminder
subsystem:com.yashasg.eyeposturereminder category:Scheduling
subsystem:com.yashasg.eyeposturereminder category:Overlay
subsystem:com.yashasg.eyeposturereminder "overlay_dismissed"
subsystem:com.yashasg.eyeposturereminder "permission_denied"
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

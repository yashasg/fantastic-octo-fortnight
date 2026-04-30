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

### 2025-07-25 — Analytics & Observability Audit (Ralph quality pass)

- **Codebase has zero analytics instrumentation** — only debug/info os.Logger calls already in `Logger.scheduling`, `Logger.overlay`, `Logger.settings`, `Logger.lifecycle`. No analytics events emitted.
- **Key event emission points identified:**
  - `ScreenTimeTracker.tick()` → `onThresholdReached?(type)` callback in AppCoordinator (~line 126): reminder_triggered
  - `OverlayView.performDismiss()` (~line 159): overlay_dismissed with method (button vs swipe vs settings_tap) — no method discrimination currently
  - `OverlayView.performAutoDismiss()` (~line 179): overlay_auto_dismissed
  - `SettingsViewModel.snooze(option:)` (~line 142): snooze_applied, snooze_limit_hit
  - `AppCoordinator.handleSnoozeWake()` (~line 401): snooze_expired
  - `PauseConditionManager.update(_:isActive:)` (~line 239): pause_condition_activated/cleared
  - `OnboardingView.finishOnboarding()` (~line 28): onboarding_completed
  - `OnboardingPermissionView.requestNotificationPermission()` (~line 72): onboarding_permission_tapped/skipped
- **Onboarding has no funnel instrumentation** — `OnboardingView.currentPage` changes fire no events. Cannot determine drop-off screen.
- **Overlay dismiss method is not differentiated** — `performDismiss()` handles × button, swipe, and settings gear tap identically. Must add `method` parameter to distinguish for Tess's discoverability analysis.
- **MetricKit not integrated** — `MXCrashDiagnostic` and `MXHangDiagnostic` are P0 for overlay UIWindow correctness. `MXAppExitMetric` jetsam count is the memory health signal.
- **Timer drift not tracked** — `ScreenTimeTracker.tick()` has 0.5s tolerance but no drift measurement. Recommend wall-clock delta check per tick.
- **Provider recommendation:** App Store Connect + MetricKit only for Phase 1–2 TestFlight. TelemetryDeck for Phase 3 if gaps remain. No Firebase/Google Analytics — "Data Not Collected" label must be maintained.
- **Issues created:** #31 (event schema), #34 (MetricKit/os.Logger), #37 (provider recommendation) — all under TestFlight milestone with `squad` label.

### 2026-04-25: Analytics & Observability Audit — Spawn Wave Quality Pass

**Scope:** Post-Phase-2 audit of telemetry infrastructure, event instrumentation coverage, and provider selection

**Three issues filed (#31, #34, #37):**

1. **#31: Core event schema + instrumentation** — 9 key events unmapped (reminder_triggered, overlay_dismissed, snooze_applied, pause_condition state changes, onboarding funnel, etc.). Onboarding has zero funnel tracking; overlay dismiss method not differentiated (button vs swipe). Post-Phase-2 enhancement.

2. **#34: MetricKit + os.Logger integration** — MetricKit is P0 for TestFlight (crashes, hangs, exits, battery). os.Logger categories already defined (4 subsystems); dSYM upload critical for crash symbolication. Ready for Phase 2 implementation.

3. **#37: Provider recommendation** — Use App Store Connect + MetricKit only; TelemetryDeck optional Phase 3. Maintain "Data Not Collected" privacy posture. No Firebase/Google Analytics. Rationale: privacy compliance, zero overhead, Apple native tools proven at scale.

**Key interaction with other audits:**
- Complements Saul's code review: P1 bugs (#22 snooze reset, #23 overlay stall) now traceable via MetricKit hangs/crashes
- Validates Rusty's edge cases: MetricKit provides hang diagnostics for #26 state machine, #27 overlay race
- Informs Livingston's test strategy: event schema defines what test coverage needs
- Enables Tess's UX validation: snooze button discoverability measurable once overlay_dismissed method differentiation implemented

**Signal gaps identified:**
- Timer drift measurement missing (Rusty's #28 counter reset validation)
- Snooze preset effectiveness unmeasured (Reuben cannot validate defaults)
- Onboarding drop-off not tracked (cannot identify funnel leak screens)

**Quality note:** Zero analytics instrumentation in Phase 1–2 is acceptable — base telemetry (App Store Connect + MetricKit) provides sufficient diagnostic surface for TestFlight quality gate.

### 2025-07-25 — Analytics Instrumentation Audit v2 (Post-Implementation)

- **Coverage score: 3/10** — Schema is well-designed (11 events, clean naming, correct privacy annotations) but critically under-wired.
- **5 of 11 events never emitted** — `appSessionStart`, `appSessionEnd`, `reminderTriggered`, `overlayDismissed`, `overlayAutoDismissed`, and `snoozeExpired` have no `AnalyticsLogger.log()` call at their trigger points. Only `snoozeActivated`, `settingChanged` (2 of 7 settings), `pauseActivated`, and `pauseDeactivated` are live.
- **MetricKitSubscriber.register() never called in AppDelegate** — `didFinishLaunchingWithOptions` sets up notification center but omits MetricKit registration. Zero diagnostic payloads during TestFlight.
- **Settings instrumentation partial** — Only `pauseDuringFocus` and `pauseWhileDriving` emit `settingChanged`. Global toggle, per-type toggles, intervals, break durations, and haptics toggle are silent.
- **Overlay dismiss method not differentiated at call site** — `DismissMethod` enum exists but `performDismiss()` is called identically from button, swipe, and settings gear. Cannot measure Tess's discoverability signal.
- **Privacy: clean** — No PII, no user IDs, no ATT, no network calls. "Data Not Collected" label safe.
- **Fix is straightforward** — All missing events need only `AnalyticsLogger.log()` calls at existing trigger points. No schema changes required. ~1 hour estimated.
- **Report filed:** `.squad/decisions/inbox/turk-analytics-pass-v2.md`

### 2026-04-28 — Read-Only Telemetry/Privacy Audit (Post-#299)

**Scope:** Full audit of AnalyticsLogger event schemas, stable raw values, privacy annotations, TELEMETRY.md/PRIVACY.md alignment, and #299 IPC event slot behavior.

**Result: Clean — no new issues filed.**

**Verified clean:**
- **18 AnalyticsEvent cases** — all emit via `AnalyticsLogger.log()` at correct trigger points in AppCoordinator, SettingsViewModel, PauseConditionManager, OverlayView (via callback), and AppCoordinatorWatchdogRecovery.
- **Stable raw values** — all enum raw values (`ShieldTriggerReason`, `DismissMethod`, `ReminderDeliveryPath`, `SchedulePath`, `SchedulePathReason`, `IPCOperation`, `IPCFailureReason`, `PauseConditionSource`, `SnoozeOption.analyticsCode`) are hardcoded snake_case strings, not localized. #278 fix confirmed (snooze uses `analyticsCode` not label).
- **Privacy annotations** — `.public` on all enum codes and numeric durations; `.private` on `settingChanged` old/new values (intentional, documented). No PII, no device IDs, no user IDs, no free-form user-authored strings.
- **TELEMETRY.md** — matches code for all 18 event schemas, stable raw value tables, privacy checklist, dashboard tier definitions. IPC Health section documents all `IPCOperation`/`IPCFailureReason` codes.
- **PRIVACY.md** — accurately describes local-only data, Apple diagnostics only, no third-party SDKs, no custom analytics backend. Screen Time/App Group IPC data correctly scoped.
- **#299 IPC event slot behavior** — per-event slot keys (`trueInterrupt.ipc.event.<UUID>`) eliminate cross-process read-modify-write race. `ipc_operation_failed` analytics event covers `writeEvent` failures. Pruning is best-effort, bounded to `maxEventCount=100`.
- **`watchdogRecoveryTriggered` detail field** — constructed from deterministic constants (`watchdog_device_activity_heartbeat_missing` or `watchdog_device_activity_heartbeat_stale:<WatchdogHeartbeatDetail.rawValue>`), not PII. Documented as "non-PII operational code" in TELEMETRY.md.
- **No localized or free-form values in any analytics path** — legacy `snooze(for:)` uses `"\(minutes)m"` format but is deprecated with no production callers.

**No material telemetry, privacy, or documentation gaps found.**

### 2026-04-30 — Read-Only Telemetry/Privacy Audit (Post-#302–#314)

**Scope:** Full audit after #302–#314 changes (onboarding a11y, overlay modal trait, Customize Settings CTA, IPC corrupt-log fix, CI hardening, docs fixes).

**Result: 1 new issue filed (#316).**

**Verified clean (no regressions):**
- **18 AnalyticsEvent cases** — unchanged, all still wired at correct trigger points. No analytics call sites added, modified, or removed by #302–#314.
- **Stable raw values** — all enum raw values remain hardcoded snake_case strings. No localized or free-form values introduced.
- **Privacy annotations** — unchanged. `.public` on all enum codes and numeric durations; `.private` on `settingChanged` old/new values. No PII in any analytics path.
- **TELEMETRY.md** — matches code for all 18 events, stable raw value tables, privacy checklist, dashboard tiers. No docs drift from #302–#314 changes.
- **PRIVACY.md** — accurate. Legal placeholders (`[PUBLISHER NAME]`, `[CONTACT EMAIL]`) untouched per charter.
- **#306 IPC fix** — `AppGroupIPCStore` now logs a warning on corrupt legacy `eventLog` instead of throwing. This is an `os.Logger` warning (not an analytics event), correctly scoped. No analytics impact.
- **#308–#310 a11y changes** — `OverlayManager.dismissOverlay()` now posts `screenChanged` notification. No analytics impact; overlay dismiss analytics still fire before this a11y notification.
- **#311/#313/#314 onboarding changes** — `OnboardingInterruptModeView` gained a tertiary "Customize Settings" CTA button. `OnboardingView.finishOnboardingAndCustomize()` sets `openSettingsOnLaunch` flag and calls `finishOnboarding()`. Neither path emits any analytics event.

**Material gap found:**
- **#316 filed:** `onboardingCompleted` event missing. Two distinct onboarding exit CTAs ("Get Started" vs "Customize Settings") are uninstrumented. Cannot measure onboarding completion rate or CTA choice distribution. Original #31 schema proposed this event but it was never implemented. Now more impactful because #314 added a second CTA with different product intent.

**No other gaps:** All other #302–#314 changes are docs, CI, a11y, or squad history — no telemetry surface area affected.

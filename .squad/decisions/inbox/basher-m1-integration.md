# Basher — M1.6 Integration Decisions

**Date:** 2026-04-24  
**Author:** Basher (iOS Dev — Services)  
**Phase:** M1.6 Integration & Edge Case Handling

---

## Decision 1: AppCoordinator conforms to ReminderScheduling

**Context:** `SettingsViewModel` had `scheduler: ReminderScheduling` pointing at `coordinator.scheduler` (the raw `ReminderScheduler`). This meant setting changes in the denied-notifications path updated UNNotifications (silently failing) but never restarted fallback timers.

**Decision:** `AppCoordinator` now conforms to `ReminderScheduling` and `SettingsView` passes `coordinator` directly. All four protocol methods (`scheduleReminders(using:)`, `rescheduleReminder(for:using:)`, `cancelReminder(for:)`, `cancelAllReminders()`) route through the coordinator's auth-aware paths so notifications and fallback timers always stay in sync.

**Impact on tests:** `SettingsViewModelTests` uses `MockReminderScheduler` — the init signature `(settings:scheduler:)` is unchanged. No test modifications needed.

---

## Decision 2: Per-type reschedule debounce lives in AppCoordinator

**Context:** Rapid slider changes in `SettingsView` can fire `reminderSettingChanged(for:)` many times per second, flooding `UNUserNotificationCenter` with add/remove pairs.

**Decision:** `AppCoordinator.reschedule(for:)` debounces per-type using Swift structured concurrency (`Task` cancellation, 300 ms window). The `MockReminderScheduler` has no debounce, so existing `SettingsViewModelTests` (including `test_rapidSettingChanges_allReschedulesAreTriggered`) continue to pass and correctly test SettingsViewModel dispatch behaviour. The integration-level debounce is production-only.

---

## Decision 3: Overlay queue replaces silent drop

**Context:** `OverlayManager.showOverlay` previously logged a warning and returned if an overlay was already on screen. If eye and posture reminders fired within seconds of each other (common with short debug intervals), one was silently lost.

**Decision:** Concurrent `showOverlay` calls are appended to an internal FIFO queue. After each `dismissOverlay`, the manager pops and presents the next entry. `clearQueue()` is exposed so `cancelAllReminders()` and snooze paths can flush pending overlays.

---

## Decision 4: AudioInterruptionManager implemented (no longer Phase 2 stub)

**Context:** `AudioInterruptionManager` was a stub since M1.1. The decisions.md user directive (2026-04-24T00:57) explicitly marked audio interruption as a Phase 1 requirement.

**Decision:** `pauseExternalAudio()` now activates `AVAudioSession` with `.soloAmbient` (interrupts Spotify/Podcasts, respects silent switch, no Control Center entry). `resumeExternalAudio()` deactivates with `.notifyOthersOnDeactivation`. Wired into `OverlayManager` on every show/dismiss path.

**Why `.soloAmbient` not `.playback`:** `.playback` would ignore the silent switch and create a phantom Control Center "now playing" entry since we don't actually play audio. `.soloAmbient` interrupts others cleanly without either side effect.

---

## Decision 5: Background/foreground lifecycle in EyePostureReminderApp

**Context:** Fallback timers (`Timer`) accumulate missed fires when the app returns from background, potentially triggering an immediate overlay burst. Notifications don't have this problem.

**Decision:**
- `.background` → `coordinator.appWillResignActive()` stops all fallback timers.
- `.active` after true background (tracked by `@State var wasInBackground`) → `coordinator.handleForegroundTransition()` refreshes auth status and restarts the correct strategy (notifications or fresh fallback timers from t=0).
- Brief `.inactive` interruptions (task switcher, control centre) do NOT trigger a full reschedule, avoiding unnecessary `UNUserNotificationCenter` traffic.

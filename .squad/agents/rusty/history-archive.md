## Learnings

### 2026-04-26: Architecture Audit v2 — Deeper Pass

**Scope:** Full re-read of all key files (AppCoordinator, ScreenTimeTracker, PauseConditionManager, OverlayManager, AnalyticsLogger, MetricKitSubscriber, ReminderScheduler, SettingsViewModel, AppDelegate, Package.swift).

**Key new findings (beyond v1):**

1. **🔴 P0: ScreenTimeTracker and its protocol lack `@MainActor`** — all access is main-thread in practice (Timer, NotificationCenter observers), but no compile-time enforcement. This will fail under Swift 6 strict concurrency. Protocol `ScreenTimeTracking` must also be annotated.
2. **🟡 P1: PauseConditionManager and detector protocols also lack `@MainActor`** — same class of issue. `PauseConditionProviding` callbacks cross isolation boundaries without Sendable guarantees.
3. **🟡 P1: Analytics events `.reminderTriggered`, `.overlayDismissed`, `.overlayAutoDismissed`, `.appSessionEnd` are defined but never emitted** — analytics system has gaps that undermine its debugging value.
4. **🟢 P2: `AppDelegate.coordinator` is strong (not weak)** — safe in single-window app but defensive improvement for multi-scene.
5. **🟢 P2: `resumeAll()` doesn't reset elapsed counters (asymmetric with `pauseAll()`)** — intentional design, but undocumented.

**v1 P1s confirmed still open:** AnalyticsEvent Sendable, MetricKitSubscriber unregistered.

**Score:** 8/10 (down from 8.5). Report: `.squad/decisions/inbox/rusty-arch-pass-v2.md`

### 2026-04-26: Edge Case Analysis — Quality Pass (Issues #26–#29)

**Scope:** Full read of AppCoordinator, ScreenTimeTracker, OverlayManager, PauseConditionManager, ReminderScheduler, SettingsStore, AppDelegate, EyePostureReminderApp.

**Four confirmed bugs filed:**

| # | Issue | Severity | Root cause |
|---|---|---|---|
| #26 | PauseConditionManager stale state when pause-setting toggled mid-condition | High | `update()` only called on detector callbacks, not on settings changes — `activeConditions` never re-evaluated when `pauseDuringFocus`/`pauseWhileDriving` flips |
| #27 | Active overlay stays visible when driving/CarPlay pause fires | Medium-High | `onPauseStateChanged(true)` only calls `screenTimeTracker.pauseAll()`, never `overlayManager.dismissOverlay()` |
| #28 | ScreenTimeTracker elapsed counter wiped on break-duration change | Medium | `setThreshold` always resets `elapsed[type] = 0` — called for all reminder settings changes, not just interval changes |
| #29 | Snooze-wake notification is user-visible banner; dismissed banner = dead snooze on killed app | Low-Medium | `scheduleSnoozeWakeNotification` sets title/body; `didReceive` never fires if user swipes banner away; killed-app self-heals only on next manual open |

**Key architecture invariants confirmed safe:**
- `ScreenTimeTracker` grace period (5s) correctly handles notification banners, incoming calls, Control Center pulls.
- `OverlayManager` overlay queue handles concurrent eye+posture threshold hits.
- `AppCoordinator.onPauseStateChanged(false)` correctly checks snooze state before resuming.
- `wasInBackground` flag correctly gates `handleForegroundTransition` to genuine background→foreground only.
- `OverlayView` uses `Timer.scheduledTimer` which auto-pauses on `willResignActive` — device-sleep countdown drift is NOT an issue.
- `scenePhase .active` calls `presentPendingOverlayIfNeeded()` safely — `pendingOverlay` is nil-checked and cleared on first use.
- Periodic `UNNotificationTrigger` (legacy scheduler path) is dead code post-ScreenTimeTracker migration — the 60s minimum trigger interval constraint cannot be hit.

**Findings ruled out (not bugs):**
- Force-quit during overlay: all `onDismiss` callbacks are `{}` — no state to corrupt. Self-heals on relaunch.
- Clock/DST changes: snooze uses `date.timeIntervalSinceNow` at schedule time, not stored interval. `max(0, ...)` handles forward time jumps. Backward jumps extend snooze — acceptable edge case.
- Short intervals (<60s): blocked by ScreenTimeTracker's `threshold > 0` guard. UNTimeIntervalTrigger min is not hit.
- CarPlay raw port string `"CarPlay"`: matches Apple's SDK raw value. Fragile but not wrong.

### 2026-04-25: Architecture Review — Updated ARCHITECTURE.md (04:35 spawn)
- **Deliverable:** ARCHITECTURE.md rewritten with 6 major corrections
- **Corrections:** Module graph accuracy, protocol definitions, SPM structure, trigger model, AppConfig initialization, onboarding state machine
- **Impact:** New authority for impl team; resolved ambiguities in Services/Views boundaries; informed Basher's DI protocol design (#13, #14)
- **Quality note:** Corrections validate Rusty's edge case analysis (#26–#29) — state machine invariants properly documented post-review.


## Session 6 Update: Screen-Time Triggers Architecture Finalized

**Session:** 2026-04-24T20:58Z – 2026-04-24T21:37Z

### Architecture Review Complete ✅

Reviewed Danny's screen-time spec and approved with **6 required amendments** (documented in Decision 3.2):

**Critical Amendment — Grace Period (5s debounce):**
```swift
func handleWillResignActive() {
    pauseTimer()  // stop incrementing immediately
    resetTask = Task { [weak self] in
        try? await Task.sleep(nanoseconds: UInt64(5.0 * 1_000_000_000))
        guard !Task.isCancelled else { return }
        self?.resetElapsedTime()
    }
}

func handleDidBecomeActive() {
    if let resetTask {
        resetTask.cancel()  // came back within grace period
        resumeTimer()
    } else {
        startTracking()  // genuine screen-off (grace expired)
    }
}
```

**Why this matters:** Without the grace period, notification banners, incoming calls, and Control Center pulls would reset the timer to zero. User loses 19 minutes of accumulated time because a text arrived — feature feels broken.

### Implementation Status

Basher implemented ScreenTimeTracker per architecture spec (Decision 3.4):
- ✅ Standalone service (not in AppCoordinator)
- ✅ 5s grace period with Task-based cancellation
- ✅ Monotonic clock (`CACurrentMediaTime()`)
- ✅ `isEnabled` flag for snooze suppression
- ✅ `Timer.tolerance = 0.5` for battery coalescing
- ✅ Build: **BUILD SUCCEEDED**

### Module Structure Realized

```
Services/
├── ScreenTimeTracker.swift (NEW) — lifecycle + timer + thresholds
├── ReminderScheduler.swift (NARROWED) — UNNotifications for snooze-wake only
├── AppCoordinator.swift (UPDATED) — subscribes to tracker events, wires to overlays
└── OverlayManager.swift — unchanged

Dependency flow:
  AppCoordinator → ScreenTimeTracker (owns, start/stop/reset)
  ScreenTimeTracker → (callback) → AppCoordinator (what to do with threshold events)
  AppCoordinator → OverlayManager (present reminders)
```

### Testing Strategy Documented

For Livingston's unit tests:
- `MockTimerFactory` — fires ticks on demand (no real timers in tests)
- `AppLifecycleProviding` protocol — tests inject `PassthroughSubject` for lifecycle events
- `MockTimeProvider` — clock is mockable
- Test cases: grace period, threshold firing, multi-threshold handling, snooze suppression, settings reschedule, system clock immunity

### Next: Testing Phase

Livingston will implement ScreenTimeTracker unit tests using mock factories + mock lifecycle provider. 8 test cases documented in architecture review; ~60-80 lines of test code per case.



## 2026-04-25 — Architecture: Wave 2 Testing Strategy Documentation

**Status:** ✅ Complete  
**Scope:** Testing architecture patterns and conventions documented in ARCHITECTURE.md

### Orchestration Summary

- **Testing Layers Defined:** Unit (manager + detectors), Integration (cross-component), UI (XCUITest)
- **Conventions Established:** Mocking patterns, fixture factory, async test patterns
- **XCUITest Requirements Documented:** Blocker (SPM limitation) and workaround (add .xcodeproj)
- **Data Flow Diagrams:** Testing architecture visually documented
- **Orchestration Log:** Filed at `.squad/orchestration-log/2026-04-24T23-19-18Z-rusty.md`

### Architecture Decisions

- Layered testing aligns with clean MVVM architecture
- Fixture factory pattern for detector mocks (reusable across test suites)
- Test environment flags via launchArguments for reproducible UI testing
- Documented test data patterns (UserDefaults mocking, NotificationCenter test doubles)

### Next Phase

Testing infrastructure documented and ready. XCUITest blocker (Phase 2) documented in decisions.md.



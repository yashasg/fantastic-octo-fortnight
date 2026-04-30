# Project Context

- **Owner:** Yashasg
- **Project:** Eye & Posture Reminder — a lightweight iOS app with background timers and full-screen overlay reminders for eye breaks (20-20-20 rule) and posture checks
- **Stack:** Swift, SwiftUI (iOS 16+), MVVM, UserNotifications, UIKit overlay, UserDefaults
- **Created:** 2026-04-24

## Core Context

**Phase 1–4 implementation history (2026-04-24 to 2026-04-25):**
- Services layer: SettingsStore, ReminderScheduler, AppCoordinator, OverlayManager, PauseConditionManager (FocusMode, CarPlay, Driving), ScreenTimeTracker with grace-period/reset state machine
- Data-driven config: AppConfig.swift + defaults.json (seeds UserDefaults on first launch; resetToDefaults() clears & re-seeds)
- Test infrastructure: MockSettingsPersisting, MockNotificationCenter, MockTimerFactory, MockAppLifecycleProvider for deterministic testing
- Bundle resource resolution: SPM `Bundle.module` in test code resolves to test target bundle, not production; production resources live in `EyePostureReminder_EyePostureReminder.bundle`
- SettingsStore two-layer pattern: UserDefaults layer (persistent) + AppConfig seeding layer (first-launch only)
- PauseConditionManager: reads settings at callback time (not registration); settings changes do NOT retroactively remove activeConditions
- ScreenTimeTracker: `CACurrentMediaTime()` monotonic clock + 5s grace period state machine + resume/pause tracking + independent eye/posture counters
- OverlayView: swipe-UP dismiss (translation.height < 0), Settings gear button calls onDismiss(), haptic feedback (medium impact) at countdown zero
- Info.plist: NSFocusStatusUsageDescription + NSMotionUsageDescription required; omitting either causes crash at first API access
- Build patterns: `./scripts/build.sh build` for compilation; `./scripts/run.sh` for bundle assembly with Info.plist refresh
- Build verified clean: Phase 1 tests passing, Phase 2–4 integration tests stable

**SPM/Swift ecosystem learnings:**
- UNTimeIntervalNotificationTrigger(repeats: true) requires ≥ 60s (OS silently rejects < 60s); use dynamic `repeats: interval >= 60`
- Code bundle ≠ resource bundle in SPM; UIColor(named:) + NSLocalizedString only search resource bundle
- LiveFocusStatusDetector uses KVO on focusStatus (not Notification.Name.INFocusStatusDidChange which does not exist)
- LiveCarPlayDetector checks AVAudioSession.Port(rawValue: "CarPlay") (AVAudioSession.Port.carPlay does not exist)
- LiveDrivingActivityDetector uses CMMotionActivityManager.startActivityUpdates; guards isActivityAvailable() for simulator

**Test patterns established:**
- @MainActor test class for async/UI work; sync tests are non-@MainActor (no decorators)
- MockNotificationCenter: addedRequests (append-only history) + pendingRequests (live queue)
- @testable import accesses protocol definitions inline (no Protocols/ folder needed)
- Bundle injection on AppConfig.load() + SettingsStore.init() for fixture testing

## Team Sync — 2026-04-25T04:35

**PR #17 Status:**
- ScreenTimeTracking + PauseConditionProviding DI protocols complete
- All 575 tests pass
- Ready for team review and Views layer integration
- Aligns with Rusty's architecture corrections

**Next:** Await PR #17 review; support Views team in Phase 2 completion

### 2026-04-26 — Quality Sweep: Service Layer Quality Audit

**Quality sweep findings from 8-agent parallel audit (read-only, no code changes):**

**4 Warnings (edge cases to handle):**

1. **OverlayManager.showOverlay() silently drops requests** — When `isOverlayVisible == false` and no active `UIWindowScene`, request returns early without queueing or `onDismiss` callback. ScreenTimeTracker-triggered overlays racing against scene activation could be lost. **Action:** Queue the request (same as `isOverlayVisible` path) and drain from `presentNextQueuedOverlay()`.

2. **ScreenTimeTracker.handleWillResignActive() doesn't cancel prior resetTask** — Assigning `resetTask` without cancelling existing one first. If notification fires twice unexpectedly, two Tasks both survive and call `resetAll()`. **Action:** Add `resetTask?.cancel()` before `resetTask = Task { … }`.

3. **AppCoordinator.cancelAllReminders() reads stale auth status** — Snooze-wake notification gated on `notificationAuthStatus == .authorized`. This property not refreshed inside `cancelAllReminders()`, so stale `.notDetermined` status (possible on first snooze before permission prompt resolves) silently skips wake notification. **Action:** Refresh auth status before gate, or remove gate and let `notificationCenter.add(_:)` fail gracefully (already catches/logs).

4. **PauseConditionManager.focusMode initial state not seeded** — `.carPlay` and `.driving` initial states seeded after detectors start, but `.focusMode` is not. `LiveFocusStatusDetector` only fires on transitions, not initial state, so Focus mode already active at cold launch won't pause until next change. **Action:** After `focusDetector.startMonitoring()`, read `focusDetector.isFocused` and call `update(.focusMode, isActive: ...)`. Mirrors carPlay/driving seeding.

**5 Suggestions (documentation/structure):**

1. **AppCoordinator implicit ordering contract** — `cancelAllReminders()` reads `settings.snoozedUntil` to arm wake task. Callers must set `snoozedUntil` **before** calling `cancelAllReminders()`. Correctly respected in `SettingsViewModel.snooze(option:)` but undocumented. **Action:** Add doc comment precondition on `cancelAllReminders()`.

2-5. Other async/MainActor patterns solid, no action needed.

**What's working well:**
- All `async throws` paths properly guarded
- `@MainActor` isolation consistent throughout
- Combine subscriptions correctly managed

**Cross-cutting impacts:**
- Test coverage critical path (Livingston audit) identified service-layer edge cases. Basher should be aware of test fixes for edge cases above.
- UI team (Linus) may need to handle overlay queue backpressure gracefully.

**Next owner action:** Implement the 4 warning fixes post-Phase-1. Add the 1 doc comment suggestion immediately.

## Learnings — 2026-04-27 — Service layer bug fixes (#117, #118, #119)

### #117 — OverlayManager: silent drop on no active scene
- **Root cause:** `showOverlay()` returned early with an error log when no `UIWindowScene` was `.foregroundActive`, discarding the overlay request entirely.
- **Fix:** Append the overlay tuple to `overlayQueue` (same structure as the already-visible path) so it is served by `presentNextQueuedOverlay()` once a scene activates.
- **Pattern:** Both "already visible" and "no scene" paths now funnel into the same queue; the existing `presentNextQueuedOverlay` guard handles scene re-check at dequeue time.

### #118 — ScreenTimeTracker: double resetTask without cancellation
- **Root cause:** `handleWillResignActive()` assigned a new `Task` to `resetTask` without cancelling the previous one. A rapid double `willResignActive` (or future code path) would leave both tasks alive, both passing `guard !Task.isCancelled`, causing `resetAll()` twice.
- **Fix:** One line — `resetTask?.cancel()` immediately before `resetTask = Task { … }`.
- **Pattern:** Whenever re-assigning an optional `Task` property, always cancel the previous value first. The existing `handleDidBecomeActive` already did this correctly (line 169–170); `handleWillResignActive` was the only missing site.

### #119 — PauseConditionManager: focusMode initial state not seeded
- **Root cause:** `startMonitoring()` seeded `.carPlay` and `.driving` initial states (fix from #73) but omitted `.focusMode`. If Focus is already active at cold-start, `activeConditions` would not include `.focusMode` until the next focus-change event.
- **Fix:** Add `update(.focusMode, isActive: focusDetector.isFocused && settings.pauseDuringFocus)` alongside the other two seed calls.
- **Pattern:** After calling each detector's `startMonitoring()`, always seed all three conditions: `.focusMode`, `.carPlay`, `.driving`.

### #133 — OverlayManager: overlay queue drain gap on scene activation
- **Root cause:** `presentNextQueuedOverlay()` was only called from `dismissOverlay()`. When `showOverlay()` queued an item because no `UIWindowScene` was foreground-active AND nothing was currently showing, dismiss never fires so the queue drained only on the next overlay dismissal — which never came.
- **Fix:** Register a `UIScene.didActivateNotification` observer in `init` (on `OperationQueue.main`, wrapped in `Task { @MainActor in }`) that calls `presentNextQueuedOverlay()` whenever a scene activates. The observer is stored as `sceneActivationObserver: NSObjectProtocol?` and removed in `deinit`.
- **Pattern:** Any queue that can only be drained by its own consumer (dismissal) needs a secondary drain trigger for the "nothing is showing" case. Scene-activation notification is the correct hook for UIWindowScene-dependent work.
- **Observer lifecycle:** Store `NSObjectProtocol` token from `addObserver(forName:object:queue:using:)` and call `NotificationCenter.default.removeObserver(_:)` in `deinit`. Do NOT use `addObserver(_:selector:name:object:)` on `@MainActor` classes — the closure-based API with `[weak self]` is safer for `final` classes.

## Learnings — 2026-04-28 — Background Reminder Capability Audit

### P0 Finding: ScreenTimeTracker-only model breaks background reminders
- **Root cause:** `AppCoordinator.scheduleReminders()` calls `scheduler.cancelAllReminders()` as a "legacy safety net", then configures only `ScreenTimeTracker`. `ScreenTimeTracker` is a 1-second `Timer` that pauses on `willResignActiveNotification` and resets counters after 5s grace. It cannot run in the background. Result: zero reminders fire while the user is in another app.
- **Key file evidence:** `AppCoordinator.swift` line 292 ("Cancel any legacy periodic UNNotifications — reminders are now driven exclusively by ScreenTimeTracker"); `ReminderScheduler.swift` lines 80-88 ("Superseded — never called in production").
- **What works in-app:** `ScreenTimeTracker` → `onThresholdReached` → `overlayManager.showOverlay()` at `.alert + 1` window level. This path is correct for foreground use.
- **What's already wired correctly:** `AppDelegate.willPresent` + `didReceive` both route to `coordinator.handleNotification(for:)` → overlay or `pendingOverlay` stash. The notification delivery plumbing is complete and will work immediately when periodic notifications are re-enabled.
- **iOS constraint confirmed:** `UNTimeIntervalNotificationTrigger(repeats: true, timeInterval: ≥60)` is the correct and only mechanism for periodic background delivery. `BGTaskScheduler` and location/audio background modes are inappropriate.
- **Action filed:** `.squad/decisions/inbox/basher-reminder-background-capability.md` — needs team decision to restore hybrid trigger model (ScreenTimeTracker for foreground + UNNotification for background).

### Key file paths for background reminder work
- `EyePostureReminder/Services/AppCoordinator.swift` — `scheduleReminders()` (line ~255), `configureScreenTimeTracker()` (line ~579), `handleNotification(for:)` (line ~343)
- `EyePostureReminder/Services/ReminderScheduler.swift` — `rescheduleReminder(for:using:)` already has correct `UNTimeIntervalNotificationTrigger` implementation; just needs calling
- `EyePostureReminder/App/AppDelegate.swift` — `willPresent` and `didReceive` notification delegates (complete)
- `EyePostureReminder/Services/ScreenTimeTracker.swift` — `handleWillResignActive()` at line ~218; `resetGracePeriod = 5.0`
- `EyePostureReminder/Views/Onboarding/OnboardingPermissionView.swift` — requests `[.alert, .sound, .badge]` correctly; no denied-permission recovery UI

### Notification permission / Settings routing
- `OnboardingPermissionView` calls `onNext()` after system prompt regardless of outcome. Denied users have no in-onboarding recovery path.
- `SettingsView` (line ~505) has `UIApplication.openSettingsURLString` button shown when `notificationAuthStatus != .authorized` — this is the current recovery path, reachable via overlay gear icon → `openSettingsOnLaunch` flag → `HomeView` opens `SettingsView`.
- The routing is functional but indirect. A direct "Go to Settings" button in onboarding post-denial is optional but recommended.

## Learnings — 2026-04-28 — P0 Fix: Restore background periodic notifications

### Implementation decision: Hybrid trigger model

**Decision:** Restore `UNNotificationRequest` periodic scheduling alongside `ScreenTimeTracker`. Neither replaces the other; both are needed for full coverage.

- **Background path (restored):** `AppCoordinator.scheduleReminders()` now calls `scheduler.scheduleReminders(using: settings)` when auth is `.authorized`, scheduling a repeating `UNTimeIntervalNotificationTrigger` per enabled type. When denied it calls `cancelAllReminders()` to clean up any stale entries.
- **Foreground path (unchanged):** `ScreenTimeTracker` fires the in-app overlay after continuous screen-on time. After firing, it now reschedules the background notification to reset the interval from the moment of the foreground trigger — preventing a near-simultaneous double banner when the user goes to another app.
- **Notification delivery → overlay:** `handleNotification(for:)` now resets the `ScreenTimeTracker` counter for the delivered type so the foreground timer does not immediately re-fire after a notification-triggered overlay.
- **Per-type reschedule:** `performReschedule(for:)` now properly reschedules (enabled) or cancels (disabled) the background notification alongside the tracker update.
- **Snooze guard intact:** The existing early-return in `scheduleReminders()` for active snooze prevents notification scheduling during snooze, preserving snooze behavior end-to-end.

### Key paths changed (commit aa7be3e)
- `AppCoordinator.scheduleReminders()` — removed "cancel legacy" block, added conditional `scheduler.scheduleReminders(using:)` / `cancelAllReminders()`
- `AppCoordinator.onThresholdReached` callback — added post-overlay `scheduler.rescheduleReminder` Task
- `AppCoordinator.handleNotification(for:)` — added `screenTimeTracker.reset(for: type)`
- `AppCoordinator.performReschedule(for:)` — moved `scheduler.cancelReminder` into disabled branch; added `scheduler.rescheduleReminder` to enabled branch
- `ReminderScheduler.swift` — updated "Superseded" comment to reflect production use

### Tests run
- `AppCoordinatorTests` — all 33 tests pass (including 9 P0 regression tests pre-written by Livingston in dc42ad3)
- Full `EyePostureReminderTests` suite — all suites passed clean

## 2026-04-29T05:05:06Z: Squad Orchestration — Interrupt Mode Pivot

**Orchestration logs filed:**
- `2026-04-29T05-05-06Z-basher-background-reminder-audit.md` — P0 audit findings
- `2026-04-29T05-05-06Z-basher-restore-hybrid-reminders.md` — hybrid model implementation, commit aa7be3e

**Session log:** `.squad/log/2026-04-29T05-05-06Z-interrupt-mode-pivot.md`

**Decisions merged:** All 9 inbox files → canonical `.squad/decisions/decisions.md`.

## 2026-04-29 — #204 Unblocked Compile-Safe Slice (Basher + Linus)

**Issue:** #204 M3.4 FamilyControls Authorization & App/Category Picker UI
**Branch:** `squad/m3-true-interrupt-mode`

### New service/model files
- **`ScreenTimeAuthorizationProviding.swift`** — `ScreenTimeAuthorizationStatus` enum (4 cases, all `Sendable`) + `ScreenTimeAuthorizingProviding` protocol. No `FamilyControls` import. `localizedStatusKey` property drives Settings status row copy.
- **`ScreenTimeAuthorizationNoop.swift`** — Pre-entitlement noop. Always returns `.unavailable`. Default injected by `AppCoordinator`.
- **`SelectedAppsState.swift`** — `@MainActor ObservableObject`. App Group `UserDefaults` (`group.com.yashasgujjar.kshana`). Stores `SelectedAppsMetadata` (categoryCount, appCount, lastUpdated — `Codable`, no opaque FamilyControls tokens). Init accepts any `UserDefaults` for test isolation.
- **`AppCoordinator`** — Added `screenTimeAuthorization: ScreenTimeAuthorizingProviding` (injectable, default `ScreenTimeAuthorizationNoop()`).

### Test files
- `MockScreenTimeAuthorizationProviding.swift` — call-recording mock with `stubbedStatus`, `stubbedRequestResult`, `reset()`.
- `ScreenTimeAuthorizationTests.swift` — 17 tests: noop behaviour, enum raw values, `localizedStatusKey` stability, mock call recording.
- `SelectedAppsStateTests.swift` — 18 tests: `SelectedAppsMetadata` codability/equality, `SelectedAppsState` init/persistence/reinit. All use isolated `UserDefaults` suites.

### Persistence constants (stable — shared with extension targets)
- App Group: `group.com.yashasgujjar.kshana`
- Enabled key: `trueInterrupt.enabled`
- Metadata key: `trueInterrupt.selectionMetadata`

### Build verified: `./scripts/build.sh test` → ✓ Tests passed (35 new tests)

## 2026-04-30 — Services/Lifecycle Read-Only Audit (post-#299)

### Audit Scope
Services: AppCoordinator, ReminderScheduler, ScreenTimeTracker, OverlayManager, PauseConditionManager, ScreenTimeAuthorizationNoop, WatchdogHeartbeat, AppGroupIPCStore, SettingsViewModel, SelectedAppsState, ScreenTimeExtensions/Shared.

### P0 Finding: #306 — readEventsCombined throws hard on corrupt legacy eventLog key

**Root cause:** `readEventsCombined` (introduced in #299 commit a520be3) throws `StoreError.corruptEventLog` when the legacy `trueInterrupt.ipc.eventLog` key is corrupt. Per-slot corrupt entries are silently skipped (consistent behavior). Since `clearEvents()` has no production call site, a corrupt legacy key permanently blocks `readEvents()` and therefore `recoverStaleDeviceActivityWatchdogIfNeeded`. Watchdog recovery returns `false` on any `readEvents()` error.

**Fix:** Downgrade `throw StoreError.corruptEventLog` in the legacy read path to a warning log + continue, consistent with per-slot skip behavior.

**Owner:** Tess (squad:tess) — reviewer-lockout on #299 artifact.

**Issue filed:** #306

### All other service paths clean
- ScreenTimeTracker: stale-tick race fixed (tickingGeneration, commit 587bf38); resetTask cancel-before-reassign confirmed fixed (from #118)
- AppCoordinator: snooze guard path correct; notificationAuthStatus refreshed before snooze gate in scheduleReminders()
- PauseConditionManager: focusMode initial state seeded (from #119)
- OverlayManager: scene-activation drain observer present (from #133)
- WatchdogHeartbeat: per-slot writes are cross-process safe (#299)
- pruneEventSlots: counts only slot keys (not legacy), slight inaccuracy when legacy events exist — self-corrects, not critical
- Snooze/cancel behavior correct in SettingsViewModel; cancelAllReminders() snooze-wake path uses last-known notificationAuthStatus (pre-existing, no new issue)

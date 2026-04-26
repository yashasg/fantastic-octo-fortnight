# Project Context

- **Owner:** Yashasg
- **Project:** Eye & Posture Reminder — a lightweight iOS app with background timers and full-screen overlay reminders for eye breaks (20-20-20 rule) and posture checks
- **Stack:** Swift, SwiftUI (iOS 16+), MVVM, UserNotifications, UIKit overlay, UserDefaults
- **Created:** 2026-04-24

## Learnings

### 2026-04-25 — TestBundle helper for SPM resource bundle resolution (Issue #11)

- **Root cause of 70 test failures:** `Bundle.module` inside `@testable import EyePostureReminder` resolves to the *test* target's bundle, not the production module's resource bundle. Colors.xcassets, Localizable.xcstrings, and defaults.json are absent from the test bundle.
- **Fix:** `Tests/.../Mocks/TestBundleHelper.swift` — `enum TestBundle` with a `module` static property that locates `EyePostureReminder_EyePostureReminder.bundle` by walking candidates starting from `Bundle(for: SettingsStore.self)`. Falls back to the code bundle if the named resource bundle is not found (handles both Xcode and CLI configurations).
- **SPM resource bundle naming convention:** `{PackageName}_{TargetName}.bundle`. For this project that is `EyePostureReminder_EyePostureReminder.bundle`.
- **Do NOT modify Package.swift** — the test target structure is correct; the problem is purely lookup-side.
- **Helpers provided:** `TestBundle.module`, `TestBundle.testColor(named:)`, `TestBundle.testLocalizedString(key:value:)` — Livingston can migrate failing tests to use these.

### 2026-04-25 — TestBundleHelper Creation (Issue #11, Basher Part)

- **File created:** `Tests/EyePostureReminderTests/Mocks/TestBundleHelper.swift`
- **Purpose:** Resolve production module's resource bundle from test code — `Bundle.module` inside `@testable import EyePostureReminder` resolves to test target's bundle, not production.
- **Implementation:** `enum TestBundle` with static `module` property that walks candidates from `Bundle(for: SettingsStore.self)` looking for `EyePostureReminder_EyePostureReminder.bundle` (SPM naming: `{PackageName}_{TargetName}.bundle`).
- **Fallback strategy:** If named resource bundle not found, use code bundle (handles both Xcode and CLI build contexts).
- **Helpers provided:** `testColor(named:)`, `testLocalizedString(key:value:)` for convenience.
- **Decision:** Do NOT modify Package.swift — test target structure is correct; fix is purely lookup-side.
- **Outcome:** Enabled Livingston to fix 70 failing tests across 5 suites by migrating them to use `TestBundle.module`.

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

## Learnings — 2026-04-24 — DI Protocols for AppCoordinator (Issues #13, #14)

### Architecture decisions
- `ScreenTimeTracking` protocol added directly above `ScreenTimeTracker` in the same file — keeps protocol/conformance co-located, avoids a separate Protocols/ folder
- `AppCoordinator.init()` uses optional parameters with `?? default` pattern: `screenTimeTracker: ScreenTimeTracking? = nil` defaulting to `ScreenTimeTracker()`. This avoids making callers (EyePostureReminderApp) provide explicit defaults while still allowing full injection in tests.
- `pauseConditionManager` internal property typed as `PauseConditionProviding` (protocol), not `PauseConditionManager` — same injection pattern as above

### Mock patterns
- `MockScreenTimeTracker` and `MockPauseConditionProvider` live in `Tests/EyePostureReminderTests/Mocks/`
- Both follow the established call-recording pattern: `private(set) var xyzCallCount = 0` + simulation helpers
- `simulateThresholdReached(for:)` and `simulatePauseStateChange(_:)` allow tests to trigger AppCoordinator reactions without real timers

### Bundle resolution bug (AppConfigTests)
- **Root cause:** `@testable import EyePostureReminder` causes the production module's `static let module: Bundle` (on Foundation.Bundle) to shadow the test target's generated accessor. The test was loading production defaults (eyeInterval: 1200) instead of fixture values (900).
- **Fix:** Replace `Bundle.module` in `AppConfigTests.testBundle` with explicit path construction: `Bundle(for: AppConfigTests.self).bundleURL.appendingPathComponent("EyePostureReminder_EyePostureReminderTests.bundle")`
- **Pattern:** Any test file that uses `Bundle.module` AND does `@testable import` of a module with resources must use explicit xctest bundle path, not `Bundle.module`

### JSON key rename missed (AppConfig.Features)
- Livingston renamed `masterEnabledDefault` → `globalEnabledDefault` in AppConfig.swift but did NOT update `defaults.json` (production) or `Fixtures/defaults.json` (test fixture)
- Fix: updated both JSON files to use `globalEnabledDefault`
- **Lesson:** When renaming Codable property names, always grep for the old name in JSON files

### Key file paths
- `EyePostureReminder/Services/ScreenTimeTracker.swift` — protocol + implementation
- `EyePostureReminder/Services/AppCoordinator.swift` — DI init params
- `Tests/EyePostureReminderTests/Mocks/MockScreenTimeTracker.swift` — new mock
- `Tests/EyePostureReminderTests/Mocks/MockPauseConditionProvider.swift` — new mock  
- `Tests/EyePostureReminderTests/Fixtures/defaults.json` — test fixture (900s eye interval, maxSnoozeCount: 5)
- `EyePostureReminder/Resources/defaults.json` — production defaults (1200s eye interval, maxSnoozeCount: 3)

## Learnings — Service Quality Review (2026-04-26)

### Summary
Full read-only audit of EyePostureReminder/Services/ and EyePostureReminder/ViewModels/. Zero critical issues. Four warnings, five suggestions.

### Key Findings

**🟡 Warning — OverlayManager.swift L114–119: Overlay silently dropped on no active scene**
When `isOverlayVisible == false` and no `UIWindowScene` is `.foregroundActive`, `showOverlay()` returns after logging an error — the request is not queued for retry and `onDismiss` is never called. This can silently lose a reminder on a notification-tap cold-launch race. The `pendingOverlay` path in `AppCoordinator.handleNotification(for:)` is a partial mitigation but only covers the notification-tap path; ScreenTimeTracker-triggered overlays that race against scene activation are unprotected.

**🟡 Warning — ScreenTimeTracker.swift L218–233: `handleWillResignActive()` doesn't cancel prior `resetTask`**
A second `willResignActive` notification (theoretically impossible but defensive) creates a new `resetTask` without cancelling the first. Both tasks survive, both pass `guard !Task.isCancelled`, and `resetAll()` is called twice. Fix: add `resetTask?.cancel()` before creating the new task.

**🟡 Warning — AppCoordinator.swift L584–589: Stale `notificationAuthStatus` in `cancelAllReminders()`**
The snooze-wake notification is gated on `notificationAuthStatus == .authorized`, but that value is not refreshed inside `cancelAllReminders()`. If called at a moment when the cached status is stale (e.g., `.notDetermined` on first snooze before the permission prompt resolves), the wake notification is silently skipped. A `Task { await refreshAuthStatus() }` before the gate would close this.

**🟡 Warning — PauseConditionManager.swift L259–262: `.focusMode` initial state not seeded**
`startMonitoring()` explicitly seeds `.carPlay` and `.driving` initial conditions after calling `startMonitoring()` on each detector, but `.focusMode` is not seeded. `LiveFocusStatusDetector` only fires `onFocusChanged` on transitions; if Focus is already active when the app cold-launches and the user authorises, the initial `isFocused = true` callback only fires inside `DispatchQueue.main.async` after KVO registration — but by that point the `update(.focusMode, isActive: …)` seed has already run with the old `isFocused = false` default. If Focus is off → on → still on between KVO registration and the app coming to foreground, the condition stays invisible to `PauseConditionManager`.

**🟢 Suggestion — AppCoordinator.swift L587: Strong `self` capture in fire-and-forget Task**
`Task { await self.scheduleSnoozeWakeNotification(at: snoozeEnd) }` captures `self` strongly. Harmless in practice (coordinator is long-lived), but `[weak self]` is the consistent pattern everywhere else in this file.

**🟢 Suggestion — AppCoordinator.swift L584: Implicit ordering contract undocumented**
`cancelAllReminders()` arms the snooze-wake task by reading `settings.snoozedUntil`, which requires callers to set `snoozedUntil` before calling `cancelAllReminders()`. This ordering contract is respected in `SettingsViewModel.snooze(option:)` but not documented in either method.

**🟢 Suggestion — ReminderScheduler.swift L79–88: "Superseded" methods lack test-only marker**
`scheduleReminders(using:)` and `rescheduleReminder(for:using:)` are commented as "never called in production" but are real scheduling implementations used by unit tests. An `@available(*, deprecated, message: "Protocol shim only")` or a clear "test-path only" warning in the doc comment would prevent accidental production use.

**🟢 Suggestion — AnalyticsLogger.swift L128–131: `settingChanged` old/new values use `privacy: .private`**
`old_value` and `new_value` in the `settingChanged` event are logged with `.private` — they're redacted in Console.app on release builds. Since values are non-PII configuration integers (intervals, durations), `.public` would aid debugging without privacy risk.

**🟢 Suggestion — MetricKitSubscriber.swift: Thread safety of `didReceive` callbacks undocumented**
`MXMetricManagerSubscriber` callbacks fire on an arbitrary thread. Implementation only calls `Logger` (thread-safe), so there's no actual bug, but a comment noting the thread-safety invariant would help future contributors avoid accidentally accessing shared state here.

### No Critical Issues Found
All system API calls are properly guarded. No force unwraps, no `try!`, no unhandled errors. `@MainActor` isolation is consistent across all service classes. Combine cancellable management in `PauseConditionManager` is correct (`.dropFirst()` pattern, `cancellables.removeAll()` on stop). Snooze, overlay queue, and grace-period state machines are well-implemented.

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

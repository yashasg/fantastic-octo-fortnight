---
name: "date-provider-default-seam"
description: "Route default service time reads through DateProviding while preserving explicit-now overloads for tests"
domain: "testing"
confidence: "high"
source: "earned"
---

## Context
Use when a service method currently takes `now: Date = Date()` and production code relies on that default, creating a hidden global clock dependency.

## Pattern
- Inject `DateProviding` at the owning service/coordinator.
- Add a zero-argument method that calls the explicit overload with `dateProvider.now`.
- Keep `func method(now: Date)` for deterministic test control.
- For guard logic without overloads (e.g., snooze-active checks), route comparisons through `dateProvider.now` and assert both injected-now inversion cases in tests.
- For debounced workflows (`reschedule(for:)` → delayed `performReschedule`), put the snooze/time guard in the delayed method behind `dateProvider.now` and verify via the public entrypoint after waiting beyond debounce.
- For enum or helper structs that currently compute dates from `Date()`, add a `referenceDate` overload and keep the old computed property as a convenience wrapper.
- For lifecycle cleanup hooks (for example `clearExpiredSnoozeIfNeeded`), evaluate stale-state guards with `dateProvider.now` and add inversion tests where wall-clock and injected clock disagree.
- For notification-delivery snooze guards (`handleNotification`), evaluate suppression with `dateProvider.now` so reminder delivery respects injected time seams in deterministic tests.
- For pause-condition resume guards (`onPauseStateChanged` resume path), evaluate snooze checks with `dateProvider.now` and assert inversion tests by simulating pause-clear callbacks.
- For launch-time scheduler snooze guards (`scheduleReminders`), compare against `dateProvider.now` and add inversion tests for wall-clock future/injected expired and wall-clock past/injected active.
- For foreground-transition snooze guards (`handleForegroundTransition`), compare expiry against `dateProvider.now` and assert inversion tests where wall-clock and injected clocks disagree.
- For lifecycle session metrics initialized during scheduling, seed `sessionStartTime` from `dateProvider.now` (not `Date()`) so `appSessionEnd` duration assertions stay deterministic under injected clocks.
- For launch-readiness latency metrics, capture foreground-entry timestamps and latency deltas from the same injected `dateProvider.now` seam; in tests, advance `MockDateProvider.now` during an awaited dependency callback to prove wall-clock time is not used.
- For constructor-level clock defaults, prefer `dateProvider: DateProviding? = nil` plus `makeDateProvider` fallback and resolve once in `init`; add paired fallback-used and explicit-bypass tests that assert behavior through a public method.

## Benefits
- Production path no longer depends on implicit `Date()` globals.
- Existing tests can stay precise by passing explicit timestamps.
- Keeps behavior stable with `SystemDateProvider` default.

## Example
- `EyePostureReminder/Services/AppCoordinatorWatchdogRecovery.swift`
- `Tests/EyePostureReminderTests/Services/AppCoordinatorWatchdogHeartbeatTests.swift`
- `EyePostureReminder/Services/AppCoordinator+ReminderScheduling.swift`
- `Tests/EyePostureReminderTests/Services/AppCoordinatorExtendedTests.swift`
- `EyePostureReminder/ViewModels/SettingsViewModel.swift`
- `Tests/EyePostureReminderTests/ViewModels/SettingsViewModelExtendedTests.swift`
- `EyePostureReminder/ViewModels/SettingsViewModel.swift` (`makeDateProvider` constructor seam)
- `Tests/EyePostureReminderTests/ViewModels/SettingsViewModelExtendedTests.swift` (`snooze(for:)` fallback-used/explicit-bypass assertions)
- `EyePostureReminder/Services/AppCoordinator.swift`
- `Tests/EyePostureReminderTests/Services/AppCoordinatorTests.swift`
- `Tests/EyePostureReminderTests/Services/AppCoordinatorExtendedTests.swift`
- `EyePostureReminder/Services/AppCoordinator.swift` (`makeDateProvider` seam)
- `Tests/EyePostureReminderTests/Services/AppCoordinatorTests.swift` (`cancelAllReminders` fallback/bypass assertions)

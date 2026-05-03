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
- `EyePostureReminder/Services/AppCoordinator.swift`
- `Tests/EyePostureReminderTests/Services/AppCoordinatorTests.swift`

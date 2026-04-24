# Decision Inbox: P1 Review Fixes + M2.3 Snooze
**By:** Basher (iOS Dev – Services)
**Date:** 2026-04-25

---

## Decision 1 — NotificationScheduling extended with getAuthorizationStatus()

**What:** Added `getAuthorizationStatus() async -> UNAuthorizationStatus` to the `NotificationScheduling` protocol instead of `getNotificationSettings() -> UNNotificationSettings`.

**Why:** `UNNotificationSettings` has no public initializer, making it impossible to stub in mock implementations. Returning `UNAuthorizationStatus` directly is simpler, sufficient for all current call sites, and trivially mockable.

**Impact:** `MockNotificationCenter` now returns `.authorized` when `authorizationGranted == true`, `.denied` otherwise. `FailOnceNotificationCenter` returns `.authorized`. All existing tests compile and pass.

---

## Decision 2 — overlayManager default via nil-coalescing in init, not as default parameter

**What:** `AppCoordinator.init` declares `overlayManager: OverlayPresenting? = nil` and resolves to `OverlayManager.shared` inside the init body, not as the parameter default expression.

**Why:** Swift disallows `@MainActor`-isolated values (like `OverlayManager.shared`) as default parameter expressions. Using `nil` with nil-coalescing in the body avoids actor-isolation compiler errors while preserving the ergonomic single-argument call site for tests and production alike.

---

## Decision 3 — Snooze wake uses both in-process Task and UNNotification

**What:** When a snooze is detected in `scheduleReminders()`, two wake mechanisms are armed:
1. `snoozeWakeTask: Task` — fires while app is in foreground/background (in-process).
2. A one-time silent `UNNotificationRequest` with `snoozeWakeCategory` — fires even if the app was killed.

**Why:** A `Task.sleep` alone is insufficient if the app is killed. A notification alone would require the user to tap the banner. Using both ensures seamless auto-resume in all lifecycle states. The in-process task cancels the notification when it fires; the notification routes to `scheduleReminders()` via `AppDelegate` which cancels the task.

---

## Decision 4 — Snooze count reset placement

**What:** `snoozeCount` is reset to 0 in three places:
1. `handleNotification(for:)` — a real reminder overlay fired.
2. `cancelSnooze()` — user manually cancelled the snooze.
3. `scheduleReminders()` when snooze expiry is detected — alongside `snoozedUntil = nil`.

**Why:** The count tracks "consecutive snoozes without a real reminder firing". All three represent the end of a snooze cycle: a real break occurred, user cancelled voluntarily, or the snooze expired naturally. Resetting in all three keeps the invariant clean.

---

## Decision 5 — snooze(for:) preserved for backward compatibility

**What:** The existing `snooze(for minutes: Int)` method is kept with the same `cancelAllReminders()` + no `scheduleReminders()` contract. New `snooze(option: SnoozeOption)` is the forward-looking API.

**Why:** Existing `SettingsViewModelTests` assert `scheduleRemindersCallCount == 0` and `cancelAllCallCount == 1` for `snooze(for: 5)`. Changing that contract would require test rewrites. The wake timer is armed by `cancelAllReminders()` on `AppCoordinator` (which checks `snoozedUntil` set just before the call), so no `scheduleReminders()` call is needed from the ViewModel.

---

## Decision 6 — SnoozeOption.restOfDay endDate

**What:** `restOfDay` computes as `Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))`, falling back to `Date() + 24h` if Calendar returns nil.

**Why:** This correctly maps to midnight of the current day in the user's local timezone, regardless of DST transitions. Avoids hardcoding 86400 seconds which would be wrong on DST change days.

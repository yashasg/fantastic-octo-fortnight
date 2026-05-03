# Skill: Assertion-Driven Coverage Upgrades

## Pattern
When a test exists only to hit lines, replace it with explicit state-transition assertions that encode behavior contracts.

## Use when
- A suite has zero-assertion tests.
- Coverage appears high but regressions can slip through unverified paths.
- Lifecycle methods (`refresh`, `foreground`, `notification handlers`) are called without postconditions.

## Steps
1. Seed deterministic preconditions with mocks (auth denied/authorized, expired/future snooze).
2. Execute the target API.
3. Assert concrete postconditions (published status, persisted snooze fields, call history arrays).
4. For side-effect APIs, assert exact interactions (`== [expected]`) instead of weak `contains` checks.
5. If assertions expose unsafe behavior, add the smallest production guard and pin with regression tests.

## Example from #497/#498
- `refreshAuthStatus()` now asserted `.notDetermined -> .denied`/`.authorized`.
- `clearExpiredSnoozeIfNeeded()` now asserted stale snooze cleanup.
- `handleNotification(for:)` now guarded during active snooze and verified to suppress overlay/reset side effects.

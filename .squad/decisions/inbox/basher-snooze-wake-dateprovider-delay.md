# Basher Decision: Snooze wake delay uses injected DateProviding

## Context
PR #578 surfaced intermittent failures in `AppCoordinatorExtendedTests.test_handleForegroundTransition_usesInjectedDateProvider_whenWallClockPastButInjectedFuture`.

## Decision
Compute snooze wake delays using `date.timeIntervalSince(dateProvider.now)` for both in-process wake task and wake notification scheduling.

## Why
`handleForegroundTransition` correctly uses `dateProvider.now` for snooze guard logic, but wake scheduling previously used wall-clock `timeIntervalSinceNow`. In inversion tests this scheduled a zero-delay wake that raced assertions and occasionally cleared snooze state before verification.

## Impact
Production behavior is unchanged with `SystemDateProvider`; tests become deterministic under injected clock seams.

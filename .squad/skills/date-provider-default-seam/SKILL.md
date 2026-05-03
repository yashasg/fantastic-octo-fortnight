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

## Benefits
- Production path no longer depends on implicit `Date()` globals.
- Existing tests can stay precise by passing explicit timestamps.
- Keeps behavior stable with `SystemDateProvider` default.

## Example
- `EyePostureReminder/Services/AppCoordinatorWatchdogRecovery.swift`
- `Tests/EyePostureReminderTests/Services/AppCoordinatorWatchdogHeartbeatTests.swift`

---
name: "reminder-scheduler-factory-seam"
description: "Inject ReminderScheduling fallback factory in AppCoordinator init"
domain: "testing"
confidence: "high"
source: "earned"
---

## Context
Use when `AppCoordinator` (or similar coordinator) accepts an optional `ReminderScheduling` dependency and currently constructs `ReminderScheduler()` directly when nil.

## Pattern
- Keep `scheduler` optional in initializer.
- Add optional fallback factory: `makeScheduler: (() -> ReminderScheduling)? = nil`.
- Resolve once in init with precedence: explicit dependency -> factory -> concrete fallback.
- Preserve runtime behavior by keeping `ReminderScheduler()` as the final production fallback.
- Add two focused tests: factory-used and explicit-scheduler-bypasses-factory.

## Examples
- `EyePostureReminder/Services/AppCoordinator.swift`
- `Tests/EyePostureReminderTests/Services/AppCoordinatorTests.swift`

## Anti-Patterns
- Direct `ReminderScheduler()` construction without a factory seam in coordinator init.
- Re-resolving scheduler in multiple methods instead of a single init-time resolution.

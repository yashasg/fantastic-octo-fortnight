---
name: "app-state-provider-factory-seam"
description: "Inject UIApplication state provider with optional factory fallback for deterministic lifecycle tests"
domain: "testing"
confidence: "high"
source: "earned"
---

## Context
Use when a lifecycle-aware service reads `UIApplication.shared` directly for foreground/background checks and you need deterministic tests.

## Patterns
- Keep the protocol seam (`AppStateProviding`) for explicit injection.
- Add optional fallback factory injection (`makeAppStateProvider`) and resolve once in `init`.
- Preserve production behavior with `UIApplication.shared` only on fallback.
- Add two focused tests:
  - fallback factory used when provider is nil
  - explicit provider bypasses factory

## Examples
- `EyePostureReminder/Services/ScreenTimeTracker.swift`
- `Tests/EyePostureReminderTests/Services/ScreenTimeTrackerTests.swift`

## Anti-Patterns
- Direct `UIApplication.shared` reads in constructor paths with no seam coverage.
- Testing private dependency state instead of public behavior (`startIfActive()` callback path).

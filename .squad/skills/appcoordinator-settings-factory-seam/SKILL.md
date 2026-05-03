---
name: "appcoordinator-settings-factory-seam"
description: "Inject makeSettings fallback in AppCoordinator to remove hidden SettingsStore construction"
domain: "testing"
confidence: "high"
source: "earned"
---

## Context
Use when `AppCoordinator` currently falls back to `SettingsStore()` directly and you need a DI seam without changing runtime behavior.

## Patterns
- Keep `settings` optional in initializer (`settings: SettingsStore? = nil`).
- Add optional fallback factory (`makeSettings: (() -> SettingsStore)? = nil`).
- Resolve once in init with precedence: explicit settings -> factory -> `SettingsStore()`.
- Add two focused tests: fallback-used and explicit-settings-bypasses-factory.

## Examples
- `EyePostureReminder/Services/AppCoordinator.swift`
- `Tests/EyePostureReminderTests/Services/AppCoordinatorTests.swift`

## Anti-Patterns
- Direct `SettingsStore()` construction in coordinator resolver paths with no override seam.
- Re-resolving settings in lifecycle methods after init.

---
name: "scalar-config-provider-seam"
description: "Inject scalar config defaults via optional value + provider factory"
domain: "testing"
confidence: "high"
source: "earned"
---

## Context
Use when an initializer default argument eagerly loads config (for example `AppConfig.load()`) for a scalar value.

## Patterns
- Prefer `value: Int? = nil` (or other scalar optional).
- Add `makeValue: () -> Int` fallback factory with production default.
- Resolve once in `init`: `let resolved = value ?? makeValue()`.
- Add two focused tests:
  - fallback factory used when explicit value is nil
  - explicit value bypasses fallback factory

## Examples
- `EyePostureReminder/ViewModels/SettingsViewModel.swift`
- `Tests/EyePostureReminderTests/ViewModels/SettingsViewModelExtendedTests.swift`

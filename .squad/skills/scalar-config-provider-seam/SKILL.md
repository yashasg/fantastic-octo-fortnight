---
name: "scalar-config-provider-seam"
description: "Inject scalar config defaults via optional value + provider factory"
domain: "testing"
confidence: "high"
source: "earned"
---

## Context
Use when an initializer default argument eagerly loads config (for example `AppConfig.load()`) for a scalar value or config object.

## Patterns
- Prefer `value: Int? = nil` (or other scalar optional).
- Add `makeValue: () -> Int` fallback factory with production default.
- Resolve once in `init`: `let resolved = value ?? makeValue()`.
- For config objects, use `config: AppConfig? = nil` plus `makeConfig: () -> AppConfig`.
- Keep behavior unchanged by continuing to pass explicit config in tests and defaulting to factory only when nil.
- Add two focused tests:
  - fallback factory used when explicit value is nil
  - explicit value bypasses fallback factory

## Examples
- `EyePostureReminder/ViewModels/SettingsViewModel.swift`
- `Tests/EyePostureReminderTests/ViewModels/SettingsViewModelExtendedTests.swift`
- `EyePostureReminder/Models/SettingsStore.swift`
- `Tests/EyePostureReminderTests/Models/SettingsStoreTests.swift`

## Anti-Patterns
- Avoid eager `config: AppConfig = AppConfig.load()` initializer defaults that hard-wire global config loading and hide DI seams.

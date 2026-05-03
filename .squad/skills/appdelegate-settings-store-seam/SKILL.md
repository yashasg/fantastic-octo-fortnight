---
name: "appdelegate-settings-store-seam"
description: "Resolve a single SettingsStore instance in AppDelegate via explicit dependency or fallback factory"
domain: "testing"
confidence: "high"
source: "earned"
---

## Context
Use when `AppDelegate` launch-argument handlers call `makeSettingsStore()` in multiple branches and tests need deterministic control over which settings instance is mutated.

## Pattern
- Add `settingsStore: SettingsStore? = nil` initializer input.
- Keep `makeSettingsStore` fallback factory with production default `{ SettingsStore() }`.
- Resolve once with lazy precedence: explicit settings -> factory.
- Route all launch-argument settings mutations through the single resolved instance.
- Add two focused tests: fallback-used-once and explicit-settings-bypasses-factory.

## Examples
- `EyePostureReminder/App/AppDelegate.swift`
- `Tests/EyePostureReminderTests/Services/AppDelegateTests.swift`

## Anti-Patterns
- Calling `makeSettingsStore()` repeatedly in launch-arg branches.
- Mixing explicit and factory-created settings instances in one launch flow.

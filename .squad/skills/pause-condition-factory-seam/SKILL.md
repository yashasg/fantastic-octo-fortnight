---
name: "pause-condition-factory-seam"
description: "Inject optional PauseConditionManager factory in AppCoordinator while preserving UI-test no-op behavior"
domain: "testing"
confidence: "high"
source: "earned"
---

## Context
Use when `AppCoordinator` directly constructs `PauseConditionManager(...)` in fallback paths and you need deterministic DI without changing runtime behavior.

## Pattern
- Add `makePauseConditionManager: ((SettingsStore) -> PauseConditionProviding)? = nil` to `AppCoordinator` init.
- In `resolvePauseConditionManager`, keep `uiTestMode` no-op short-circuit first.
- If an explicit provider is absent and factory exists, use the factory; otherwise use the production `PauseConditionManager(...)` fallback.
- Add two tests: factory-used when provider is nil, and explicit provider bypasses factory.

## Example
- `EyePostureReminder/Services/AppCoordinator.swift`
- `Tests/EyePostureReminderTests/Services/AppCoordinatorTests.swift`

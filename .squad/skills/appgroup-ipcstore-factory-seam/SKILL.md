---
name: "appgroup-ipcstore-factory-seam"
description: "Inject optional AppGroupIPCProviding plus fallback factory to avoid eager AppGroupIPCStore defaults"
domain: "testing"
confidence: "high"
source: "earned"
---

## Context
Use when a coordinator/service initializer defaults IPC persistence directly to `AppGroupIPCStore()` and you need deterministic fallback-path tests without changing behavior.

## Patterns
- Replace eager concrete default args with optional protocol injection (`ipcStore: AppGroupIPCProviding? = nil`).
- Add a fallback factory closure (`makeIPCStore`) that keeps production defaults.
- Resolve once in `init` (`ipcStore ?? makeIPCStore()`), then use the resolved store everywhere.
- Add two tests: factory called when explicit store is nil, and factory bypassed when explicit store is injected.

## Examples
- `EyePostureReminder/Services/AppCoordinator.swift`
- `Tests/EyePostureReminderTests/Services/AppCoordinatorTests.swift`

## Anti-Patterns
- `ipcStore: AppGroupIPCProviding = AppGroupIPCStore()` in initializer signatures.
- Re-instantiating `AppGroupIPCStore()` outside the resolved dependency path.

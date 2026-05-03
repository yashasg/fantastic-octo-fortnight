---
name: "active-scene-provider-seam"
description: "Inject AppCoordinator scene-activity checks to avoid direct UIApplication.shared reads"
domain: "testing"
confidence: "high"
source: "earned"
---

## Context
Use when service/coordinator logic branches on whether a foreground scene is active and currently reads `UIApplication.shared.connectedScenes` inline.

## Patterns
- Inject `hasActiveSceneProvider: (() -> Bool)? = nil` for direct explicit control in tests.
- Add optional fallback factory `makeHasActiveSceneProvider` for deterministic fallback-path assertions.
- Resolve once in `init`, then call the resolved provider at use sites.
- Keep production fallback scene lookup inside `init` (not default parameter values) to avoid Swift 6 actor-isolation errors from main-actor UIKit globals.
- Add two focused tests:
  - fallback factory used when explicit provider is nil
  - explicit provider bypasses fallback factory

## Examples
- `EyePostureReminder/Services/AppCoordinator.swift`
- `Tests/EyePostureReminderTests/Services/AppCoordinatorTests.swift`

## Anti-Patterns
- Reading `UIApplication.shared.connectedScenes` directly inside business/service methods.
- Putting `UIApplication.shared` scene closures directly in initializer default arguments.

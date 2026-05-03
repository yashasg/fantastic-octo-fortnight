---
name: "notification-center-observer-seam"
description: "Inject NotificationCenter for observer lifecycle wiring while preserving production defaults"
domain: "testing"
confidence: "high"
source: "earned"
---

## Context
Use when a service/coordinator registers observers via `NotificationCenter.default` and tests need deterministic isolation from global observer state.

## Pattern
- Add a `NotificationCenter` dependency with default `.default` in the initializer.
- Store it on the type and use it for both `addObserver` and `removeObserver`.
- In tests, inject a fresh `NotificationCenter()` and post notifications there.
- Add one negative assertion proving `NotificationCenter.default` does not drive behavior when a custom center is injected.

## Benefits
- Preserves runtime behavior in production.
- Removes hidden global coupling.
- Prevents cross-test interference from shared notification observers.

---
name: "overlay-presenting-factory-seam"
description: "Inject overlay presenter factory fallback to avoid direct OverlayManager construction"
domain: "testing"
confidence: "high"
source: "earned"
---

## Context
Use when a coordinator/service accepts an optional `OverlayPresenting` dependency but directly constructs `OverlayManager()` when nil.

## Pattern
- Keep dependency optional (`overlayManager: OverlayPresenting? = nil`).
- Add fallback factory closure (`makeOverlayManager: (() -> OverlayPresenting)? = nil`).
- Resolve once in `init` with precedence: explicit dependency → factory fallback → production concrete default.
- Preserve production behavior by keeping `OverlayManager()` as the final fallback.
- Add two focused tests: factory-used and explicit-overlay-bypasses-factory.

## Examples
- `EyePostureReminder/Services/AppCoordinator.swift`
- `Tests/EyePostureReminderTests/Services/AppCoordinatorTests.swift`

## Anti-Patterns
- Hardcoding `OverlayManager()` in initializer resolution without a factory seam.
- Mixing injected and freshly-constructed overlay presenters after dependency resolution.

---
name: "accessibility-poster-factory-seam"
description: "Inject accessibility poster via optional dependency plus fallback factory"
domain: "testing"
confidence: "high"
source: "earned"
---

## Context
Use when a service initializer eagerly constructs `LiveAccessibilityNotificationPoster()` (or similar concrete collaborator) in its parameter defaults.

## Pattern
- Change parameter to optional protocol type (`accessibilityNotificationPoster: AccessibilityNotificationPosting? = nil`).
- Add fallback factory (`makeAccessibilityNotificationPoster`) with current production default.
- Resolve once in `init` and store the resolved collaborator.
- Add two seam tests: fallback-used and explicit-bypass.

## Anti-Patterns
- Eager concrete construction in initializer defaults.
- Mixed usage of injected dependency and newly constructed concrete instances.

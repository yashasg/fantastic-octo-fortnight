---
name: "notification-center-observer-seam"
description: "Inject NotificationCenter for observer lifecycle wiring while preserving production defaults"
domain: "testing"
confidence: "high"
source: "earned"
---

## Context
Use when a service/coordinator registers observers via `NotificationCenter.default` and tests need deterministic isolation from global observer state.

## Patterns
- Add a `NotificationCenter` dependency with default `.default` in the initializer.
- Store it on the type and use it for both `addObserver` and `removeObserver`.
- For observer callbacks that read runtime state, inject a tiny state-provider closure (or protocol) so tests can drive callback outcomes deterministically.
- In `@MainActor` types where callback closures are nonisolated/sendable, keep provider seams compile-safe (for example with `nonisolated(unsafe)` immutable closure storage) and dispatch UI-state mutations back to main.
- In tests, inject a fresh `NotificationCenter()` and post notifications there.
- Add one negative assertion proving `NotificationCenter.default` does not drive behavior when a custom center is injected.

## Examples
- `EyePostureReminder/Services/AppCoordinator.swift` + `Tests/EyePostureReminderTests/Services/AppCoordinatorNotificationFallbackTests.swift`
- `EyePostureReminder/Services/ScreenTimeTracker.swift` + `Tests/EyePostureReminderTests/Services/ScreenTimeTrackerTests.swift`
- `EyePostureReminder/Services/PauseConditionManager.swift` (`LiveCarPlayDetector`) + `Tests/EyePostureReminderTests/Services/LiveCarPlayDetectorTests.swift`
- `EyePostureReminder/Services/OverlayManager.swift` + `Tests/EyePostureReminderTests/Services/OverlayManagerExtendedTests.swift`

## Anti-Patterns
- Registering on `NotificationCenter.default` and removing on a different center.
- Testing observer logic by posting only to `.default` while production code uses an injected center.
- Coupling observer callbacks directly to hard-to-control system singletons when a tiny seam would make behavior deterministic.

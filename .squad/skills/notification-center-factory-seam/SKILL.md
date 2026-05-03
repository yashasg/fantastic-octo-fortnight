---
name: "notification-center-factory-seam"
description: "Inject optional NotificationScheduling plus fallback factory to avoid eager UNUserNotificationCenter defaults"
domain: "testing"
confidence: "high"
source: "earned"
---

## Context
Use when a coordinator/service initializer defaults a notification dependency directly to `UNUserNotificationCenter.current()` and you need deterministic fallback-path tests.

## Patterns
- Replace eager concrete default args with optional protocol injection (`notificationCenter: Protocol? = nil`).
- Add a fallback factory closure (`makeNotificationCenter`) that keeps production singleton wiring.
- Resolve the dependency once in `init` and store the resolved instance.
- Add two tests: fallback factory invoked when explicit dependency is nil, and factory bypassed when explicit dependency is provided.

## Examples
- `EyePostureReminder/Services/AppCoordinator.swift`
- `Tests/EyePostureReminderTests/Services/AppCoordinatorTests.swift`

## Anti-Patterns
- `notificationCenter: NotificationScheduling = UNUserNotificationCenter.current()` in initializer signatures.
- Mixing direct singleton reads after resolving an injected/factory dependency.

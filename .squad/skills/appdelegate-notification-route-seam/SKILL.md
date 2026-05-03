---
name: "appdelegate-notification-route-seam"
description: "Unify AppDelegate notification category routing with a shared route resolver and dispatcher"
domain: "testing"
confidence: "high"
source: "earned"
---

## Context
Use when `AppDelegate` has duplicated category-ID routing logic across both `UNUserNotificationCenterDelegate` callbacks.

## Pattern
- Add a small route enum (e.g. `.reminder(ReminderType)`, `.snoozeWake`, `.ignore`).
- Add `notificationRoute(for:)` as a single category resolver.
- Add `dispatchNotificationRoute(_:)` for coordinator side effects.
- Call resolver + dispatcher from both `willPresent` and `didReceive`.
- Add focused route-mapping tests on the resolver method.

## Anti-Patterns
- Copy/pasting reminder/snooze routing branches in multiple delegate callbacks.
- Testing routing only through system-only notification objects instead of testing the resolver directly.

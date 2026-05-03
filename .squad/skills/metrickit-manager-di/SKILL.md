---
name: "metrickit-manager-di"
description: "Inject MXMetricManager behind a tiny protocol for deterministic service tests"
domain: "testing"
confidence: "high"
source: "earned"
---

## Context
Use this when a service calls `MXMetricManager.shared` directly, but the behavior you want to test is the interaction (`add(self)`) rather than MetricKit internals.

## Patterns
- Define a narrow protocol with only the methods used (`add(_:)`).
- Conform `MXMetricManager` to the protocol.
- Inject the protocol into the service initializer with `MXMetricManager.shared` as the default.
- Keep singleton entrypoints (like `static let shared`) for production wiring.
- If app lifecycle code triggers registration, inject a `MetricKitSubscribing` seam at the delegate boundary and lazily fallback to `MetricKitSubscriber.shared` at callback time.

## Examples
- `EyePostureReminder/Services/MetricKitSubscriber.swift`
- `Tests/EyePostureReminderTests/Services/MetricKitSubscriberTests.swift`
- `EyePostureReminder/App/AppDelegate.swift`
- `Tests/EyePostureReminderTests/Services/AppDelegateTests.swift`

## Anti-Patterns
- Calling `MXMetricManager.shared` directly from service methods when interaction testing is required.
- Creating broad protocols that mirror all MetricKit APIs when only one method is used.

---
name: "service-logger-di"
description: "Inject logger protocols into services to test logging side effects without global os.Logger coupling"
domain: "testing"
confidence: "high"
source: "earned"
---

## Context
Use this when a service mixes core logic with direct `Logger.lifecycle` calls and you need focused unit assertions for log side effects.

## Patterns
- Define a narrow logger protocol (`info`, `warning`, `error`) in the service boundary.
- Provide a small production adapter that forwards to `Logger.lifecycle`.
- Inject the logger via initializer with the adapter as the default.
- Keep message strings unchanged to preserve operational observability.

## Examples
- `EyePostureReminder/Services/MetricKitSubscriber.swift`
- `Tests/EyePostureReminderTests/Services/MetricKitSubscriberTests.swift`

## Anti-Patterns
- Directly asserting `os.Logger` output in unit tests.
- Replacing all logging with broad abstractions when only one service needs a seam.

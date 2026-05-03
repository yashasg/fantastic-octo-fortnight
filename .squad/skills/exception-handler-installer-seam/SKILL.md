---
name: "exception-handler-installer-seam"
description: "Inject an AppDelegate uncaught-exception installer closure for deterministic lifecycle tests"
domain: "testing"
confidence: "high"
source: "earned"
---

## Context
Use when app lifecycle delegates install uncaught Objective-C exception handlers directly in `didFinishLaunching`, which creates hard-to-test global side effects.

## Patterns
- Add an optional installer dependency (`installUncaughtExceptionHandler: (() -> Void)? = nil`) to the delegate initializer.
- Resolve once in `init` with precedence: explicit installer -> production default installer.
- Keep `installUncaughtExceptionHandler()` as the public method and route it through the resolved installer.
- Preserve production behavior by keeping the same `NSSetUncaughtExceptionHandler` logging closure in the default installer.
- Add focused tests that assert installer invocation both for direct method calls and launch-path wiring.

## Examples
- `EyePostureReminder/App/AppDelegate.swift`
- `Tests/EyePostureReminderTests/Services/AppDelegateTests.swift`

## Anti-Patterns
- Hard-coding `NSSetUncaughtExceptionHandler` inside delegate lifecycle methods with no seam.
- Unit tests that mutate global uncaught-exception handler state as setup/teardown.

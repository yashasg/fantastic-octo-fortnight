# Decision: #462 Phase A DI/SRP — AppDelegate UI-test overlay consumer seam

**Date:** 2026-05-03  
**Owner:** Basher (iOS Dev — Services)  
**Issue:** #462

## Context
`EyePostureReminderApp` was reading and mutating `UserDefaults.standard` directly to consume the debug-only `uiTestOverlayType` launch key. This bypassed the existing `AppDelegate` `uiTestDefaults` injection seam and left app-lifecycle glue coupled to a global singleton.

## Decision
Add a focused `AppDelegate.consumeUITestOverlayType()` helper (DEBUG-only) that reads from injected `uiTestDefaults`, returns a parsed `ReminderType`, and clears the key when consumed. Update `EyePostureReminderApp` to call this helper instead of touching `UserDefaults.standard`.

## Why
- Preserves existing runtime behavior (same one-shot consume-and-clear semantics).
- Strengthens DI/SRP: App lifecycle state access stays inside the delegate/service layer.
- Improves testability with isolated `UserDefaults` suites and deterministic unit coverage.

## Scope
- `EyePostureReminder/App/AppDelegate.swift`
- `EyePostureReminder/App/EyePostureReminderApp.swift`
- `Tests/EyePostureReminderTests/Services/AppDelegateTests.swift`

## Validation
- `./scripts/build.sh build` ✅
- `./scripts/build.sh test` ✅

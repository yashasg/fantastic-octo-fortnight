# Decision: #462 Phase A DI/SRP — AppDelegate Launch Arguments Provider Seam

**Date:** 2026-05-03  
**Owner:** Basher (iOS Dev — Services)  
**Issue:** #462

## Context
`AppDelegate.init` used `launchArguments: [String] = CommandLine.arguments`, which keeps a hidden process-global dependency in the initializer signature and makes fallback behavior hard to validate directly in unit tests.

## Decision
Switch `AppDelegate` launch-argument injection to:
- `launchArguments: [String]? = nil`
- `launchArgumentsProvider: () -> [String]` defaulting to `{ CommandLine.arguments }`

Resolve `self.launchArguments` inside `init` via `launchArguments ?? launchArgumentsProvider()`.

## Why
- Preserves production behavior (still uses `CommandLine.arguments` by default).
- Improves DI testability by allowing deterministic tests to prove:
  - fallback path calls provider when explicit launch args are absent
  - explicit launch args bypass provider
- Keeps the micro-slice surgical and SRP-focused on launch-context resolution.

## Scope
- `EyePostureReminder/App/AppDelegate.swift`
- `Tests/EyePostureReminderTests/Services/AppDelegateTests.swift`

## Validation
- `./scripts/build.sh build` ✅
- `./scripts/build.sh test` ✅

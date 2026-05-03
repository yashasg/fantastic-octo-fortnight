---
name: "launch-context-di-seam"
description: "Inject process environment and launch args at coordinator boundaries for deterministic tests"
domain: "testing"
confidence: "high"
source: "earned"
---

## Context
Use this when service or coordinator logic branches on process launch context
(`ProcessInfo.processInfo.environment`, `CommandLine.arguments`) and needs stable unit tests.

## Patterns
- Add injected initializer inputs for launch context with production-safe defaults.
- Thread injected values through resolver helpers instead of reading globals in helper bodies.
- Keep behavior unchanged by preserving the same default values used before extraction.
- For `@MainActor` coordinators, use optional init params for actor-isolated defaults and resolve to static values inside `init` (avoids Swift 6 nonisolated default-argument errors).

## Examples
- `AppCoordinator.init(..., processEnvironment: [String: String] = ProcessInfo.processInfo.environment, launchArguments: [String] = CommandLine.arguments, ...)`
- `resolveScreenTimeAuthorization(..., processEnvironment:, launchArguments:)` in `EyePostureReminder/Services/AppCoordinator.swift`.
- Focused coverage in `Tests/EyePostureReminderTests/Services/AppCoordinatorUITestLaunchContextTests.swift`.

## Anti-Patterns
- Reading launch context globals directly inside static resolvers.
- Overriding global process state in tests instead of injecting explicit values.

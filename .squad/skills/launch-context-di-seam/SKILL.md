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
- When launch-arg branches need service mutation (e.g., reset defaults / short overlay durations), inject a tiny factory closure (`makeSettingsStore`) instead of constructing concrete services inline.
- If multiple resolver branches depend on UI-test mode, compute `let resolvedUITestMode = uiTestMode ?? isUITestMode(launchArguments:)` once in `init` and pass that value into each resolver to prevent mixed global/injected behavior.
- For singleton-backed callbacks (e.g., app launch wiring), inject a zero-arg factory (`makeNotificationCenter`) and use it only on the fallback path so tests can validate callback behavior without invoking fragile system singletons directly.
- For launch-argument consumers in delegates/services, use `launchArguments: [String]? = nil` with an injected `launchArgumentsProvider` fallback closure so tests can verify both fallback and explicit-argument bypass paths deterministically.
- For coordinators that consume launch arguments in multiple places, resolve once (`let resolvedLaunchArguments = launchArguments ?? launchArgumentsProvider()`) and thread the resolved value through each branch to avoid mixed injected/global behavior.
- Apply the same optional+provider pattern to process environment reads (`processEnvironment: [String: String]? = nil`, `processEnvironmentProvider`) and resolve once in `init` before passing to resolver helpers.
- For coordinator lifecycle methods that branch on UI-test mode after init (for example `refreshAuthStatus`), persist the resolved init value in an instance property and guard on that property instead of static globals.

## Examples
- `AppCoordinator.init(..., processEnvironment: [String: String]? = nil, processEnvironmentProvider: @escaping () -> [String: String] = { ProcessInfo.processInfo.environment }, launchArguments: [String]? = nil, launchArgumentsProvider: @escaping () -> [String] = { CommandLine.arguments }, ...)`
- `resolveScreenTimeAuthorization(..., processEnvironment:, launchArguments:)` in `EyePostureReminder/Services/AppCoordinator.swift`.
- Focused coverage in `Tests/EyePostureReminderTests/Services/AppCoordinatorUITestLaunchContextTests.swift` (`test_init_withoutLaunchArguments_usesInjectedLaunchArgumentsProvider`, `test_init_withExplicitLaunchArguments_doesNotCallInjectedLaunchArgumentsProvider`, `test_init_withoutProcessEnvironment_usesInjectedProcessEnvironmentProvider`, `test_init_withExplicitProcessEnvironment_doesNotCallInjectedProcessEnvironmentProvider`).
- `AppDelegate.init(..., makeSettingsStore: @escaping @MainActor () -> SettingsStore = { SettingsStore() })` with usage in `applyUITestLaunchArguments()` and seam coverage in `Tests/EyePostureReminderTests/Services/AppDelegateTests.swift`.
- `AppDelegate.init(..., makeNotificationCenter: @escaping () -> UserNotificationCenterDelegating = { UNUserNotificationCenter.current() })` with fallback-path coverage in `test_didFinishLaunching_withNilNotificationCenter_usesInjectedFactory`.
- `AppDelegate.init(..., launchArguments: [String]? = nil, launchArgumentsProvider: @escaping () -> [String] = { CommandLine.arguments })` with fallback/bypass coverage in `test_init_withoutLaunchArguments_usesInjectedLaunchArgumentsProvider` and `test_init_withExplicitLaunchArguments_doesNotCallInjectedLaunchArgumentsProvider`.
- `AppCoordinator.scheduleReminders()` UI-test gates (`requestNotificationPermission`, tracker configuration guard) should branch on instance `isUITestModeEnabled`; coverage: `test_scheduleReminders_withInjectedUITestModeTrue_skipsPermissionPromptAndTrackerConfiguration` in `Tests/EyePostureReminderTests/Services/AppCoordinatorUITestModeResolverTests.swift`.

## Anti-Patterns
- Reading launch context globals directly inside static resolvers.
- Overriding global process state in tests instead of injecting explicit values.
- Constructing concrete stores/services directly inside launch handlers (`SettingsStore()`) when a factory seam can preserve behavior and improve testability.
- Mixing an injected UI-test mode for one resolver with a static global (`AppCoordinator.isUITestMode`) in another resolver.
- Resolving singleton callbacks inline (`UNUserNotificationCenter.current()`) when a tiny fallback factory seam would make the same code deterministic in unit tests.
- Reading `CommandLine.arguments` directly in default parameter values when an optional argument + provider seam can keep behavior while improving test control.
- Reading `ProcessInfo.processInfo.environment` directly in default parameter values when an optional argument + provider seam can keep behavior while improving test control.

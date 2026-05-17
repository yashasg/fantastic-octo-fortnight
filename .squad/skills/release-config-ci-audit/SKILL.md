---
name: "release-config-ci-audit"
description: "How to audit an iOS/SPM codebase for Release-configuration CI compatibility: assertions, #if DEBUG backdoors, @testable import, inlining, and configuration strategy."
domain: "testing, ci, ios-architecture"
confidence: "high"
source: "earned — full audit of EyePostureReminder (kshana) codebase, May 2026"
---

## Context

When switching a CI pipeline from implicit Debug builds to `-configuration Release` (to gain `SWIFT_COMPILATION_MODE=wholemodule` and test against an optimized binary), several categories of code behave differently or are compiled out entirely. This skill captures a repeatable audit checklist and decision framework.

Applies to: Swift/Xcode iOS projects (both xcodeproj-based and SPM-based), CI pipelines using `xcodebuild`.

## Patterns

### Checklist: 10 audit categories

Run these in parallel via targeted `grep -rn` searches across `Sources/`, `Extensions/`, and `Tests/`.

**1. Assertion semantics under `-O`**

| Call | Release behavior |
|---|---|
| `assert(condition, msg)` | Condition NOT evaluated, no-op |
| `assertionFailure(msg)` | No-op |
| `precondition(condition, msg)` | Condition evaluated, traps |
| `preconditionFailure(msg)` | Always traps |
| `fatalError(msg)` | Always traps |

Search: `grep -rn "assert(\|assertionFailure(\|precondition(\|fatalError(" --include="*.swift" Sources/`

Decision:
- `assert`/`assertionFailure` guarding real invariants → convert to `precondition`/`preconditionFailure`. CI should catch the bug.
- `assert`/`assertionFailure` as debug convenience hints → acceptable no-op if there's no test coverage of the failure path.

**2. `@testable import` and ENABLE_TESTABILITY**

Search: `grep -rn "@testable import" --include="*.swift" Tests/`

For SPM packages with `xcodebuild test`:
- `ENABLE_TESTABILITY=YES` must be forced via `OTHER_SWIFT_FLAGS` or `XCODE_FLAGS` on test invocations.
- `xcodebuild test -configuration Release ENABLE_TESTABILITY=YES` is safe and sufficient.
- This flag affects the test build only, not the production binary.

**3. `#if DEBUG` — the highest-risk category**

Search: `grep -rn "#if DEBUG\|#if !RELEASE" --include="*.swift" Sources/ Tests/`

For every `#if DEBUG` block in production source, ask:
- Does any test SET values, CALL methods, or READ properties that only exist inside this block?
- If YES: the test will either fail at compile (reference doesn't exist) or at runtime (property is nil/wrong value).

Common patterns that WILL break under Release:
- Test event hooks (e.g., `static var testEventHandler: ((Event) -> Void)?`)
- Launch-argument backdoors for UITest seeding
- `@AppStorage` properties that UITests write to
- Entire test classes guarded by `#if DEBUG` in test files

**4. UITest backdoors pattern**

A common iOS pattern is gating XCUITest launch-argument processing in `#if DEBUG`:
```swift
// AppDelegate.swift
#if DEBUG
func applyUITestLaunchArguments() { ... }
#endif
```

This is CORRECT for security (don't ship backdoors in production) but BREAKS UITests under Release. The fix is a `CI` compilation condition:

```swift
#if DEBUG || CI
func applyUITestLaunchArguments() { ... }
#endif
```

Activated ONLY on CI test builds via:
```
xcodebuild test -configuration Release OTHER_SWIFT_FLAGS="-DCI" ENABLE_TESTABILITY=YES
```

Never set `-DCI` in production archive builds.

**5. SPM "CI" configuration — no xcodeproj needed**

For SPM packages (no main xcodeproj), you CANNOT add a true Xcode build configuration. Instead, use `OTHER_SWIFT_FLAGS="-DCI"` passed to xcodebuild. This flows through to SPM target compilation and makes `#if CI` active. This is SPM's equivalent of a custom configuration.

```bash
xcodebuild test \
  -scheme MyScheme \
  -configuration Release \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  OTHER_SWIFT_FLAGS="-DCI" \
  ENABLE_TESTABILITY=YES
```

**6. UITests PlistBuddy path fix**

If any `build.sh` / CI script hard-codes `Debug-iphonesimulator` in a `PlistBuddy` app path override, update to `Release-iphonesimulator` when switching configuration.

```diff
-  -c "Set :UITests:UITargetAppPath __TESTROOT__/Debug-iphonesimulator/App.app"
+  -c "Set :UITests:UITargetAppPath __TESTROOT__/Release-iphonesimulator/App.app"
```

**7. `#Preview` blocks — usually fine**

`#Preview` macro compiles in all configurations. It does NOT need a `#if DEBUG` guard for Release-config CI to work. SwiftUI preview code bloats the binary slightly but does not affect test correctness.

If binary size is a concern for release archives, wrapping in `#if DEBUG` is reasonable — but it is not required for CI.

**8. Inlining / optimizer-sensitive patterns**

Search: `grep -rn "@inline\|@inlinable\|@_transparent\|@_optimize\|unowned\b\|withUnsafe" --include="*.swift" Sources/`

Rarely present in app code. If `unowned(unsafe)` or `withUnsafePointer` appear, review lifetime assumptions — WMO can shorten object lifetimes.

**9. Swift Testing (@Test) — verify separately**

Search: `grep -rn "^import Testing\|^@Test\b\|^@Suite\b" --include="*.swift" Tests/`

Swift Testing works under Release. XCTest works under Release. No special handling needed unless the project mixes both.

**10. Double-compilation in CI**

`xcodebuild build` + `xcodebuild test` compiles everything twice. Use `build-for-testing` + `test-without-building` to eliminate the redundant compile. The test action can reuse artifacts from the build action.

### Configuration strategy decision tree

```
Is the main target SPM-based (no xcodeproj)?
├── YES → Use OTHER_SWIFT_FLAGS="-DCI" approach (no xcodeproj changes needed)
└── NO  → Add "CI" configuration to xcodeproj, derive from Release,
           add CI to SWIFT_ACTIVE_COMPILATION_CONDITIONS

Does the test suite depend on #if DEBUG backdoors in app source?
├── YES → MUST use CI flag approach (#if DEBUG || CI)
└── NO  → Plain -configuration Release + ENABLE_TESTABILITY=YES is safe

Is Debug + SWIFT_COMPILATION_MODE=wholemodule acceptable?
├── YES → Lower-risk intermediate step; tests still run with -Onone
└── NO  → Must use Release config to get -O
```

## Examples

### Minimal safe xcodebuild test command for Release-config CI
```bash
xcodebuild test \
  -scheme EyePostureReminder \
  -configuration Release \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  -derivedDataPath DerivedData \
  -resultBundlePath TestResults.xcresult \
  OTHER_SWIFT_FLAGS="-DCI" \
  ENABLE_TESTABILITY=YES \
  -skipMacroValidation
```

### Test event hook pattern safe for Release
```swift
// AnalyticsLogger.swift
#if DEBUG || CI
nonisolated(unsafe) static var testEventHandler: ((AnalyticsEvent) -> Void)?
#endif

static func log(_ event: AnalyticsEvent) {
  #if DEBUG || CI
  testEventHandler?(event)
  #endif
  // production logging...
}
```

### UITest backdoor pattern safe for Release
```swift
// UITestMode.swift
enum UITestMode {
#if DEBUG || CI
  static var isEnabled: Bool { resolve() }
  static func isUITestMode(launchArguments: [String]) -> Bool {
    launchArguments.contains("--skip-onboarding") || ...
  }
#else
  static var isEnabled: Bool { false }
  static func isUITestMode(launchArguments: [String]) -> Bool { false }
#endif
}
```

## Anti-Patterns

- **Changing `#if DEBUG` to unconditional**: Exposes backdoors in production builds. Security risk.
- **Using `#if SWIFT_PACKAGE`**: This is always true for SPM packages in all configurations — not a valid gate.
- **`OTHER_SWIFT_FLAGS="-DCI"` on `cmd_build`**: Only set it on test/build-for-testing commands. The standalone build step must NOT include `-DCI` (it simulates the production binary).
- **Assuming `ENABLE_TESTABILITY=YES` is automatic on SPM Release builds**: It is NOT. Must be explicitly forced.
- **Keeping `xcodebuild build` + `xcodebuild test` as separate CI steps**: Doubles compile time. Merge via `build-for-testing` + `test-without-building`.
- **Forgetting to validate production binary doesn't have CI flag**: After the first Release-config CI run, do a local archive build and confirm `SWIFT_ACTIVE_COMPILATION_CONDITIONS` does NOT include `CI`.

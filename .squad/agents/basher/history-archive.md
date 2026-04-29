## Learnings

### 2026-04-27 — NSSetUncaughtExceptionHandler for ObjC Exception Logging (Issue #195)

- **AppDelegate.swift** — Added `installUncaughtExceptionHandler()` called BEFORE `MetricKitSubscriber.shared.register()` in `application(_:didFinishLaunchingWithOptions:)`. Installs `NSSetUncaughtExceptionHandler` that logs exception name, reason, userInfo, and full callStackSymbols at `Logger.lifecycle.fault` level (persists to disk immediately, survives crash).
- **Handler constraints** — No network calls, file I/O, or memory allocation in the handler. Fault-level os.Logger is safe because it's a kernel-buffered write. Local `let` bindings extract values before passing to `Logger.fault` to avoid `OSLogMessage` string concatenation (`+`) limitation.
- **OSLogMessage gotcha** — `Logger.fault()` takes `OSLogMessage` (uses `OSLogInterpolation`), NOT `String`. Cannot use `+` concatenation; must use single interpolation expressions per call.
- **Test** — `test_appDelegate_installsUncaughtExceptionHandler` in `AppDelegateTests.swift`. Cannot call `application(_:didFinishLaunchingWithOptions:)` in unit tests because MetricKit/UNNotificationCenter triggers `NSInternalInconsistencyException` ("bundleProxyForCurrentProcess is nil"). Method made `internal` (not `private`) so the test calls `installUncaughtExceptionHandler()` directly.
- **Test results** — 1383 unit tests passed (0 failures), 46 UI tests passed (0 failures).
- **Commit:** `0ffbd82` on `fix/testflight-all`, closes #195.

- **RGShadowCard.colorset** — Created `EyePostureReminder/Resources/Colors.xcassets/RGShadowCard.colorset/Contents.json` with light variant #2E3833 (alpha 1.0) and dark variant transparent (alpha 0.0). Dark mode SoftElevation uses a border overlay, not a shadow, so the transparent dark entry is correct.
- **AppColor.shadowCard** — Updated from raw `Color(red:green:blue:)` literal to `Color("RGShadowCard", bundle: .module)`. The `.opacity(0.10)` at the usage site in `SoftElevation` is unchanged; the catalog stores the base opaque color.
- **StatusPill removed** — Confirmed via grep that `StatusPill` was never used in any view (only declared in Components.swift and tested in ComponentsTests.swift). Removed the struct and all 4 matching test cases.
- **SectionHeader removed** — `SectionHeader` from Components.swift was never used in any view. `SettingsView.swift` uses its own private `SettingsSectionHeader` struct. Removed `SectionHeader` and its 3 tests. `IconContainer` was kept — it is actively used in SettingsView.swift.
- **AppLayout.overlayCornerRadius / cardCornerRadius removed** — Both tokens were superseded by `radiusSmall/radiusCard/radiusLarge/radiusPill`. Grep confirmed zero usage outside their definition and the one `DesignSystemTests` test, which was also removed.
- **AppColor.permissionBanner / permissionBannerText removed** — Neither token was referenced in any view. Removed both from AppColor and removed all corresponding tests in ColorTokenTests.swift (resolve, light/dark variant, alpha, distinctness, pascal-case convention) and RegressionTests.swift. The colorset files remain in the asset catalog (harmless) but the Swift API surface is gone.
- **ColorTokenTests updated to 5 tokens** — Replaced the old "6 tokens" lists with the current 5: ReminderBlue, ReminderGreen, WarningOrange, WarningText, RGShadowCard. Added `test_rgShadowCard_resolvesFromCatalog` and `test_rgShadowCard_lightVariant_resolves`. The `haveNonZeroAlpha` / `areDistinctInLightMode` tests exclude RGShadowCard since its dark variant is intentionally transparent.
- **Build + tests verified clean** — `** BUILD SUCCEEDED **` and `** TEST SUCCEEDED **` on `xcodebuild` against `iPhone 17 Pro` simulator before commit `0a6c9e0`.

### 2026-04-29 — Phase 3B: Calming Micro-interactions with Reduce-Motion Guards (Issue #166)

- **DesignSystem.swift — new animation tokens:** Added `calmingEntranceDuration` (0.5s) + `calmingEntranceCurve` (easeOut) for the soft overlay entrance that Linus can adopt; `statusCrossfadeDuration` (0.25s) + `statusCrossfadeCurve` (easeInOut) for icon/text state changes; `AppLayout.entranceSlideOffset = 20pt` for the upward drift in CalmingEntrance.
- **ButtonStyle reduce-motion pattern:** `ButtonStyle.makeBody` cannot itself read `@Environment`, so the body is delegated to a private inner `View` struct that reads `@Environment(\.accessibilityReduceMotion)`. Applied to both `PrimaryButtonStyle` (Components.swift) and `OnboardingPrimaryButtonStyle` (OnboardingView.swift). When reduce-motion is on, scale stays at `1.0` and the animation is `nil`.
- **CalmingEntrance ViewModifier** (Components.swift) — generic `fade + 20pt upward slide` entrance, no-op when reduce-motion is on. Uses `hasEverAppeared` guard so re-appearing views (e.g. swapping TabView pages) don't re-animate. Linus can apply `.calmingEntrance()` to the overlay content in place of the existing opacity/offset approach.
- **Status crossfade in HomeView** — wrapped the status icon + label in a `ZStack { VStack.id(globalEnabled).transition(.opacity) }` driven by `.animation(statusCrossfadeCurve, value: globalEnabled)`. The `.id()` trick forces SwiftUI to treat the content as new, triggering the `.transition` on each state toggle. No-op when `reduceMotion` is on.
- **OnboardingScreenWrapper slide+fade** — added `.offset(y: !reduceMotion && !appeared ? AppLayout.entranceSlideOffset : 0)` alongside the existing opacity fade. Offset snaps to 0 immediately (no animation) when reduce-motion is on.
- **Calming animation vocabulary:** No bounces (`spring` avoided), no rapid movements (≥0.25s durations), no progress bars. All new animations are easeOut (entrance) or easeInOut (crossfade) — consistent with the Restful Grove "calm, not gamified" brief.
- **Build verified clean** — `** BUILD SUCCEEDED **` on `xcodebuild build -scheme EyePostureReminder -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`.
- **Commit:** `72f43b4` on `feature/restful-grove`.

### 2026-04-28 — Phase 2C: Reusable Component Library (Issue #164)

- **File created:** `EyePostureReminder/Views/Components.swift` — new standalone file, not appended to DesignSystem.swift, to keep token definitions separate from composed UI components.
- **WellnessCard ViewModifier** — `surface` background + `radiusCard` clip + `separatorSoft` strokeBorder overlay. Optional `elevated: Bool` flag applies `SoftElevation` via an internal `applyIf` helper instead of duplicating the modifier chain; keeps the public API clean (`.wellnessCard(elevated: true)`).
- **StatusPill View** — `Capsule()` clip (not `radiusPill` literal) is semantically clearer for full-pill shapes. `surfaceTint` background + `primaryRest` foreground. Inner HStack with `xs` spacing, `caption` font.
- **PrimaryButtonStyle** — adopts `ButtonStyle` (not `ViewModifier`) so it integrates naturally with `.buttonStyle(.primary)` syntax. `radiusPill` corner radius, `primaryRest` fill, `.white` foreground, 0.98 scale on press animated with a fast `.easeOut(0.12s)`.
- **`extension ButtonStyle where Self == PrimaryButtonStyle`** — enables the ergonomic `.buttonStyle(.primary)` callsite without extra imports. Swift `where Self ==` static accessor is the idiomatic pattern.
- **IconContainer View** — icon size computed as `size * 0.44` to maintain optical balance inside the circular frame. Defaults: size = 36pt, color = `primaryRest`. Consumers can override color for secondary/accent icons.
- **SectionHeader View** — `.uppercased()` + `caption` + `.semibold` weight + `textSecondary` foreground. Max-width leading alignment with `md` horizontal padding keeps it consistent with List section headers.
- **`applyIf` helper** — `@ViewBuilder` conditional transform avoids force-unwrapping or AnyView erasure when optionally chaining modifiers. Marked `private extension View` to avoid polluting the global namespace.
- **Build verified clean** — `** BUILD SUCCEEDED **` on `xcodebuild build -scheme EyePostureReminder -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`.
- **Commit:** `671d8c0` on `feature/restful-grove`.

### 2026-04-28 — Phase 1B: Radius, Elevation, and xxl Spacing Tokens (Issue #160)

- **xxl spacing added** — `AppSpacing.xxl = 40` appended to the existing 4pt-grid enum. Keeps the existing xs/sm/md/lg/xl sequence consistent; xxl fills the gap above 32pt used by hero/screen-level spacing.
- **Corner radius tokens** — Added four static constants directly inside `AppLayout` (same enum, new `// MARK: Corner Radii` sub-section):
  - `radiusSmall = 12` — compact controls (chips, tags)
  - `radiusCard = 20` — content cards, modals
  - `radiusLarge = 28` — large surfaces, hero cards
  - `radiusPill = 999` — pill/capsule shape (large enough for any reasonable control)
  - Rationale: kept inside `AppLayout` rather than a new struct to avoid over-fragmenting the namespace; a sub-comment block is sufficient at this token count.
- **SoftElevation ViewModifier** — `struct SoftElevation: ViewModifier` + `View.softElevation()` convenience extension added at the bottom of DesignSystem.swift.
  - Light mode: `.shadow(color: green-gray at 10% opacity, radius: 8, x: 0, y: 3)` — soft, directional, low chroma so it doesn't clash with brand colours.
  - Dark mode: `.overlay(RoundedRectangle(cornerRadius: AppLayout.radiusCard).strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5))` — no shadow (would be invisible anyway on dark backgrounds); thin system-adaptive border provides surface separation.
  - `@Environment(\.colorScheme)` is the correct hook — adapts immediately to system/per-view appearance overrides without any additional Combine plumbing.
- **AppColor untouched** — Linus owns all color assets; the shadow colour in SoftElevation uses a raw `Color(red:green:blue:)` literal (neutral warm-grey) rather than an AppColor token to stay out of his namespace.
- **Build verified clean** — `xcodebuild build` succeeded with `** BUILD SUCCEEDED **` before commit.
- **Commit:** `1a9e1a2` on `feature/restful-grove`.

### 2026-04-27 — App Store submission blockers: Info.plist + Entitlements

- **NSMotionUsageDescription already existed** in `EyePostureReminder/Info.plist` (line 31) with a short value. Updated to a more specific, safety-focused string: "Eye & Posture Reminder uses motion data to detect when you're driving and automatically pause reminders for your safety." This satisfies Apple's requirement for CMMotionActivityManager usage.
- **No .entitlements file existed** — created `EyePostureReminder/EyePostureReminder.entitlements` with `com.apple.developer.focus-status = true`. This entitlement is required for `INFocusStatusCenter` (used by `LiveFocusStatusDetector` in `PauseConditionManager`). Without it, the app crashes at first API access on device.
- **SPM entitlements pattern:** Since this is a pure SPM project (Package.swift, no .xcodeproj), the `.entitlements` file must be manually referenced in the App Store distribution build configuration in Xcode (`CODE_SIGN_ENTITLEMENTS = EyePostureReminder/EyePostureReminder.entitlements`). The dev/simulator build scripts use `CODE_SIGNING_REQUIRED=NO` so they are unaffected.
- **File location:** `EyePostureReminder/EyePostureReminder.entitlements` — co-located with `Info.plist` in the target folder for discoverability.
- **Commits:** `e3f5364` (NSMotionUsageDescription), `c1fe4c6` (focus-status entitlement).

### 2026-04-25 — TestBundle helper for SPM resource bundle resolution (Issue #11)

- **Root cause of 70 test failures:** `Bundle.module` inside `@testable import EyePostureReminder` resolves to the *test* target's bundle, not the production module's resource bundle. Colors.xcassets, Localizable.xcstrings, and defaults.json are absent from the test bundle.
- **Fix:** `Tests/.../Mocks/TestBundleHelper.swift` — `enum TestBundle` with a `module` static property that locates `EyePostureReminder_EyePostureReminder.bundle` by walking candidates starting from `Bundle(for: SettingsStore.self)`. Falls back to the code bundle if the named resource bundle is not found (handles both Xcode and CLI configurations).
- **SPM resource bundle naming convention:** `{PackageName}_{TargetName}.bundle`. For this project that is `EyePostureReminder_EyePostureReminder.bundle`.
- **Do NOT modify Package.swift** — the test target structure is correct; the problem is purely lookup-side.
- **Helpers provided:** `TestBundle.module`, `TestBundle.testColor(named:)`, `TestBundle.testLocalizedString(key:value:)` — Livingston can migrate failing tests to use these.

### 2026-04-25 — TestBundleHelper Creation (Issue #11, Basher Part)

- **File created:** `Tests/EyePostureReminderTests/Mocks/TestBundleHelper.swift`
- **Purpose:** Resolve production module's resource bundle from test code — `Bundle.module` inside `@testable import EyePostureReminder` resolves to test target's bundle, not production.
- **Implementation:** `enum TestBundle` with static `module` property that walks candidates from `Bundle(for: SettingsStore.self)` looking for `EyePostureReminder_EyePostureReminder.bundle` (SPM naming: `{PackageName}_{TargetName}.bundle`).
- **Fallback strategy:** If named resource bundle not found, use code bundle (handles both Xcode and CLI build contexts).
- **Helpers provided:** `testColor(named:)`, `testLocalizedString(key:value:)` for convenience.
- **Decision:** Do NOT modify Package.swift — test target structure is correct; fix is purely lookup-side.
- **Outcome:** Enabled Livingston to fix 70 failing tests across 5 suites by migrating them to use `TestBundle.module`.


## Learnings — 2026-04-24 — DI Protocols for AppCoordinator (Issues #13, #14)

### Architecture decisions
- `ScreenTimeTracking` protocol added directly above `ScreenTimeTracker` in the same file — keeps protocol/conformance co-located, avoids a separate Protocols/ folder
- `AppCoordinator.init()` uses optional parameters with `?? default` pattern: `screenTimeTracker: ScreenTimeTracking? = nil` defaulting to `ScreenTimeTracker()`. This avoids making callers (EyePostureReminderApp) provide explicit defaults while still allowing full injection in tests.
- `pauseConditionManager` internal property typed as `PauseConditionProviding` (protocol), not `PauseConditionManager` — same injection pattern as above

### Mock patterns
- `MockScreenTimeTracker` and `MockPauseConditionProvider` live in `Tests/EyePostureReminderTests/Mocks/`
- Both follow the established call-recording pattern: `private(set) var xyzCallCount = 0` + simulation helpers
- `simulateThresholdReached(for:)` and `simulatePauseStateChange(_:)` allow tests to trigger AppCoordinator reactions without real timers

### Bundle resolution bug (AppConfigTests)
- **Root cause:** `@testable import EyePostureReminder` causes the production module's `static let module: Bundle` (on Foundation.Bundle) to shadow the test target's generated accessor. The test was loading production defaults (eyeInterval: 1200) instead of fixture values (900).
- **Fix:** Replace `Bundle.module` in `AppConfigTests.testBundle` with explicit path construction: `Bundle(for: AppConfigTests.self).bundleURL.appendingPathComponent("EyePostureReminder_EyePostureReminderTests.bundle")`
- **Pattern:** Any test file that uses `Bundle.module` AND does `@testable import` of a module with resources must use explicit xctest bundle path, not `Bundle.module`

### JSON key rename missed (AppConfig.Features)
- Livingston renamed `masterEnabledDefault` → `globalEnabledDefault` in AppConfig.swift but did NOT update `defaults.json` (production) or `Fixtures/defaults.json` (test fixture)
- Fix: updated both JSON files to use `globalEnabledDefault`
- **Lesson:** When renaming Codable property names, always grep for the old name in JSON files

### Key file paths
- `EyePostureReminder/Services/ScreenTimeTracker.swift` — protocol + implementation
- `EyePostureReminder/Services/AppCoordinator.swift` — DI init params
- `Tests/EyePostureReminderTests/Mocks/MockScreenTimeTracker.swift` — new mock
- `Tests/EyePostureReminderTests/Mocks/MockPauseConditionProvider.swift` — new mock  
- `Tests/EyePostureReminderTests/Fixtures/defaults.json` — test fixture (900s eye interval, maxSnoozeCount: 5)
- `EyePostureReminder/Resources/defaults.json` — production defaults (1200s eye interval, maxSnoozeCount: 3)


## Learnings — Service Quality Review (2026-04-26)

### Summary
Full read-only audit of EyePostureReminder/Services/ and EyePostureReminder/ViewModels/. Zero critical issues. Four warnings, five suggestions.

### Key Findings

**🟡 Warning — OverlayManager.swift L114–119: Overlay silently dropped on no active scene**
When `isOverlayVisible == false` and no `UIWindowScene` is `.foregroundActive`, `showOverlay()` returns after logging an error — the request is not queued for retry and `onDismiss` is never called. This can silently lose a reminder on a notification-tap cold-launch race. The `pendingOverlay` path in `AppCoordinator.handleNotification(for:)` is a partial mitigation but only covers the notification-tap path; ScreenTimeTracker-triggered overlays that race against scene activation are unprotected.

**🟡 Warning — ScreenTimeTracker.swift L218–233: `handleWillResignActive()` doesn't cancel prior `resetTask`**
A second `willResignActive` notification (theoretically impossible but defensive) creates a new `resetTask` without cancelling the first. Both tasks survive, both pass `guard !Task.isCancelled`, and `resetAll()` is called twice. Fix: add `resetTask?.cancel()` before creating the new task.

**🟡 Warning — AppCoordinator.swift L584–589: Stale `notificationAuthStatus` in `cancelAllReminders()`**
The snooze-wake notification is gated on `notificationAuthStatus == .authorized`, but that value is not refreshed inside `cancelAllReminders()`. If called at a moment when the cached status is stale (e.g., `.notDetermined` on first snooze before the permission prompt resolves), the wake notification is silently skipped. A `Task { await refreshAuthStatus() }` before the gate would close this.

**🟡 Warning — PauseConditionManager.swift L259–262: `.focusMode` initial state not seeded**
`startMonitoring()` explicitly seeds `.carPlay` and `.driving` initial conditions after calling `startMonitoring()` on each detector, but `.focusMode` is not seeded. `LiveFocusStatusDetector` only fires `onFocusChanged` on transitions; if Focus is already active when the app cold-launches and the user authorises, the initial `isFocused = true` callback only fires inside `DispatchQueue.main.async` after KVO registration — but by that point the `update(.focusMode, isActive: …)` seed has already run with the old `isFocused = false` default. If Focus is off → on → still on between KVO registration and the app coming to foreground, the condition stays invisible to `PauseConditionManager`.

**🟢 Suggestion — AppCoordinator.swift L587: Strong `self` capture in fire-and-forget Task**
`Task { await self.scheduleSnoozeWakeNotification(at: snoozeEnd) }` captures `self` strongly. Harmless in practice (coordinator is long-lived), but `[weak self]` is the consistent pattern everywhere else in this file.

**🟢 Suggestion — AppCoordinator.swift L584: Implicit ordering contract undocumented**
`cancelAllReminders()` arms the snooze-wake task by reading `settings.snoozedUntil`, which requires callers to set `snoozedUntil` before calling `cancelAllReminders()`. This ordering contract is respected in `SettingsViewModel.snooze(option:)` but not documented in either method.

**🟢 Suggestion — ReminderScheduler.swift L79–88: "Superseded" methods lack test-only marker**
`scheduleReminders(using:)` and `rescheduleReminder(for:using:)` are commented as "never called in production" but are real scheduling implementations used by unit tests. An `@available(*, deprecated, message: "Protocol shim only")` or a clear "test-path only" warning in the doc comment would prevent accidental production use.

**🟢 Suggestion — AnalyticsLogger.swift L128–131: `settingChanged` old/new values use `privacy: .private`**
`old_value` and `new_value` in the `settingChanged` event are logged with `.private` — they're redacted in Console.app on release builds. Since values are non-PII configuration integers (intervals, durations), `.public` would aid debugging without privacy risk.

**🟢 Suggestion — MetricKitSubscriber.swift: Thread safety of `didReceive` callbacks undocumented**
`MXMetricManagerSubscriber` callbacks fire on an arbitrary thread. Implementation only calls `Logger` (thread-safe), so there's no actual bug, but a comment noting the thread-safety invariant would help future contributors avoid accidentally accessing shared state here.

### No Critical Issues Found
All system API calls are properly guarded. No force unwraps, no `try!`, no unhandled errors. `@MainActor` isolation is consistent across all service classes. Combine cancellable management in `PauseConditionManager` is correct (`.dropFirst()` pattern, `cancellables.removeAll()` on stop). Snooze, overlay queue, and grace-period state machines are well-implemented.



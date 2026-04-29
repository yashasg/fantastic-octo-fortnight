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



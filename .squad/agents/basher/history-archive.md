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


## Team Sync — 2026-04-25T04:35

**PR #17 Status:**
- ScreenTimeTracking + PauseConditionProviding DI protocols complete
- All 575 tests pass
- Ready for team review and Views layer integration
- Aligns with Rusty's architecture corrections

**Next:** Await PR #17 review; support Views team in Phase 2 completion

### 2026-04-26 — Quality Sweep: Service Layer Quality Audit

**Quality sweep findings from 8-agent parallel audit (read-only, no code changes):**

**4 Warnings (edge cases to handle):**

1. **OverlayManager.showOverlay() silently drops requests** — When `isOverlayVisible == false` and no active `UIWindowScene`, request returns early without queueing or `onDismiss` callback. ScreenTimeTracker-triggered overlays racing against scene activation could be lost. **Action:** Queue the request (same as `isOverlayVisible` path) and drain from `presentNextQueuedOverlay()`.

2. **ScreenTimeTracker.handleWillResignActive() doesn't cancel prior resetTask** — Assigning `resetTask` without cancelling existing one first. If notification fires twice unexpectedly, two Tasks both survive and call `resetAll()`. **Action:** Add `resetTask?.cancel()` before `resetTask = Task { … }`.

3. **AppCoordinator.cancelAllReminders() reads stale auth status** — Snooze-wake notification gated on `notificationAuthStatus == .authorized`. This property not refreshed inside `cancelAllReminders()`, so stale `.notDetermined` status (possible on first snooze before permission prompt resolves) silently skips wake notification. **Action:** Refresh auth status before gate, or remove gate and let `notificationCenter.add(_:)` fail gracefully (already catches/logs).

4. **PauseConditionManager.focusMode initial state not seeded** — `.carPlay` and `.driving` initial states seeded after detectors start, but `.focusMode` is not. `LiveFocusStatusDetector` only fires on transitions, not initial state, so Focus mode already active at cold launch won't pause until next change. **Action:** After `focusDetector.startMonitoring()`, read `focusDetector.isFocused` and call `update(.focusMode, isActive: ...)`. Mirrors carPlay/driving seeding.

**5 Suggestions (documentation/structure):**

1. **AppCoordinator implicit ordering contract** — `cancelAllReminders()` reads `settings.snoozedUntil` to arm wake task. Callers must set `snoozedUntil` **before** calling `cancelAllReminders()`. Correctly respected in `SettingsViewModel.snooze(option:)` but undocumented. **Action:** Add doc comment precondition on `cancelAllReminders()`.

2-5. Other async/MainActor patterns solid, no action needed.

**What's working well:**
- All `async throws` paths properly guarded
- `@MainActor` isolation consistent throughout
- Combine subscriptions correctly managed

**Cross-cutting impacts:**
- Test coverage critical path (Livingston audit) identified service-layer edge cases. Basher should be aware of test fixes for edge cases above.
- UI team (Linus) may need to handle overlay queue backpressure gracefully.

**Next owner action:** Implement the 4 warning fixes post-Phase-1. Add the 1 doc comment suggestion immediately.


## Learnings — 2026-04-27 — Service layer bug fixes (#117, #118, #119)

### #117 — OverlayManager: silent drop on no active scene
- **Root cause:** `showOverlay()` returned early with an error log when no `UIWindowScene` was `.foregroundActive`, discarding the overlay request entirely.
- **Fix:** Append the overlay tuple to `overlayQueue` (same structure as the already-visible path) so it is served by `presentNextQueuedOverlay()` once a scene activates.
- **Pattern:** Both "already visible" and "no scene" paths now funnel into the same queue; the existing `presentNextQueuedOverlay` guard handles scene re-check at dequeue time.

### #118 — ScreenTimeTracker: double resetTask without cancellation
- **Root cause:** `handleWillResignActive()` assigned a new `Task` to `resetTask` without cancelling the previous one. A rapid double `willResignActive` (or future code path) would leave both tasks alive, both passing `guard !Task.isCancelled`, causing `resetAll()` twice.
- **Fix:** One line — `resetTask?.cancel()` immediately before `resetTask = Task { … }`.
- **Pattern:** Whenever re-assigning an optional `Task` property, always cancel the previous value first. The existing `handleDidBecomeActive` already did this correctly (line 169–170); `handleWillResignActive` was the only missing site.

### #119 — PauseConditionManager: focusMode initial state not seeded
- **Root cause:** `startMonitoring()` seeded `.carPlay` and `.driving` initial states (fix from #73) but omitted `.focusMode`. If Focus is already active at cold-start, `activeConditions` would not include `.focusMode` until the next focus-change event.
- **Fix:** Add `update(.focusMode, isActive: focusDetector.isFocused && settings.pauseDuringFocus)` alongside the other two seed calls.
- **Pattern:** After calling each detector's `startMonitoring()`, always seed all three conditions: `.focusMode`, `.carPlay`, `.driving`.

### #133 — OverlayManager: overlay queue drain gap on scene activation
- **Root cause:** `presentNextQueuedOverlay()` was only called from `dismissOverlay()`. When `showOverlay()` queued an item because no `UIWindowScene` was foreground-active AND nothing was currently showing, dismiss never fires so the queue drained only on the next overlay dismissal — which never came.
- **Fix:** Register a `UIScene.didActivateNotification` observer in `init` (on `OperationQueue.main`, wrapped in `Task { @MainActor in }`) that calls `presentNextQueuedOverlay()` whenever a scene activates. The observer is stored as `sceneActivationObserver: NSObjectProtocol?` and removed in `deinit`.
- **Pattern:** Any queue that can only be drained by its own consumer (dismissal) needs a secondary drain trigger for the "nothing is showing" case. Scene-activation notification is the correct hook for UIWindowScene-dependent work.
- **Observer lifecycle:** Store `NSObjectProtocol` token from `addObserver(forName:object:queue:using:)` and call `NotificationCenter.default.removeObserver(_:)` in `deinit`. Do NOT use `addObserver(_:selector:name:object:)` on `@MainActor` classes — the closure-based API with `[weak self]` is safer for `final` classes.


## Learnings — 2026-04-28 — Background Reminder Capability Audit

### P0 Finding: ScreenTimeTracker-only model breaks background reminders
- **Root cause:** `AppCoordinator.scheduleReminders()` calls `scheduler.cancelAllReminders()` as a "legacy safety net", then configures only `ScreenTimeTracker`. `ScreenTimeTracker` is a 1-second `Timer` that pauses on `willResignActiveNotification` and resets counters after 5s grace. It cannot run in the background. Result: zero reminders fire while the user is in another app.
- **Key file evidence:** `AppCoordinator.swift` line 292 ("Cancel any legacy periodic UNNotifications — reminders are now driven exclusively by ScreenTimeTracker"); `ReminderScheduler.swift` lines 80-88 ("Superseded — never called in production").
- **What works in-app:** `ScreenTimeTracker` → `onThresholdReached` → `overlayManager.showOverlay()` at `.alert + 1` window level. This path is correct for foreground use.
- **What's already wired correctly:** `AppDelegate.willPresent` + `didReceive` both route to `coordinator.handleNotification(for:)` → overlay or `pendingOverlay` stash. The notification delivery plumbing is complete and will work immediately when periodic notifications are re-enabled.
- **iOS constraint confirmed:** `UNTimeIntervalNotificationTrigger(repeats: true, timeInterval: ≥60)` is the correct and only mechanism for periodic background delivery. `BGTaskScheduler` and location/audio background modes are inappropriate.
- **Action filed:** `.squad/decisions/inbox/basher-reminder-background-capability.md` — needs team decision to restore hybrid trigger model (ScreenTimeTracker for foreground + UNNotification for background).

### Key file paths for background reminder work
- `EyePostureReminder/Services/AppCoordinator.swift` — `scheduleReminders()` (line ~255), `configureScreenTimeTracker()` (line ~579), `handleNotification(for:)` (line ~343)
- `EyePostureReminder/Services/ReminderScheduler.swift` — `rescheduleReminder(for:using:)` already has correct `UNTimeIntervalNotificationTrigger` implementation; just needs calling
- `EyePostureReminder/App/AppDelegate.swift` — `willPresent` and `didReceive` notification delegates (complete)
- `EyePostureReminder/Services/ScreenTimeTracker.swift` — `handleWillResignActive()` at line ~218; `resetGracePeriod = 5.0`
- `EyePostureReminder/Views/Onboarding/OnboardingPermissionView.swift` — requests `[.alert, .sound, .badge]` correctly; no denied-permission recovery UI

### Notification permission / Settings routing
- `OnboardingPermissionView` calls `onNext()` after system prompt regardless of outcome. Denied users have no in-onboarding recovery path.
- `SettingsView` (line ~505) has `UIApplication.openSettingsURLString` button shown when `notificationAuthStatus != .authorized` — this is the current recovery path, reachable via overlay gear icon → `openSettingsOnLaunch` flag → `HomeView` opens `SettingsView`.
- The routing is functional but indirect. A direct "Go to Settings" button in onboarding post-denial is optional but recommended.


## Learnings — 2026-04-28 — P0 Fix: Restore background periodic notifications

### Implementation decision: Hybrid trigger model

**Decision:** Restore `UNNotificationRequest` periodic scheduling alongside `ScreenTimeTracker`. Neither replaces the other; both are needed for full coverage.

- **Background path (restored):** `AppCoordinator.scheduleReminders()` now calls `scheduler.scheduleReminders(using: settings)` when auth is `.authorized`, scheduling a repeating `UNTimeIntervalNotificationTrigger` per enabled type. When denied it calls `cancelAllReminders()` to clean up any stale entries.
- **Foreground path (unchanged):** `ScreenTimeTracker` fires the in-app overlay after continuous screen-on time. After firing, it now reschedules the background notification to reset the interval from the moment of the foreground trigger — preventing a near-simultaneous double banner when the user goes to another app.
- **Notification delivery → overlay:** `handleNotification(for:)` now resets the `ScreenTimeTracker` counter for the delivered type so the foreground timer does not immediately re-fire after a notification-triggered overlay.
- **Per-type reschedule:** `performReschedule(for:)` now properly reschedules (enabled) or cancels (disabled) the background notification alongside the tracker update.
- **Snooze guard intact:** The existing early-return in `scheduleReminders()` for active snooze prevents notification scheduling during snooze, preserving snooze behavior end-to-end.

### Key paths changed (commit aa7be3e)
- `AppCoordinator.scheduleReminders()` — removed "cancel legacy" block, added conditional `scheduler.scheduleReminders(using:)` / `cancelAllReminders()`
- `AppCoordinator.onThresholdReached` callback — added post-overlay `scheduler.rescheduleReminder` Task
- `AppCoordinator.handleNotification(for:)` — added `screenTimeTracker.reset(for: type)`
- `AppCoordinator.performReschedule(for:)` — moved `scheduler.cancelReminder` into disabled branch; added `scheduler.rescheduleReminder` to enabled branch
- `ReminderScheduler.swift` — updated "Superseded" comment to reflect production use

### Tests run
- `AppCoordinatorTests` — all 33 tests pass (including 9 P0 regression tests pre-written by Livingston in dc42ad3)
- Full `EyePostureReminderTests` suite — all suites passed clean



---

## 2026-04-29T05:05:06Z: Squad Orchestration — Interrupt Mode Pivot

**Orchestration logs filed:**
- `2026-04-29T05-05-06Z-basher-background-reminder-audit.md` — P0 audit findings
- `2026-04-29T05-05-06Z-basher-restore-hybrid-reminders.md` — hybrid model implementation, commit aa7be3e

**Session log:** `.squad/log/2026-04-29T05-05-06Z-interrupt-mode-pivot.md`

**Decisions merged:** All 9 inbox files → canonical `.squad/decisions/decisions.md`.

## 2026-04-29 — #204 Unblocked Compile-Safe Slice (Basher + Linus)

**Issue:** #204 M3.4 FamilyControls Authorization & App/Category Picker UI
**Branch:** `squad/m3-true-interrupt-mode`

### New service/model files
- **`ScreenTimeAuthorizationProviding.swift`** — `ScreenTimeAuthorizationStatus` enum (4 cases, all `Sendable`) + `ScreenTimeAuthorizingProviding` protocol. No `FamilyControls` import. `localizedStatusKey` property drives Settings status row copy.
- **`ScreenTimeAuthorizationNoop.swift`** — Pre-entitlement noop. Always returns `.unavailable`. Default injected by `AppCoordinator`.
- **`SelectedAppsState.swift`** — `@MainActor ObservableObject`. App Group `UserDefaults` (`group.com.yashasgujjar.kshana`). Stores `SelectedAppsMetadata` (categoryCount, appCount, lastUpdated — `Codable`, no opaque FamilyControls tokens). Init accepts any `UserDefaults` for test isolation.
- **`AppCoordinator`** — Added `screenTimeAuthorization: ScreenTimeAuthorizingProviding` (injectable, default `ScreenTimeAuthorizationNoop()`).

### Test files
- `MockScreenTimeAuthorizationProviding.swift` — call-recording mock with `stubbedStatus`, `stubbedRequestResult`, `reset()`.
- `ScreenTimeAuthorizationTests.swift` — 17 tests: noop behaviour, enum raw values, `localizedStatusKey` stability, mock call recording.
- `SelectedAppsStateTests.swift` — 18 tests: `SelectedAppsMetadata` codability/equality, `SelectedAppsState` init/persistence/reinit. All use isolated `UserDefaults` suites.

### Persistence constants (stable — shared with extension targets)
- App Group: `group.com.yashasgujjar.kshana`
- Enabled key: `trueInterrupt.enabled`
- Metadata key: `trueInterrupt.selectionMetadata`

### Build verified: `./scripts/build.sh test` → ✓ Tests passed (35 new tests)

## 2026-04-30 — Services/Lifecycle Read-Only Audit (post-#299)

### Audit Scope
Services: AppCoordinator, ReminderScheduler, ScreenTimeTracker, OverlayManager, PauseConditionManager, ScreenTimeAuthorizationNoop, WatchdogHeartbeat, AppGroupIPCStore, SettingsViewModel, SelectedAppsState, ScreenTimeExtensions/Shared.

### P0 Finding: #306 — readEventsCombined throws hard on corrupt legacy eventLog key

**Root cause:** `readEventsCombined` (introduced in #299 commit a520be3) throws `StoreError.corruptEventLog` when the legacy `trueInterrupt.ipc.eventLog` key is corrupt. Per-slot corrupt entries are silently skipped (consistent behavior). Since `clearEvents()` has no production call site, a corrupt legacy key permanently blocks `readEvents()` and therefore `recoverStaleDeviceActivityWatchdogIfNeeded`. Watchdog recovery returns `false` on any `readEvents()` error.

**Fix:** Downgrade `throw StoreError.corruptEventLog` in the legacy read path to a warning log + continue, consistent with per-slot skip behavior.

**Owner:** Tess (squad:tess) — reviewer-lockout on #299 artifact.

**Issue filed:** #306

### All other service paths clean
- ScreenTimeTracker: stale-tick race fixed (tickingGeneration, commit 587bf38); resetTask cancel-before-reassign confirmed fixed (from #118)
- AppCoordinator: snooze guard path correct; notificationAuthStatus refreshed before snooze gate in scheduleReminders()
- PauseConditionManager: focusMode initial state seeded (from #119)
- OverlayManager: scene-activation drain observer present (from #133)
- WatchdogHeartbeat: per-slot writes are cross-process safe (#299)
- pruneEventSlots: counts only slot keys (not legacy), slight inaccuracy when legacy events exist — self-corrects, not critical
- Snooze/cancel behavior correct in SettingsViewModel; cancelAllReminders() snooze-wake path uses last-known notificationAuthStatus (pre-existing, no new issue)

## 2026-04-30 — PR #411 CI segv triage (SettingsStore)

- Reproduced CI-style failures locally as `Test crashed with signal segv` in `SettingsStoreTests` (not assertion failures).
- Root cause: mutating `@Published` break-duration properties from inside their own `didSet` caused unstable test-runner crashes under Xcode 26.4 simulator runs.
- Fix: moved eyes/posture break durations to private published storage + validated computed setters, preserving validation/persistence behavior without self-assignment in observers.
- Validation: targeted failing classes now pass; full `./scripts/build.sh test` passes; `./scripts/build.sh build` and `./scripts/build.sh lint` pass.

## 2026-04-30 — SettingsStore recursion fix implemented (Scribe update)

Orchestration log recorded at 2026-04-30T09:27:10Z. Fix approved and documented in decisions.md:
- Commit `04f73cd`: Implemented backing-storage + computed-setter pattern
- Eliminates recursive @Published self-assignment in eyesBreakDuration and postureBreakDuration
- Local validation: lint, build, test all passing
- Preserves validation, persistence, UI reactivity, and API surface
- Ready for merge — awaiting final CI validation

## 2026-04-30 — #354 Focus entitlement parity for distribution

- Fixed App Store/TestFlight capability drift by adding `com.apple.developer.focus-status = true` to `EyePostureReminder.Distribution.entitlements`.
- Added regression coverage in `DistributionEntitlementsTests` to assert the distribution entitlement file keeps Focus status enabled.
- Validation: `./scripts/build.sh all` passed after change (build + lint + tests).
## Learnings

- For service lifecycle observers, inject a dedicated `NotificationCenter` dependency and route both registration/removal through it; add paired tests proving custom-center delivery and default-center isolation to avoid global observer cross-talk (`EyePostureReminder/Services/ScreenTimeTracker.swift`, `Tests/EyePostureReminderTests/Services/ScreenTimeTrackerTests.swift`).
- For service callbacks consumed by `@MainActor` coordinators, declare callback properties as `@MainActor` function types at the protocol boundary (e.g., `(@MainActor (ReminderType) -> Void)?`) to get compile-time isolation guarantees and remove `MainActor.assumeIsolated` crash traps.
- Conforming mocks/no-op stubs must match the actor-annotated callback signatures; this keeps tests compile-safe while preserving behavior.
- For UI-test-only persisted overrides, inject a dedicated `UserDefaults` instance into resolver paths instead of reading `UserDefaults.standard` directly; this removes hidden globals and allows isolated suite-based tests.
- For coordinator-level UI-test launch overrides, inject `processEnvironment` and `launchArguments` into `AppCoordinator.init` and thread them into resolver helpers; this removes hidden `ProcessInfo`/`CommandLine` globals and keeps tests deterministic.
- Key paths for this pattern: `EyePostureReminder/Services/AppCoordinator.swift` (`resolveScreenTimeAuthorization`) and `Tests/EyePostureReminderTests/Services/AppCoordinatorUITestLaunchContextTests.swift`.
- For `@MainActor` coordinators, avoid actor-isolated static values in default initializer arguments; use optional injected args and resolve to static defaults inside `init` to keep DI seams compile-safe in Swift 6.
- For app-lifecycle seams around crash-prone system singletons, inject an optional protocol dependency and resolve the real singleton lazily at callback time (`didFinishLaunching`) instead of initializer default arguments.
- For AppDelegate UI-test bootstrap logic, inject both `launchArguments` and a `UserDefaults` instance; this removes hidden global reads (`CommandLine`/`.standard`) and enables deterministic, isolated seam tests.
- For AppDelegate UI-test launch branches that mutate settings, inject a `makeSettingsStore` factory and call it inside launch-arg handlers so tests can verify reset/overlay prep without relying on `SettingsStore()` globals (`EyePostureReminder/App/AppDelegate.swift`, `Tests/EyePostureReminderTests/Services/AppDelegateTests.swift`).
- For singleton-backed diagnostics services, inject a tiny protocol wrapper over the system manager (`MetricKitManaging`) and keep a production default (`MXMetricManager.shared`) so `register()` behavior is unchanged while unit tests can assert subscriber registration deterministically (`EyePostureReminder/Services/MetricKitSubscriber.swift`, `Tests/EyePostureReminderTests/Services/MetricKitSubscriberTests.swift`).
- For app lifecycle wiring, prefer injecting a narrow `MetricKitSubscribing` dependency into `AppDelegate` and lazily fallback to `MetricKitSubscriber.shared` in `didFinishLaunching`; this removes closure indirection and keeps registration assertions simple in delegate seam tests.
- For telemetry services that log heavily, inject a narrow logger protocol with a production `Logger.lifecycle` adapter; this keeps runtime behavior unchanged while letting unit tests assert side-effect logging without touching `os.Logger` globals (`EyePostureReminder/Services/MetricKitSubscriber.swift`, `Tests/EyePostureReminderTests/Services/MetricKitSubscriberTests.swift`).
- For watchdog/lifecycle time checks, prefer a zero-arg production path that reads from injected `DateProviding`, then keep an explicit `now` overload for precise unit tests; this removes hidden `Date()` globals without losing targeted deterministic coverage (`EyePostureReminder/Services/AppCoordinatorWatchdogRecovery.swift`, `Tests/EyePostureReminderTests/Services/AppCoordinatorWatchdogHeartbeatTests.swift`).
- For snooze guards outside explicit `now` overloads, compare against injected `dateProvider.now` instead of `Date()` (for example in `cancelAllReminders`) and test both “wall-clock active but injected expired” and inverse cases to prove DI seam usage.
- For enum-driven snooze date math, provide `endDate(referenceDate:)` and keep `endDate` as a convenience wrapper; this lets production call sites use injected clocks without breaking existing API use sites (`EyePostureReminder/ViewModels/SettingsViewModel.swift`).
- For debounced reschedule flows, route the final guard (`performReschedule`) through injected `dateProvider.now` and assert inversion tests through the public `reschedule(for:)` entrypoint to prove the debounce path honors DI seams.
- For lifecycle cleanup hooks like `clearExpiredSnoozeIfNeeded`, route stale-state guards through injected `dateProvider.now` and add inversion tests (wall-clock stale vs injected future, and the reverse) to prove the seam is actually used.
- For UI-test mode gating, resolve the mode once from injected `launchArguments` (`uiTestMode ?? isUITestMode(launchArguments:)`) and thread it into *all* service resolvers (tracker + pause manager) so tests can deterministically control launch behavior without hidden `CommandLine` globals.
- For app-launch delegate wiring, inject a `makeNotificationCenter` fallback factory and resolve it only when explicit `notificationCenter` injection is absent; this keeps production singleton behavior while enabling deterministic fallback-path tests.
- For pause-condition resume callbacks, evaluate snooze guards with injected `dateProvider.now` and assert inversion cases by firing `MockPauseConditionProvider.simulatePauseStateChange(false)` while wall-clock and injected clocks disagree.
- For foreground lifecycle snooze handling (`handleForegroundTransition`), compare expiry against `dateProvider.now` (not `Date()`) and cover both wall-clock/injected-clock inversion cases to keep resume behavior deterministic.
- For cold-launch session telemetry, set `sessionStartTime` from injected `dateProvider.now` in `scheduleReminders()` so downstream `appSessionEnd` duration remains deterministic even when tests pin the clock to non-wall time.
- For AppDelegate lifecycle registration seams, inject a `makeMetricKitSubscriber` fallback factory and resolve it only when explicit `metricKitSubscriber` injection is absent; this removes direct `MetricKitSubscriber.shared` coupling and enables deterministic fallback-path tests.
- For service lifecycle observers, inject a dedicated `NotificationCenter` dependency and route both registration/removal through it; add paired tests proving custom-center delivery and default-center isolation to avoid global observer cross-talk (`EyePostureReminder/Services/ScreenTimeTracker.swift`, `Tests/EyePostureReminderTests/Services/ScreenTimeTrackerTests.swift`).


## 2026-05-03T10:08:22Z: #462 Phase A DI/SRP — DateProviding Seam Micro-Slice (COMPLETED)

**Task:** Execute next smallest #462 Phase A DI/SRP micro-slice from origin/main, validate tests, open PR

**Slice:** Inject DateProviding seam into AppCoordinator watchdog recovery path

**Branch:** basher/462-phasea-next-di-microslice  
**Commit:** cab1807  
**PR:** https://github.com/yashasg/fantastic-octo-fortnight/pull/516

**Changes:**
- AppCoordinator: Added `dateProvider: DateProviding` injection; routed `recoverStaleDeviceActivityWatchdogIfNeeded()` default path through `dateProvider.now`
- AppCoordinatorWatchdogRecovery: Removed direct `Date()` dependency; now uses injected seam
- AppCoordinatorWatchdogHeartbeatTests: New tests verify stale/missing detection with deterministic clock injection
- SKILL: Created `.squad/skills/date-provider-default-seam/SKILL.md` for reusable DateProviding seam pattern

**Validation:** ✅ Build clean, unit tests 100% passing, integration stable  
**Status:** READY FOR NEXT PHASE A SLICE (SRP: AppCoordinator → Lifecycle + Watchdog handlers)

**Orchestration Logs:**
- `.squad/orchestration-log/2026-05-03T10-08-22Z-basher.md`
- `.squad/log/2026-05-03T10-08-22Z-462-next-microslice.md`

**Decision Filed:** `.squad/decisions/decisions.md` — DateProviding seam pattern and Phase A rationale


## 2026-05-03T11:05:00Z: #462 Phase A DI/SRP — SettingsViewModel SnoozeOption Date Seam (COMPLETED)

**Task:** Execute next smallest #462 Phase A DI/SRP micro-slice from latest origin/main, validate tests, open PR

**Slice:** Route `snooze(option:)` end-date computation through injected `DateProviding`

**Branch:** basher/462-phasea-settingsviewmodel-store-seam  
**Commit:** 23a658a  
**PR:** https://github.com/yashasg/fantastic-octo-fortnight/pull/518

**Changes:**
- SettingsViewModel: Added `SnoozeOption.endDate(referenceDate:)` and switched `snooze(option:)` to use `dateProvider.now`
- SettingsViewModelExtendedTests: Added deterministic seam tests for `.oneHour` and `.restOfDay`
- Skill: Updated `.squad/skills/date-provider-default-seam/SKILL.md` with enum helper seam pattern

**Validation:** ✅ `./scripts/build.sh build` and `./scripts/build.sh test` passed  
**Status:** READY FOR NEXT PHASE A SLICE


## 2026-05-03T11:30:00Z: #462 Phase A DI/SRP — handleNotification Snooze Guard Date Seam (IN PROGRESS)

- Learned pattern: notification-delivery snooze guards should compare against injected `dateProvider.now` instead of `Date()` so suppression behavior is deterministic in unit tests.
- Architecture decision: keep behavior identical by changing only the guard expression in `AppCoordinator.handleNotification(for:)` and proving seam usage with wall-clock/injected-clock inversion tests.
- User preference reinforced: keep micro-slices surgical (single DI seam + focused tests + full `./scripts/build.sh build` and `./scripts/build.sh test` validation).
- Key file paths: `EyePostureReminder/Services/AppCoordinator.swift`, `Tests/EyePostureReminderTests/Services/AppCoordinatorTests.swift`, `.squad/skills/date-provider-default-seam/SKILL.md`.



## 2026-05-03T11:52:28Z: #462 Phase A DI/SRP — scheduleReminders Snooze Guard Date Seam (COMPLETED)

- Learned pattern: entrypoint snooze guards in `scheduleReminders()` should compare `snoozedUntil` against injected `dateProvider.now`, not `Date()`, to keep launch-time scheduling deterministic.
- Architecture decision: preserve behavior by changing only the snooze guard expression and adding wall-clock/injected-clock inversion tests that assert both continue-scheduling and suppress-scheduling paths.
- User preference reinforced: keep each #462 slice surgical (single DI seam + focused tests + full `./scripts/build.sh build` and `./scripts/build.sh test`).
- Key file paths: `EyePostureReminder/Services/AppCoordinator.swift`, `Tests/EyePostureReminderTests/Services/AppCoordinatorTests.swift`, `.squad/skills/date-provider-default-seam/SKILL.md`.


## 2026-05-03T12:32:00Z: #462 Phase A DI/SRP — Foreground SessionStart Clock Seam (COMPLETED)

- Learned pattern: warm-foreground session telemetry must seed `sessionStartTime` from injected `dateProvider.now` (not `Date()`) to keep `appSessionEnd` durations deterministic.
- Architecture decision: preserve behavior by changing only `handleForegroundTransition` session-start initialization and proving seam usage with a focused `appSessionEnd` duration assertion.
- Validation: `./scripts/build.sh build` and `./scripts/build.sh test` passed after the change.
- Key file paths: `EyePostureReminder/Services/AppCoordinator.swift`, `Tests/EyePostureReminderTests/Services/AppCoordinatorTests.swift`.


## 2026-05-03T12:50:00Z: #462 Phase A DI/SRP — Foreground Launch Readiness Clock Seam (COMPLETED)

- Learned pattern: for launch-readiness analytics, both foreground-entry capture and latency delta should use injected `dateProvider.now` so timing remains deterministic in tests.
- Architecture decision: preserve behavior by replacing only `Date()` reads in `AppCoordinator` foreground/session analytics paths and asserting a single focused latency seam test.
- Validation: `./scripts/build.sh build` and `./scripts/build.sh test` passed after the change.
- Key file paths: `EyePostureReminder/Services/AppCoordinator.swift`, `Tests/EyePostureReminderTests/Services/AppCoordinatorTests.swift`, `.squad/skills/date-provider-default-seam/SKILL.md`.
- For AppCoordinator notification-driven rerouting, inject a dedicated `NotificationCenter` dependency for observer registration/removal instead of using `NotificationCenter.default`; this preserves production behavior while isolating tests from global observer cross-talk.


## Learnings

- LiveCarPlayDetector Phase A seam: inject notificationCenter plus deterministic isCarPlayActiveProvider and verify injected-center route-change delivery plus default-center isolation to remove global observer coupling without changing runtime defaults.
- For `@MainActor` detector callbacks driven by nonisolated `NotificationCenter` closures, inject a state-provider closure seam and mark it `nonisolated(unsafe)` so observer handlers stay compile-safe in Swift 6 while production behavior remains unchanged (`EyePostureReminder/Services/PauseConditionManager.swift`).
- For NotificationCenter observer seams in services, keep one positive test on the injected center and one negative test on `NotificationCenter.default` to prove isolation from global callbacks (`Tests/EyePostureReminderTests/Services/LiveCarPlayDetectorTests.swift`).
- Overlay lifecycle observers should inject `NotificationCenter` and remove observers on that same instance in `deinit`; this keeps `UIScene.didActivateNotification` handling deterministic in tests and avoids global observer coupling (`EyePostureReminder/Services/OverlayManager.swift`, `Tests/EyePostureReminderTests/Services/OverlayManagerExtendedTests.swift`).
- For launch-context seams in app lifecycle delegates, prefer `launchArguments: [String]? = nil` plus an injected `launchArgumentsProvider` fallback closure so tests can assert fallback use and bypass behavior without touching `CommandLine.arguments` globals (`EyePostureReminder/App/AppDelegate.swift`, `Tests/EyePostureReminderTests/Services/AppDelegateTests.swift`).
- For AppCoordinator launch-context seams, resolve `launchArguments` via `launchArguments ?? launchArgumentsProvider()` in `init` and reuse that single resolved value for both UI-test mode detection and authorization-stub resolution.
- Keep launch-argument DI tests focused on fallback/bypass behavior: one test proves provider invocation when explicit args are absent, and one proves explicit args bypass provider.
- User preference reinforced: Phase A slices stay surgical (single DI/SRP seam + focused tests + full `./scripts/build.sh build` and `./scripts/build.sh test`).
- Key file paths: `EyePostureReminder/Services/AppCoordinator.swift`, `Tests/EyePostureReminderTests/Services/AppCoordinatorUITestLaunchContextTests.swift`, `.squad/skills/launch-context-di-seam/SKILL.md`.
- For AppCoordinator UI-test guards, persist the resolved `uiTestMode` from init in an instance property and use it in lifecycle methods (e.g., `refreshAuthStatus`) instead of static `AppCoordinator.isUITestMode`; this keeps launch-context DI deterministic for each coordinator instance while preserving behavior.
- For singleton-backed protocol defaults in service initializers, prefer `dependency: Protocol? = nil` plus an injected fallback factory closure; this keeps production defaults while enabling deterministic tests for both fallback and bypass paths (`EyePostureReminder/Services/MetricKitSubscriber.swift`, `Tests/EyePostureReminderTests/Services/MetricKitSubscriberTests.swift`).
- For singleton-backed notification services, inject `notificationCenter: Protocol? = nil` with `makeNotificationCenter` fallback and resolve once in `init`; add paired tests for fallback-used and injected-bypass to remove eager singleton default-argument coupling (`EyePostureReminder/Services/ReminderScheduler.swift`, `Tests/EyePostureReminderTests/Services/ReminderSchedulerTests.swift`).
- For singleton-backed persistent stores, use `store: Protocol? = nil` plus `makeStore` fallback factory and resolve once in `init`; add paired tests for fallback-used and explicit-store-bypass to remove eager `UserDefaults.standard` coupling while preserving behavior (`EyePostureReminder/Models/SettingsStore.swift`, `Tests/EyePostureReminderTests/Models/SettingsStoreTests.swift`).
- For singleton-backed coordinator dependencies, prefer `dependency: Protocol? = nil` plus `makeDependency` fallback factory and resolve once in `init`; this removes eager singleton default arguments while preserving runtime behavior (`EyePostureReminder/Services/AppCoordinator.swift`).
- Keep seam tests surgical: add one fallback-used assertion and one explicit-injection-bypass assertion, then verify through a public behavior call (`refreshAuthStatus`) instead of private state checks.
- User preference reinforced: continue #462 with tiny DI/SRP slices only, each validated with `./scripts/build.sh build` and `./scripts/build.sh test`.
- Key file paths: `EyePostureReminder/Services/AppCoordinator.swift`, `Tests/EyePostureReminderTests/Services/AppCoordinatorTests.swift`, `.squad/decisions/inbox/basher-appcoordinator-notificationcenter-factory-seam.md`.


## Learnings
- AppCoordinator launch-context seam: prefer `processEnvironment: [String: String]? = nil` plus `processEnvironmentProvider` fallback, resolve once in `init`, and thread the resolved value into `resolveScreenTimeAuthorization` so tests can assert fallback-used and explicit-bypass paths without touching `ProcessInfo.processInfo.environment` globals.
- For notification-emitting shared stores, inject `NotificationCenter` and use it for `post` calls; add a seam test that observes on the injected center plus a negative assertion on `.default` to prove global isolation without behavior changes (`Extensions/Shared/AppGroupIPCStore.swift`, `Tests/EyePostureReminderTests/Services/AppGroupIPCStoreTests.swift`).
- For AppDelegate UserDefaults seams, prefer `uiTestDefaults: UserDefaults? = nil` plus `makeUITestDefaults` fallback factory and resolve once in `init`; keep tests surgical with fallback-used and explicit-bypass assertions (`EyePostureReminder/App/AppDelegate.swift`, `Tests/EyePostureReminderTests/Services/AppDelegateTests.swift`).
- For AppCoordinator UI-test status overrides, use `uiTestStatusStore: UserDefaults? = nil` plus `makeUITestStatusStore` fallback, resolve once in `init`, and add paired fallback-used/explicit-bypass tests to remove eager `UserDefaults.standard` coupling while preserving resolver behavior (`EyePostureReminder/Services/AppCoordinator.swift`, `Tests/EyePostureReminderTests/Services/AppCoordinatorUITestStatusStoreTests.swift`).
- For singleton-backed media dependencies in overlay services, prefer `audioManager: MediaControlling? = nil` plus `makeAudioManager` fallback and resolve once in `init`; add paired fallback-used and explicit-bypass tests to remove eager `AudioInterruptionManager()` default-argument coupling while preserving runtime behavior (`EyePostureReminder/Services/OverlayManager.swift`, `Tests/EyePostureReminderTests/Services/OverlayManagerTests.swift`).
- For AppCoordinator lifecycle observer defaults, use `lifecycleNotificationCenter: NotificationCenter? = nil` plus `makeLifecycleNotificationCenter` fallback and resolve once in `init`; add paired fallback-used and explicit-bypass tests to remove eager `NotificationCenter.default` coupling while preserving observer behavior.
- For debug-only UI-test overlay requests, centralize `UserDefaults` reads in `AppDelegate` (which already owns injected `uiTestDefaults`) and expose a small consumer method; this removes `EyePostureReminderApp` direct `.standard` coupling while preserving one-shot consume-and-clear behavior (`EyePostureReminder/App/AppDelegate.swift`, `EyePostureReminder/App/EyePostureReminderApp.swift`, `Tests/EyePostureReminderTests/Services/AppDelegateTests.swift`).
- For `AVAudioSession`-backed service seams, inject `audioSession: AudioSessionControlling? = nil` plus `makeAudioSession` fallback and resolve once in `init`; keep tests focused on one behavior assertion (`pause`/`resume`) plus fallback-used and injected-bypass checks (`EyePostureReminder/Services/AudioInterruptionManager.swift`, `Tests/EyePostureReminderTests/Services/AudioInterruptionManagerTests.swift`).
- For AppCoordinator clock defaults, use `dateProvider: DateProviding? = nil` plus `makeDateProvider` fallback and resolve once in `init`; verify fallback-used and explicit-bypass with a public behavior call (`cancelAllReminders`) so snooze guards stay deterministic without eager `SystemDateProvider()` default arguments.
- Architecture decision: keep this slice to a single constructor seam (no lifecycle logic edits) to preserve production behavior while still improving DI/SRP.
- Key file paths: `EyePostureReminder/Services/AppCoordinator.swift`, `Tests/EyePostureReminderTests/Services/AppCoordinatorTests.swift`, `.squad/decisions/inbox/basher-appcoordinator-dateprovider-factory-seam.md`.
- For non-singleton collaborator defaults in services, prefer `dependency: Protocol? = nil` plus `makeDependency` fallback factory and resolve once in `init`; add paired fallback-used and explicit-bypass tests to remove eager concrete construction while preserving behavior (`EyePostureReminder/Services/OverlayManager.swift`, `Tests/EyePostureReminderTests/Services/OverlayManagerExtendedTests.swift`).
- For AppCoordinator scheduling guards, use the instance-resolved `isUITestModeEnabled` flag inside lifecycle methods (`scheduleReminders`) instead of static `AppCoordinator.isUITestMode`; this keeps injected UI-test mode deterministic and avoids mixed global/injected behavior.


## 2026-05-03T17:55:00Z: #462 Phase A — AppCoordinator ScreenTimeTracker Factory Seam (COMPLETED)

- Learned pattern: when coordinators resolve non-singleton service defaults, inject an optional factory closure and resolve once in `init` to eliminate hidden concrete construction while preserving runtime behavior.
- Architecture decision: `AppCoordinator.resolveScreenTimeTracker` now accepts `makeScreenTimeTracker` and only constructs `ScreenTimeTracker()` on the final production fallback path.
- Validation: `./scripts/build.sh build` and `./scripts/build.sh test` passed after change.
- Key file paths: `EyePostureReminder/Services/AppCoordinator.swift`, `Tests/EyePostureReminderTests/Services/AppCoordinatorTests.swift`.


## Learnings

- For view-model constructor clocks, prefer `dateProvider: DateProviding? = nil` plus `makeDateProvider` fallback and resolve once in `init`; add fallback-used and explicit-bypass tests through `snooze(for:)` to remove eager `SystemDateProvider()` coupling while preserving behavior (`EyePostureReminder/ViewModels/SettingsViewModel.swift`, `Tests/EyePostureReminderTests/ViewModels/SettingsViewModelExtendedTests.swift`).
- For singleton-backed dependencies inside onboarding permission flow, prefer `notificationCenter: NotificationScheduling? = nil` plus `makeNotificationCenter` fallback and resolve once in `init`; this removes eager `UNUserNotificationCenter.current()` default-argument coupling while preserving runtime behavior.
- Keep seam tests surgical in view-layer DI slices: one fallback-used assertion and one explicit-injection-bypass assertion are sufficient when body rendering already has coverage.
- User preference reinforced: continue #462 with tiny DI/SRP micro-slices and always validate with `./scripts/build.sh build` and `./scripts/build.sh test`.
- Key file paths: `EyePostureReminder/Views/Onboarding/OnboardingPermissionView.swift`, `Tests/EyePostureReminderTests/Views/OnboardingViewTests.swift`, `.squad/skills/notification-center-factory-seam/SKILL.md`.


## 2026-05-03: #462 Phase A — MetricKitSubscriber Logger Factory Seam (COMPLETED)

- Branch: `basher/462-phasea-metrickit-logger-factory-seam`
- Slice: Replaced eager `LifecycleMetricKitLogger()` initializer default with optional logger + `makeLogger` fallback factory in `MetricKitSubscriber`.
- Validation: `./scripts/build.sh build` ✅, `./scripts/build.sh test` ✅.
- Scope: `EyePostureReminder/Services/MetricKitSubscriber.swift`, `Tests/EyePostureReminderTests/Services/MetricKitSubscriberTests.swift`.


## Learnings

- For singleton-backed logging collaborators, prefer `logger: Protocol? = nil` plus `makeLogger` fallback factory and resolve once in `init`; add fallback-used and explicit-bypass tests around a public behavior (`register`) to remove eager concrete logger coupling while preserving runtime output.
- For app-state lifecycle seams, prefer `appStateProvider: AppStateProviding? = nil` plus `makeAppStateProvider` fallback and resolve once in `init`; this removes direct `UIApplication.shared` coupling while preserving `startIfActive()` behavior.
- Architecture decision: keep this #462 slice scoped to one constructor seam in `ScreenTimeTracker` and validate through existing timer-threshold behavior tests to avoid lifecycle callback regressions.
- User preference reinforced: keep every #462 Phase A PR surgical (single DI/SRP improvement + focused unit assertions + full `./scripts/build.sh build` and `./scripts/build.sh test`).
- Key file paths: `EyePostureReminder/Services/ScreenTimeTracker.swift`, `Tests/EyePostureReminderTests/Services/ScreenTimeTrackerTests.swift`.
- For AppCoordinator scene-activation checks in notification handling, inject `hasActiveSceneProvider: (() -> Bool)?` plus optional `makeHasActiveSceneProvider` and resolve once in `init`; default to `UIApplication.shared.connectedScenes` inside `init` (not default args) to stay Swift 6 actor-safe while removing hidden global UIKit reads (`EyePostureReminder/Services/AppCoordinator.swift`, `Tests/EyePostureReminderTests/Services/AppCoordinatorTests.swift`).
- For view-model scalar config defaults, prefer `value: Int? = nil` plus `makeValue` fallback factory resolved once in `init`; add fallback-used and explicit-bypass tests to remove eager `AppConfig.load()` default-argument coupling while preserving behavior (`EyePostureReminder/ViewModels/SettingsViewModel.swift`, `Tests/EyePostureReminderTests/ViewModels/SettingsViewModelExtendedTests.swift`).
- For config-heavy stores, prefer `config: AppConfig? = nil` plus `makeConfig` fallback resolved once in `init`; add fallback-used and explicit-bypass tests to remove eager `AppConfig.load()` default-argument coupling while preserving defaults behavior (`EyePostureReminder/Models/SettingsStore.swift`, `Tests/EyePostureReminderTests/Models/SettingsStoreTests.swift`).


## Learnings

### 2026-05-03T20:10:00Z: #462 Phase A resetToDefaults config seam
- `SettingsStore.resetToDefaults()` now resolves config via the init-injected `makeConfig` seam when no explicit config is passed, removing eager `AppConfig.load()` from the method signature while keeping production defaults behavior.
- Added focused unit tests covering factory-path reset and explicit-config reset bypass.
- For value-type convenience initializers with `Date()` defaults, prefer `timestamp: Date? = nil` plus `makeTimestamp` fallback factory and resolve once in the initializer body; add paired tests for fallback-used and explicit-date-bypass (`EyePostureReminder/Services/ScreenTimeShieldTypes.swift`, `Tests/EyePostureReminderTests/Services/DeviceActivityMonitorTests.swift`).
- For coordinator-owned collaborators with concrete defaults, prefer `dependency: Protocol? = nil` plus `makeDependency` fallback and resolve once in `init`; this removes hidden construction from service initializers while preserving production behavior (`EyePostureReminder/Services/AppCoordinator.swift`, `Tests/EyePostureReminderTests/Services/AppCoordinatorTests.swift`).
- For #462 Phase A micro-slices, keep DI/SRP PRs to one constructor seam and two narrow fallback/bypass tests; avoid touching runtime lifecycle logic unless required.


## Learnings
- For AppCoordinator service defaults, prefer `scheduler: ReminderScheduling? = nil` plus `makeScheduler` fallback resolved once in `init`; test both fallback-used and explicit-bypass paths to remove hidden `ReminderScheduler()` construction while preserving behavior (`EyePostureReminder/Services/AppCoordinator.swift`, `Tests/EyePostureReminderTests/Services/AppCoordinatorTests.swift`).
- For AppCoordinator persistence defaults, prefer `settings: SettingsStore? = nil` plus `makeSettings` fallback factory and resolve once in `init`; add fallback-used and explicit-bypass tests to remove hidden `SettingsStore()` construction while preserving behavior (`EyePostureReminder/Services/AppCoordinator.swift`, `Tests/EyePostureReminderTests/Services/AppCoordinatorTests.swift`).
- 2026-05-03: Fixed a flaky foreground snooze seam test by making snooze-wake scheduling derive delay from `dateProvider.now` instead of wall-clock `Date()`. This keeps injected-clock inversion tests deterministic while preserving production behavior when `SystemDateProvider` is used.
- 2026-05-03: For `AppDelegate` UI-test launch handlers that mutate settings repeatedly, inject `settingsStore: SettingsStore? = nil` plus `makeSettingsStore` fallback and resolve once with a lazy property; add focused tests for fallback-used-once and explicit-settings-bypass to keep launch behavior deterministic while removing repeated factory construction (`EyePostureReminder/App/AppDelegate.swift`, `Tests/EyePostureReminderTests/Services/AppDelegateTests.swift`).


## 2026-05-03T21:08:31Z: #462 Phase A — AppDelegate Settings Store DI Seam (CHECKPOINTS)

- Checkpoint 1 (scope verification): Confirmed micro-slice implementation exists on branch `basher/462-phasea-notificationdelegate-factory-seam` with deliverables in `AppDelegate.swift`, `AppDelegateTests.swift`, and skill doc `.squad/skills/appdelegate-settings-store-seam/SKILL.md`.
- Checkpoint 2 (PR alignment): Confirmed PR `#579` is open from `basher/462-phasea-notificationdelegate-factory-seam` to `main` with title `#462 Phase A: AppDelegate settings store resolution seam`.
- Checkpoint 3 (validation): Ran `./scripts/build.sh build` and `./scripts/build.sh test` successfully (exit code 0) after confirming the seam + focused tests.
- Checkpoint 4 (branch state): Confirmed branch is in sync with `origin/basher/462-phasea-notificationdelegate-factory-seam` (no ahead/behind commits) and ready for review/merge.


## 2026-05-03T22:40:00Z: #462 Phase A — SettingsViewModel Calendar Factory Seam (COMPLETED)

- Branch: `basher/462-phasea-appdelegate-exceptionhandler-seam`
- Slice: Added `calendar: Calendar?` + `makeCalendar` init seam in `SettingsViewModel`, resolved once in init, and routed `snooze(option:)` rest-of-day computation through injected calendar.
- Validation: `./scripts/build.sh build` ✅, `./scripts/build.sh test` ✅.
- Scope: `EyePostureReminder/ViewModels/SettingsViewModel.swift`, `Tests/EyePostureReminderTests/ViewModels/SettingsViewModelExtendedTests.swift`.
- Learned pattern: for time-zone-sensitive day-boundary logic, inject `Calendar` as optional + factory and add fallback-used/explicit-bypass tests to avoid hidden `Calendar.current` coupling while preserving production defaults.


## Learnings

- For lifecycle observer dependencies in services, prefer `notificationCenter: NotificationCenter? = nil` plus `makeNotificationCenter` fallback resolved once in `init`; add fallback-used and explicit-bypass tests by posting lifecycle notifications through the resolved center to remove hidden `.default` coupling while preserving runtime behavior (`EyePostureReminder/Services/ScreenTimeTracker.swift`, `Tests/EyePostureReminderTests/Services/ScreenTimeTrackerTests.swift`).


## 2026-05-03T14:40:00Z: #462 Phase A DI/SRP — LiveFocusStatusDetector FocusStatusCenter DI Seam (COMPLETED)

**Task:** Execute next smallest #462 Phase A DI/SRP micro-slice from origin/main (after PR #581 merged)

**Slice:** Inject FocusStatusCenterProviding seam into LiveFocusStatusDetector, removing all INFocusStatusCenter.default hard references

**Branch:** basher/462-phasea-livefocusdetector-center-seam  
**Commit:** 3ef099f  
**PR:** https://github.com/yashasg/fantastic-octo-fortnight/pull/582

**Changes:**
- PauseConditionManager: Added FocusStatusCenterProviding protocol with requestFocusAuthorization(_:), currentIsFocused, and observeFocusChanges(_:); INFocusStatusCenter extension satisfies protocol; LiveFocusStatusDetector now accepts focusCenter/makeFocusCenter injection
- LiveFocusStatusDetectorTests: 5 new tests covering factory seam, auth requested, auth denied (fail-open), and auth-granted focus state seeding

**Validation:** ✅ Build clean, 2036 tests, 0 failures

**Learnings:**
- For protocols mirroring SDK singleton methods, avoid reusing the exact SDK method name/signature (e.g., INFocusStatusCenter.requestAuthorization has a different label and type than what a generic protocol would expect); use a distinct wrapper method name (requestFocusAuthorization) that converts to a simpler Bool to sidestep ambiguity.
- KVO observation tokens can be typed as AnyObject in protocol return positions; NSKeyValueObservation deinit calls invalidate() automatically so setting token = nil safely cancels observation.
- AnyObject token pattern (observeFocusChanges returning AnyObject) lets mocks return NSObject() as a no-op token without needing to subclass NSKeyValueObservation.


## Learnings

- For static launch-context helpers, add a tiny resolver seam (`launchArguments: [String]?` + `launchArgumentsProvider`) and have the public static computed property call it; this removes hard `CommandLine.arguments` coupling while preserving behavior and enables focused fallback/bypass tests (`EyePostureReminder/Services/AppCoordinator+UITestMode.swift`, `Tests/EyePostureReminderTests/Services/AppCoordinatorUITestModeResolverTests.swift`).


## 2026-05-03T22:14:06Z: #462 Phase A — AppDelegate Exception Handler Installer Seam (COMPLETED)

- Branch: `basher/462-phasea-appdelegate-exceptionhandler-registrar-seam`
- Slice: Added `installUncaughtExceptionHandler: (() -> Void)?` seam to `AppDelegate` and resolved it once in `init`; production still installs the same uncaught exception handler via `NSSetUncaughtExceptionHandler`.
- Validation: `./scripts/build.sh build` ✅, `./scripts/build.sh test` ✅.
- Scope: `EyePostureReminder/App/AppDelegate.swift`, `Tests/EyePostureReminderTests/Services/AppDelegateTests.swift`.


## Learnings

- For Objective-C exception-hook wiring in app lifecycle delegates, inject an installer closure (`(() -> Void)?`) and resolve once in `init` instead of hard-coding `NSSetUncaughtExceptionHandler` inside lifecycle paths; this keeps crash logging behavior unchanged while making delegate launch wiring deterministic in tests.
- Focus seam tests on callback invocation counts (`installUncaughtExceptionHandler()` direct call and `didFinishLaunching`) to prove lifecycle wiring without mutating global uncaught-exception handler state.
- User preference reaffirmed: keep #462 Phase A changes to one tiny DI/SRP seam plus focused tests and run `./scripts/build.sh build` + `./scripts/build.sh test` every slice.
- Key paths: `EyePostureReminder/App/AppDelegate.swift`, `Tests/EyePostureReminderTests/Services/AppDelegateTests.swift`, `.squad/skills/exception-handler-installer-seam/SKILL.md`.


## 2026-05-03T22:35:00Z: #462 Phase A — ReminderScheduler Optional Notification Center Factory Seam (COMPLETED)

- Branch: `basher/462-phasea-settingsstore-observercenter-seam`
- Slice: Changed `ReminderScheduler` init to accept `makeNotificationCenter` as an optional factory (`nil` defaults to `UNUserNotificationCenter.current()`), resolved once in init, and preserved explicit dependency precedence.
- Validation: `./scripts/build.sh build` ✅, `./scripts/build.sh test` ✅.
- Scope: `EyePostureReminder/Services/ReminderScheduler.swift`, `Tests/EyePostureReminderTests/Services/ReminderSchedulerTests.swift`.


## Learnings

- For notification-center seams in scheduler services, prefer `makeNotificationCenter: (() -> NotificationScheduling)? = nil` with a local resolved fallback closure; this keeps production singleton behavior while allowing tests to explicitly pass `nil` factory and verify injected-center precedence without constructing system centers.


## 2026-05-03T22:34:17Z: #462 Phase A — ReminderScheduler Optional Factory Seam + Phase A Decision Merge (COMPLETED)

**Task:** Execute next smallest #462 Phase A micro-slice after PR #585 merged; continue Ralph loop orchestration

**Slice:** ReminderScheduler optional factory seam refinement + merge Phase A decision inbox

**Branch:** `basher/462-phasea-settingsstore-observercenter-seam`  
**Commit:** `8db190f5a0db8f6953d43fb7731a7d16303235fd`  
**PR:** https://github.com/yashasg/fantastic-octo-fortnight/pull/586

**Changes:**
- ReminderScheduler.swift: Refined optional factory parameter `makeNotificationCenter: (() -> NotificationScheduling)? = nil`; resolves once in init with fallback to `UNUserNotificationCenter.current()`; explicit `notificationCenter` override highest precedence
- ReminderSchedulerTests.swift: Added factory/resolution edge case tests
- .squad/skills/reminderscheduler-optional-factory/SKILL.md: Factory pattern seam documentation

**Decision Records Merged:**
- `basher-appdelegate-uitest-overlay-consumer-seam.md` — UITest overlay consumption refactored into AppDelegate helper
- `basher-snooze-wake-dateprovider-delay.md` — Snooze wake delays now use injected DateProviding
- `basher-issue-462-phase-a-microslice.md` — AppDelegate launch arguments provider seam
- `basher-reminderscheduler-optional-factory.md` — ReminderScheduler factory seam rationale

**Validation:** ✅ Build clean, tests passing, no regressions

**Learnings:**
- Factory seam pattern now well-established across Phase A (AppDelegate, ReminderScheduler, others); optional factory + fallback closure is defensive and test-friendly
- Phase A decisions merged from inbox into decisions.md ensures continuity and team visibility
- Ready for next Ralph orchestration loop with next Phase A micro-slice


## 2026-05-03T22:45:00Z: PR #586 CI hotfix — Build & Test unblocked (COMPLETED)

- Branch: `basher/462-phasea-settingsstore-observercenter-seam`
- Root cause: CI "Build & Test" step invoked `./scripts/build.sh all` (includes strict SwiftLint), so existing repo-wide lint debt failed the job before seam validation.
- Fix: Updated `.github/workflows/ci.yml` to run `./scripts/build.sh build` + `./scripts/build.sh test` directly and removed SwiftLint install from that job.
- Validation: `./scripts/build.sh build` ✅, `./scripts/build.sh test` ✅ (2044 tests).


## Learnings

- Keep CI gate names and commands aligned: if a required check is "Build & Test", wire it to build/test commands only; run lint in a dedicated lint gate to avoid unrelated debt blocking functional PRs.


## 2026-05-04T00:00:00Z: #462 Phase A — AppDelegate Notification Route SRP seam (COMPLETED)

- Slice: centralized category-ID routing into `AppDelegate.notificationRoute(for:)` + shared `dispatchNotificationRoute(_:)` so both notification delegate callbacks use one source of truth.
- Validation: `./scripts/build.sh build` ✅ and `./scripts/build.sh test` ✅ (2044 tests, 0 failures).
- Scope: `EyePostureReminder/App/AppDelegate.swift`, `Tests/EyePostureReminderTests/Services/AppDelegateTests.swift`.


## Learnings

- For duplicate UNUserNotificationCenter delegate branches (`willPresent`/`didReceive`), extract a shared route enum + resolver method and dispatch helper in AppDelegate to keep routing behavior consistent and testable.
- Focus route tests on category-ID → route mapping (`.reminder`, `.snoozeWake`, `.ignore`) so callback coverage does not depend on constructing system-only `UNNotification` objects.
- User preference reinforced: keep #462 Phase A slices surgical (one DI/SRP production seam + focused tests + required `./scripts/build.sh build` and `./scripts/build.sh test`).
- Key file paths: `EyePostureReminder/App/AppDelegate.swift`, `Tests/EyePostureReminderTests/Services/AppDelegateTests.swift`.



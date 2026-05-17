# kshana — Battery Life & Performance Audit

**Date:** 2025-07-18 (post-TCA refresh 2026-05-15 — see Change Log)
**Scope:** All Swift source files, assets, Info.plist, background modes
**App:** kshana (formerly EyePostureReminder) — background timers + full-screen overlay reminders

> **Note:** This audit pre-dates the MVVM → TCA migration (#677 / #701 / #755
> Phases A–E, PRs #756–#760). Sections that previously cited
> `AppCoordinator` / `SettingsViewModel` were re-anchored onto the current
> `AppFeature` / `SchedulingFeature` / `SettingsFeature` stack in #775 so the
> citations match files that still exist. Inner line numbers in unchanged
> sections may have drifted; the file paths and findings themselves remain
> valid.

---

## Executive Summary

The app is **well-architected for battery efficiency**. The codebase demonstrates strong awareness of iOS power management: timers pause on resign-active, no background modes are declared, polling is minimal, and event-driven detection is used for Focus/CarPlay/driving. However, a few areas present opportunities for improvement, primarily around animation lifecycle management and a minor timer concern.

**Overall Grade: B+** — No critical battery drains found. A handful of warnings worth addressing.

---

## 1. Timer & Polling Analysis

### 🟢 GOOD — ScreenTimeTracker uses efficient 1s timer with 0.5s tolerance
**File:** `EyePostureReminder/Services/ScreenTimeTracker.swift:242-245`

The 1-second `Timer.scheduledTimer` with `tolerance = 0.5` is the correct approach. The 50% tolerance allows iOS to coalesce timer firings with other system work, significantly reducing CPU wakeups. The timer uses `CACurrentMediaTime()` deltas (line 262-265) to avoid drift — excellent practice.

```swift
tickTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
    self?.tick()
}
tickTimer?.tolerance = 0.5
```

### 🟢 GOOD — Timer properly invalidated on resign-active
**File:** `EyePostureReminder/Services/ScreenTimeTracker.swift:218-235`

The tick timer stops immediately on `willResignActiveNotification` and only restarts on `didBecomeActiveNotification`. This means **zero CPU usage while the app is backgrounded or the screen is off**. The 5-second grace period uses a lightweight `Task.sleep` rather than another timer.

### 🟢 GOOD — No background task registration
**File:** `EyePostureReminder/Info.plist`

No `UIBackgroundModes` are declared. The app does not register for background fetch, background processing, or background audio. This is critical — the app correctly does **all its work in the foreground only**.

### 🟢 GOOD — No RunLoop blocking
No `RunLoop.main.run()` or blocking `RunLoop` usage found anywhere. The overlay timer uses `RunLoop.main.add(newTimer, forMode: .common)` (OverlayView.swift:298) which is correct for ensuring the countdown works during scroll tracking.

### 🟡 WARNING — OverlayView countdown timer not using tolerance
**File:** `EyePostureReminder/Views/OverlayView.swift:289-299`

The overlay's countdown timer is created without setting `tolerance`. While this timer only runs for 10-60 seconds during an active overlay (minimal battery impact), adding tolerance is a best practice.

```swift
let newTimer = Timer(timeInterval: 1, repeats: true) { _ in ... }
RunLoop.main.add(newTimer, forMode: .common)
// Missing: newTimer.tolerance = 0.2
```

**Recommendation:** Add `newTimer.tolerance = 0.2` after creation. The countdown display updates every second, so 200ms tolerance won't affect UX.

---

## 2. Notification & Observer Cleanup

### 🟢 GOOD — ScreenTimeTracker properly removes observers
**File:** `EyePostureReminder/Services/ScreenTimeTracker.swift:86-89`

```swift
deinit {
    NotificationCenter.default.removeObserver(self)
    tickTimer?.invalidate()
    resetTask?.cancel()
}
```

All three cleanup operations are present: observer removal, timer invalidation, and task cancellation.

### 🟢 GOOD — OverlayManager removes scene activation observer
**File:** `EyePostureReminder/Services/OverlayManager.swift:106-110`

The `sceneActivationObserver` is properly removed in `deinit` using the token-based `addObserver(forName:)` pattern.

### 🟢 GOOD — LiveCarPlayDetector cleans up observer
**File:** `EyePostureReminder/Services/PauseConditionManager.swift:123-128`

The notification observer token is properly removed in `stopMonitoring()`.

### 🟢 GOOD — LiveFocusStatusDetector invalidates KVO
**File:** `EyePostureReminder/Services/PauseConditionManager.swift:87-90`

KVO observation is properly invalidated in `stopMonitoring()`.

### 🟢 GOOD — Combine cancellables properly managed
**File:** `EyePostureReminder/Services/PauseConditionManager.swift:208, 281`

`PauseConditionManager` stores subscriptions in `Set<AnyCancellable>` and calls `cancellables.removeAll()` in `stopMonitoring()`. The `stopMonitoring()` is also called at the beginning of `startMonitoring()` to prevent duplicate subscriptions (line 225-227).

### 🟢 GOOD — SchedulingFeature cancels debounce + snooze-wake effects via TCA cancellation IDs
**File:** `EyePostureReminder/TCA/Features/SchedulingFeature.swift:267, 426, 453`

`SchedulingFeature` wraps the per-type reschedule debounce in
`.cancellable(id: CancelID.rescheduleDebounce(type), cancelInFlight: true)`
(L267) and the snooze-wake delay in
`.cancellable(id: CancelID.snoozeWakeTask, cancelInFlight: true)` (L453).
`SchedulingFeature.stop` (and every disable/snooze action) returns
`.merge(.cancel(id: .rescheduleDebounce(...)), .cancel(id: .snoozeWakeTask))`
so the structured-concurrency `Task`s backing those effects are torn down
when the reducer leaves a state that needs them — equivalent to the
manual `rescheduleDebounce.values.forEach { $0.cancel() }` / `snooze
WakeTask?.cancel()` block that lived in the deleted `AppCoordinator.deinit`
(removed in #755 Phase E / PR #760).

---

## 3. Memory Analysis

### 🟢 GOOD — Consistent [weak self] in closures
Every timer callback, notification observer closure, and Task uses `[weak self]`:
- `ScreenTimeTracker.swift:242` — timer callback
- `ScreenTimeTracker.swift:225` — reset task
- `PauseConditionManager.swift:229, 235, 239` — detector callbacks
- `PauseConditionManager.swift:247, 256` — Combine sinks
- `OverlayManager.swift:99, 164` — scene observer, dismiss callback

No retain cycles detected. (The previous `AppCoordinator.swift:157/178`
threshold/pause-state callbacks were removed in #755 Phase E; the equivalent
flow now runs inside `SchedulingFeature.thresholdReachedEffect` /
`pauseStateChanged` via structured-concurrency `for await` loops on the
dependency-client async streams, which don't capture `self`.)

### 🟢 GOOD — Single TCA Store owned by `App.init`, never re-created
**File:** `EyePostureReminder/App/EyePostureReminderApp.swift:15, 48`

```swift
private let store: StoreOf<AppFeature>

init() {
    // …seed initialState from UserDefaults / launch args…
    self.store = Store(initialState: initialState) { AppFeature() }
}
```

The store is constructed once during `App.init` and held in a `let` for the
app lifetime — `WindowGroup` injects it into `RootView(store: store)` and
downstream views observe scoped sub-stores via
`@Perception.Bindable var store: StoreOf<…Feature>` plus
`WithPerceptionTracking` (e.g. `EyePostureReminder/Views/HomeView.swift:21,
201`, `EyePostureReminder/Views/SettingsView.swift:64, 103`). The
previous `@StateObject AppCoordinator` + `@EnvironmentObject` graph was
decommissioned in #755 Phase D (PR #759) and Phase E (PR #760); no view in
the tree allocates a duplicate root store.

### 🟢 GOOD — No large image assets
**File:** `EyePostureReminder/Resources/`

The app uses only SF Symbols (system icons) and custom font files. Font files are ~270KB each (Nunito Regular + Italic) — reasonable. No bitmap images in the asset catalog. The `Colors.xcassets` contains only color definitions (<1KB each).

### 🟡 WARNING — OverlayManager creates UIWindow on-demand but allocates UIHostingController on main thread
**File:** `EyePostureReminder/Services/OverlayManager.swift:157-173`

`UIHostingController` creation involves SwiftUI view tree setup on the main thread. While this is inherently required (UIKit mandate), the OverlayView contains haptic generator allocation. This is a minor concern since overlays fire at most every 10-60 minutes.

**Recommendation:** No action needed — frequency is too low to matter.

---

## 4. View Performance

### 🟢 GOOD — SwiftUI body properties are lightweight
All `body` properties contain only declarative view descriptions with no
computation, network calls, or data processing. Settings/Home views observe
state through `WithPerceptionTracking` over a scoped `StoreOf<…Feature>` plus
`@AppStorage`-backed primitives (see `EyePostureReminder/Views/SettingsView
.swift:64, 103`, `EyePostureReminder/Views/HomeView.swift:21, 201`), so only
the bindings actually read by `body` trigger view invalidation.

### 🟢 GOOD — HomeView uses .id() for efficient crossfade
**File:** `EyePostureReminder/Views/HomeView.swift:42`

```swift
.id(settings.globalEnabled)
```

This forces SwiftUI to treat the status text as a new view when the toggle changes, enabling clean transition animations without expensive diffing.

### 🟢 GOOD — ForEach uses proper identity
**File:** `EyePostureReminder/Views/ReminderRowView.swift:74`

```swift
ForEach(SettingsPickerOptions.intervalOptions, id: \.self) { seconds in
```

Using `id: \.self` on `TimeInterval` values is correct since these are unique
static constants. `SettingsPickerOptions` (defined in
`EyePostureReminder/Models/SettingsPickerOptions.swift`) hosts the picker
constants formerly exposed by `SettingsViewModel` — they were extracted in
#755 Phase B when the view model was deleted.

### 🟡 WARNING — YinYangEyeView breathing animation runs indefinitely
**File:** `EyePostureReminder/Views/YinYangEyeView.swift:72-79`

```swift
withAnimation(
    .easeInOut(duration: 4)
    .repeatForever(autoreverses: true)
) {
    breathing = true
}
```

This `.repeatForever` animation continues running even when the view is off-screen (e.g., when the user navigates to Settings). SwiftUI animations are GPU-driven and lightweight, but the continuous animation state prevents the display from entering low-power idle mode.

The `onAppear` guard (`guard !hasStarted`) prevents re-triggering, but there is no `onDisappear` to pause the animation.

**Impact:** Minor — the animation is a simple `scaleEffect` (GPU compositing, no layout), and the view is only present on `HomeView`. However, it does keep the GPU active.

**Recommendation:** Consider using `TimelineView` with a visibility check, or toggling the animation off in `onDisappear`.

### 🟢 GOOD — SettingsView does no eager work at construction
**File:** `EyePostureReminder/Views/SettingsView.swift:92-100`

`SettingsView.init` only stores its `StoreOf<SettingsFeature>` and the
injected `AccessibilityNotificationPosting` — no async work, no service
allocation. The settings sheet is presented lazily, so this cost is paid
only on the first open. (The legacy `SettingsViewModel` it replaced was
deleted in #755 Phase B and is no longer instantiated anywhere.)

---

## 5. Animation Efficiency

### 🟢 GOOD — scaleEffect and rotationEffect are GPU-accelerated
**File:** `EyePostureReminder/Views/YinYangEyeView.swift:55-56`

Both `.rotationEffect` and `.scaleEffect` are transform-based operations that run on the GPU compositor — no layout recalculations. This is the most efficient way to animate in SwiftUI.

### 🟢 GOOD — Animations respect reduce-motion
All animation sites check `@Environment(\.accessibilityReduceMotion)`:
- `RootView.swift:47` — onboarding transition
- `HomeView.swift:45` — status crossfade
- `OverlayView.swift:159, 234, 257, 276` — countdown ring, entrance, dismiss
- `YinYangEyeView.swift:66` — spin and breathing
- `ReminderRowView.swift:64` — settings expand
- `Components.swift:57, 109` — button press, calming entrance

When reduce-motion is enabled, all animations are skipped (`nil` animation or immediate state change).

### 🟡 WARNING — No explicit animation pause on app background
**File:** `EyePostureReminder/Views/YinYangEyeView.swift`

The breathing animation (`.repeatForever`) continues running when the app is backgrounded. While iOS suspends the render pipeline, the animation state is preserved and resumes immediately on foreground. This causes a brief GPU spike on every foreground transition.

**Recommendation:** This is a very minor concern. SwiftUI handles suspension well. No action required unless MetricKit reports GPU wake issues.

### 🟢 GOOD — Overlay entrance/exit animations are finite
**File:** `EyePostureReminder/Views/OverlayView.swift:234-238, 257-262`

Overlay entrance (0.5s ease-out) and exit (0.2s ease-in) animations are one-shot with defined durations. They do not repeat and complete quickly.

### 🟢 GOOD — Countdown ring uses linear animation keyed to value change
**File:** `EyePostureReminder/Views/OverlayView.swift:157-160`

```swift
.animation(
    reduceMotion ? .none : AppAnimation.countdownRingCurve,
    value: secondsRemaining
)
```

The animation only fires when `secondsRemaining` changes (once per second), not continuously.

---

## 6. Battery-Specific Concerns

### 🟢 GOOD — No location services used
The app does **not** use `CLLocationManager` or any Core Location APIs. Driving detection uses `CMMotionActivityManager` instead — a much more battery-efficient approach that uses the motion coprocessor (M-series chip), not GPS.

### 🟢 GOOD — Focus mode uses event-driven KVO, not polling
**File:** `EyePostureReminder/Services/PauseConditionManager.swift:72-83`

```swift
self.focusObservation = INFocusStatusCenter.default.observe(
    \.focusStatus, options: [.new]
) { ... }
```

KVO observation fires only when the Focus status changes. No polling timer.

### 🟢 GOOD — CarPlay detection is event-driven
**File:** `EyePostureReminder/Services/PauseConditionManager.swift:108-119`

Uses `AVAudioSession.routeChangeNotification` — fires only when audio routing changes (CarPlay connect/disconnect). Zero battery cost when idle.

### 🟢 GOOD — Driving detection uses CMMotionActivityManager
**File:** `EyePostureReminder/Services/PauseConditionManager.swift:158`

```swift
manager.startActivityUpdates(to: .main) { ... }
```

`CMMotionActivityManager` uses Apple's motion coprocessor chip, which runs at extremely low power independent of the main CPU. Activity updates are batched and delivered efficiently. The callback filters for `automotive && confidence == .high` (line 160), avoiding false positives.

### 🟢 GOOD — Audio session activated only during overlays
**File:** `EyePostureReminder/Services/AudioInterruptionManager.swift:43-72`

`AVAudioSession` is activated (`setActive(true)`) only when an overlay appears and deactivated (`setActive(false, options: .notifyOthersOnDeactivation)`) on every dismiss path. No persistent audio session.

### 🟢 GOOD — No background refresh scheduling
No `BGTaskScheduler` registration, no `UIApplication.shared.setMinimumBackgroundFetchInterval`, no background processing tasks. The app is purely foreground.

### 🟢 GOOD — AppConfig cached after first load
**File:** `EyePostureReminder/Models/AppConfig.swift:51-52`

```swift
private static let _mainBundleLoaded: AppConfig = _performLoad(from: .main)
```

JSON config is loaded and decoded exactly once per app lifecycle. Subsequent calls return the cached value — no repeated disk I/O.

---

## 7. Startup Performance

### 🟢 GOOD — Minimal work at launch
**File:** `EyePostureReminder/App/AppDelegate.swift:13-21`

`didFinishLaunchingWithOptions` does only three things:
1. Sets the notification center delegate
2. Registers MetricKit subscriber
3. Processes UI test arguments

No heavy initialization, no network calls, no database setup.

### 🟡 WARNING — Font registration on main thread at app init
**File:** `EyePostureReminder/App/EyePostureReminderApp.swift:16`

```swift
init() {
    AppTypography.registerFonts()
}
```

**File:** `EyePostureReminder/Views/DesignSystem.swift:83-96`

Font registration uses `CTFontManagerRegisterGraphicsFont`, which performs synchronous file I/O (reading TTF data from disk) on the main thread during app init. With only 2 font files (~270KB each), this completes in <5ms on modern devices.

**Impact:** Negligible on current hardware. Would only matter if many more fonts were added.

**Recommendation:** No action needed for 2 fonts. If font count grows beyond 5-6, consider deferring registration to a background queue.

### 🟢 GOOD — App root + SchedulingFeature start path is lightweight
**File:** `EyePostureReminder/App/EyePostureReminderApp.swift:17-49, 115-132`;
`EyePostureReminder/TCA/Features/SchedulingFeature.swift:481-503` (the
`.start` action)

`App.init` registers fonts, seeds onboarding/settings UserDefaults from
launch arguments under `#if DEBUG`, and constructs a single `Store
OfAppFeature`. The reducer body and dependency-client wiring are pure value
work — no I/O, no service allocation. `SchedulingFeature.start` is dispatched
from `RootView`'s `.task` modifier so the long-running async streams
(`trackerClient.thresholdReached`, `pauseConditionClient.pauseStateChanges`,
`settingsClient.stream`, scene/foreground notifications) are subscribed off
the first frame rather than during init. The deleted `AppCoordinator.init`
(#755 Phase E / PR #760) used the same "wire callbacks now, schedule work
via `.task`" shape — only the implementation moved from a god-object onto
the TCA reducer.

### 🟢 GOOD — No large asset catalog images
All visual elements use SF Symbols (system-provided, zero app bundle cost) and programmatic SwiftUI shapes (the yin-yang is drawn with Circle/Path primitives). No bitmap images to load.

---

## 8. Additional Findings

### 🟢 GOOD — AnalyticsLogger is pure os.Logger — no network
**File:** `EyePostureReminder/Services/AnalyticsLogger.swift`

Analytics uses only `os.Logger` — zero network calls, zero disk writes beyond the system log buffer. No third-party SDK overhead.

### 🟢 GOOD — Debounced per-type rescheduling
**File:** `EyePostureReminder/TCA/Features/SchedulingFeature.swift:267`

`SchedulingFeature.performReschedule` returns its work wrapped in
`.cancellable(id: CancelID.rescheduleDebounce(type), cancelInFlight: true)`,
so a burst of slider adjustments collapses into a single trailing reschedule
per `ReminderType`. This preserves the 300 ms debounce window that the
deleted `AppCoordinator.performReschedule` (#755 Phase E) previously
enforced, without thrashing `ScreenTimeTracker`.

### 🟢 GOOD — UI test mode disables background services
**Files:** `EyePostureReminder/Utilities/UITestMode.swift`;
`EyePostureReminder/Services/NoopServices.swift:17, 41`;
`EyePostureReminder/TCA/Features/SchedulingFeature.swift:48, 224`

`UITestMode.isUITestMode` reads `ProcessInfo.processInfo.arguments` once and
gates background work two ways: (1) `SchedulingFeature.State` carries an
`isUITestModeEnabled` flag that short-circuits the `.start` effect's
threshold/pause/foreground subscriptions, and (2) the dependency clients
themselves fall back to `Noop*` implementations (`NoopScreenTimeTracker`,
`NoopPauseConditionManager`, `ScreenTimeAuthorizationNoop`,
`DeviceActivityMonitorNoop`) when the live entitlements aren't available
or when XCUITest is detected. This eliminates the 1-second timer and motion
activity monitoring during UI tests — the same outcome the deleted
`AppCoordinator.isUITestMode` branch produced before #755 Phase E (PR #760).

### 🟢 GOOD — MetricKit subscriber registered for production monitoring
**File:** `EyePostureReminder/Services/MetricKitSubscriber.swift`

The app subscribes to `MXMetricManager` to receive daily metric and diagnostic payloads. This is a passive listener with zero battery cost — iOS delivers payloads on its own schedule.

### 🟡 WARNING — OnboardingView modifies UIPageControl.appearance() in init
**File:** `EyePostureReminder/Views/Onboarding/OnboardingView.swift:14-15`

```swift
init() {
    UIPageControl.appearance().currentPageIndicatorTintColor = UIColor(AppColor.primaryRest)
    UIPageControl.appearance().pageIndicatorTintColor = UIColor(AppColor.separatorSoft)
}
```

`UIAppearance` modifications are global singletons. While not a battery issue, this init runs every time SwiftUI re-creates the `OnboardingView` struct (potentially on each body evaluation of the parent). The appearance proxy is idempotent but involves Objective-C runtime calls.

**Recommendation:** Move to a `static let` initializer or use `.onAppear` with a guard.

---

## Summary Scorecard

| Area | Grade | Notes |
|------|-------|-------|
| Timer Efficiency | 🟢 A | 1s timer with 0.5s tolerance, pauses on background |
| Observer Cleanup | 🟢 A | All observers properly removed in deinit/stop |
| Memory Management | 🟢 A | Consistent [weak self], no retain cycles |
| View Performance | 🟢 A- | Lightweight bodies, proper identity |
| Animation Efficiency | 🟢 A- | GPU-accelerated, reduce-motion respected |
| Battery Impact | 🟢 A | No background modes, event-driven detection |
| Startup Performance | 🟢 A | Minimal blocking work before first frame |

---

## Priority-Ordered Action Items

| Priority | ID | Action | Effort |
|----------|----|--------|--------|
| P3 | PERF-001 | Add `tolerance` to OverlayView countdown timer | 1 line |
| P3 | PERF-002 | Consider pausing YinYang breathing animation on `onDisappear` | Small |
| P4 | PERF-003 | Move OnboardingView `UIPageControl.appearance()` to static init | Small |

**Legend:** P1 = fix immediately, P2 = fix this sprint, P3 = fix when convenient, P4 = nice-to-have

---

## Conclusion

kshana is **battery-efficient by design**. The architecture makes several excellent choices:
- Screen-time tracking via a foreground-only timer that pauses on background
- Event-driven detection for Focus, CarPlay, and driving (no polling)
- No background modes declared — the app does zero work when suspended
- Consistent `[weak self]` prevents retain cycles
- All animations respect `accessibilityReduceMotion`
- Lightweight startup path with deferred async work

The three warnings are all P3/P4 severity — none will cause measurable battery drain in real usage. The app is ready for production from a battery/performance perspective.

---

## Change Log

| Date | Change | By |
| --- | --- | --- |
| 2026-05-15 | Post-TCA-migration refresh (#775). Re-anchored AppCoordinator-era sections onto current TCA stack: §2 debounce cancellation now cites `SchedulingFeature.CancelID.rescheduleDebounce` / `.snoozeWakeTask`; §3 `[weak self]` list drops the deleted `AppCoordinator` callbacks and notes the equivalent `for await` flow inside `SchedulingFeature`; §3 lifecycle ownership rewritten as "Single TCA Store owned by `App.init`" with `StoreOf<AppFeature>` + `WithPerceptionTracking` references; §4 SwiftUI body claim re-anchored from `@EnvironmentObject` to scoped `StoreOf<…Feature>` + `@AppStorage`; §4 `ForEach` identity citation moved from `SettingsViewModel.intervalOptions` to `SettingsPickerOptions.intervalOptions` (#755 Phase B); §4 "lazy SettingsViewModel" rewritten as "SettingsView does no eager work at construction"; §7 startup section now cites `EyePostureReminderApp.init` + `SchedulingFeature.start` instead of the deleted `AppCoordinator.init`; §8 debounce / UI-test-mode sections re-anchored onto `SchedulingFeature` + `UITestMode` + `NoopServices` / `*Noop` dependency-client fallbacks. No findings were added or removed — only file/symbol citations were updated to match the post-#755 architecture. | Rusty |

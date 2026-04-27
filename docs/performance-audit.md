# kshana — Battery Life & Performance Audit

**Date:** 2025-07-18
**Scope:** All Swift source files, assets, Info.plist, background modes
**App:** kshana (formerly EyePostureReminder) — background timers + full-screen overlay reminders

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

### 🟢 GOOD — AppCoordinator cancels debounce tasks in deinit
**File:** `EyePostureReminder/Services/AppCoordinator.swift:205-208`

```swift
deinit {
    rescheduleDebounce.values.forEach { $0.cancel() }
    snoozeWakeTask?.cancel()
}
```

---

## 3. Memory Analysis

### 🟢 GOOD — Consistent [weak self] in closures
Every timer callback, notification observer closure, and Task uses `[weak self]`:
- `ScreenTimeTracker.swift:242` — timer callback
- `ScreenTimeTracker.swift:225` — reset task
- `PauseConditionManager.swift:229, 235, 239` — detector callbacks
- `PauseConditionManager.swift:247, 256` — Combine sinks
- `AppCoordinator.swift:157` — threshold callback
- `AppCoordinator.swift:178` — pause state callback
- `OverlayManager.swift:99, 164` — scene observer, dismiss callback

No retain cycles detected.

### 🟢 GOOD — @StateObject used correctly for AppCoordinator
**File:** `EyePostureReminder/App/EyePostureReminderApp.swift:6`

```swift
@StateObject private var coordinator = AppCoordinator()
```

The coordinator is created once by SwiftUI and persists for the app lifetime. Downstream views use `@EnvironmentObject` (not `@StateObject`), preventing re-creation.

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
All `body` properties contain only declarative view descriptions with no computation, network calls, or data processing. Settings views use `@EnvironmentObject` for reactive updates.

### 🟢 GOOD — HomeView uses .id() for efficient crossfade
**File:** `EyePostureReminder/Views/HomeView.swift:42`

```swift
.id(settings.globalEnabled)
```

This forces SwiftUI to treat the status text as a new view when the toggle changes, enabling clean transition animations without expensive diffing.

### 🟢 GOOD — ForEach uses proper identity
**File:** `EyePostureReminder/Views/ReminderRowView.swift:35-36`

```swift
ForEach(SettingsViewModel.intervalOptions, id: \.self) { seconds in
```

Using `id: \.self` on `TimeInterval` values is correct since these are unique static constants.

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

### 🟢 GOOD — SettingsView lazily creates SettingsViewModel
**File:** `EyePostureReminder/Views/SettingsView.swift:296-302`

The `SettingsViewModel` is created in `onAppear` only when needed, not eagerly. This avoids unnecessary work when the settings sheet is never opened.

---

## 5. Animation Efficiency

### 🟢 GOOD — scaleEffect and rotationEffect are GPU-accelerated
**File:** `EyePostureReminder/Views/YinYangEyeView.swift:55-56`

Both `.rotationEffect` and `.scaleEffect` are transform-based operations that run on the GPU compositor — no layout recalculations. This is the most efficient way to animate in SwiftUI.

### 🟢 GOOD — Animations respect reduce-motion
All animation sites check `@Environment(\.accessibilityReduceMotion)`:
- `ContentView.swift:19` — onboarding transition
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

### 🟢 GOOD — AppCoordinator init is lightweight
**File:** `EyePostureReminder/Services/AppCoordinator.swift:127-203`

The init creates service objects (all lightweight allocations), wires callbacks (closure assignment, no work done), and starts pause condition monitoring. `scheduleReminders()` is called asynchronously via `.task` modifier, not blocking the first frame.

### 🟢 GOOD — No large asset catalog images
All visual elements use SF Symbols (system-provided, zero app bundle cost) and programmatic SwiftUI shapes (the yin-yang is drawn with Circle/Path primitives). No bitmap images to load.

---

## 8. Additional Findings

### 🟢 GOOD — AnalyticsLogger is pure os.Logger — no network
**File:** `EyePostureReminder/Services/AnalyticsLogger.swift`

Analytics uses only `os.Logger` — zero network calls, zero disk writes beyond the system log buffer. No third-party SDK overhead.

### 🟢 GOOD — Debounced per-type rescheduling
**File:** `EyePostureReminder/Services/AppCoordinator.swift:324-332`

Settings changes are debounced per-type with a 300ms window, preventing rapid slider adjustments from thrashing the screen time tracker.

### 🟢 GOOD — UI test mode disables background services
**File:** `EyePostureReminder/Services/AppCoordinator.swift:120-123, 142-152`

When running under XCUITest, `NoopScreenTimeTracker` and `NoopPauseConditionManager` replace live services. This eliminates the 1-second timer and motion activity monitoring, preventing test flakiness and unnecessary resource usage during testing.

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

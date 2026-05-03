# Project Context

- **Owner:** Yashasg
- **Project:** Eye & Posture Reminder — a lightweight iOS app with background timers and full-screen overlay reminders for eye breaks (20-20-20 rule) and posture checks
- **Stack:** Swift, SwiftUI (iOS 16+), MVVM, UserNotifications, UIKit overlay, UserDefaults
- **Created:** 2026-04-24

## Core Context

**Phase 1–4 implementation history (2026-04-24 to 2026-04-25):**
- Services layer: SettingsStore, ReminderScheduler, AppCoordinator, OverlayManager, PauseConditionManager (FocusMode, CarPlay, Driving), ScreenTimeTracker with grace-period/reset state machine
- Data-driven config: AppConfig.swift + defaults.json (seeds UserDefaults on first launch; resetToDefaults() clears & re-seeds)
- Test infrastructure: MockSettingsPersisting, MockNotificationCenter, MockTimerFactory, MockAppLifecycleProvider for deterministic testing
- Bundle resource resolution: SPM `Bundle.module` in test code resolves to test target bundle, not production; production resources live in `EyePostureReminder_EyePostureReminder.bundle`
- SettingsStore two-layer pattern: UserDefaults layer (persistent) + AppConfig seeding layer (first-launch only)
- PauseConditionManager: reads settings at callback time (not registration); settings changes do NOT retroactively remove activeConditions
- ScreenTimeTracker: `CACurrentMediaTime()` monotonic clock + 5s grace period state machine + resume/pause tracking + independent eye/posture counters
- OverlayView: swipe-UP dismiss (translation.height < 0), Settings gear button calls onDismiss(), haptic feedback (medium impact) at countdown zero
- Info.plist: NSFocusStatusUsageDescription + NSMotionUsageDescription required; omitting either causes crash at first API access
- Build patterns: `./scripts/build.sh build` for compilation; `./scripts/run.sh` for bundle assembly with Info.plist refresh
- Build verified clean: Phase 1 tests passing, Phase 2–4 integration tests stable

**SPM/Swift ecosystem learnings:**
- UNTimeIntervalNotificationTrigger(repeats: true) requires ≥ 60s (OS silently rejects < 60s); use dynamic `repeats: interval >= 60`
- Code bundle ≠ resource bundle in SPM; UIColor(named:) + NSLocalizedString only search resource bundle
- LiveFocusStatusDetector uses KVO on focusStatus (not Notification.Name.INFocusStatusDidChange which does not exist)
- LiveCarPlayDetector checks AVAudioSession.Port(rawValue: "CarPlay") (AVAudioSession.Port.carPlay does not exist)
- LiveDrivingActivityDetector uses CMMotionActivityManager.startActivityUpdates; guards isActivityAvailable() for simulator

**Test patterns established:**
- @MainActor test class for async/UI work; sync tests are non-@MainActor (no decorators)
- MockNotificationCenter: addedRequests (append-only history) + pendingRequests (live queue)
- @testable import accesses protocol definitions inline (no Protocols/ folder needed)
- Bundle injection on AppConfig.load() + SettingsStore.init() for fixture testing

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


## Phase A DI/SRP Implementation Summary (2026-05-03)

**Completed Micro-Slices:**
- DateProviding seam for AppCoordinator recovery/watchdog paths
- SettingsViewModel snooze date seam
- handleNotification snooze guard date seam
- scheduleReminders snooze guard date seam
- Foreground session start clock seam
- Foreground launch readiness clock seam
- LiveCarPlayDetector notificationCenter seam
- AppDelegate launch-argument provider seam
- AppDelegate UI-test overlay consumer seam
- AppCoordinator pause-condition manager factory seam

**Core Pattern Established:**
Each Phase A micro-slice follows: optional inject protocol/factory → resolve once in init → fallback to production default → focused seam tests (fallback-used + explicit-bypass assertions) → full build/test validation.

**Key Architectural Decisions:**
- Prefer `dependency: Protocol? = nil` + fallback factory over eager default arguments
- UI-test guards (isUITestModeEnabled, NoopPauseConditionManager) placed *before* factory resolution to preserve XCUITest determinism
- All instance-resolved state should be used in lifecycle methods (not static globals)
- Seam tests are surgical: prove fallback-used path, prove explicit-injection bypass path, verify behavior through public method calls
- Production behavior is never changed: factories default to original implementations

**Validation Established:**
- `./scripts/build.sh build` and `./scripts/build.sh test` pass cleanly after each micro-slice
- No integration regressions detected
- Phase A momentum maintained with surgical, focused slices


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

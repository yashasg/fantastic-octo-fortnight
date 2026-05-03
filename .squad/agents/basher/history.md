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

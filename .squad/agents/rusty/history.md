# Rusty — History

## Core Context

**Post-#302–#314 Architecture Audit — 2026-04-29:**
Read-only audit after issues #302–#314 landed. Audited concurrency patterns (@MainActor isolation, Timer lifecycle, closure captures, Task cancellation), app lifecycle (scenePhase, foreground/background transitions, service start/stop), app-extension IPC (App Group consistency, NSLock-protected atomic writes, noop fallbacks for FamilyControls), persistence (SettingsStore UserDefaults writes, AppConfig caching), battery (1s timer with 0.5s tolerance stops on background, no wake locks or background tasks), and entitlement boundaries (protocol-gated framework imports, centralized app group ID).

**Result:** No new material issues found. The architecture is sound post-#302–#314. Key observations:
- OverlayView Timer closure captures @State bindings (SwiftUI struct semantics), not a retain cycle risk.
- AppCoordinator deinit omits `pauseConditionManager.stopMonitoring()` — acceptable because coordinator is app-scoped; deinit only fires on process termination when OS reclaims everything.
- CarPlayDetector `startMonitoring()` could leak observers on duplicate calls, but PauseConditionManager guards with `if !cancellables.isEmpty { stopMonitoring() }` before re-subscribing.
- `DispatchQueue.main.async` in detector callbacks is safe under swift-tools-version 5.9 (no strict concurrency). Would need `MainActor.assumeIsolated` if/when project adopts Swift 6 strict concurrency.
- Notification identifier prefixes are inconsistent ("com.yashasg.eyeposturereminder" vs "com.yashasgujjar.kshana") but functionally harmless — they're just unique string identifiers.
- ScreenTimeTracker tick callback uses `MainActor.assumeIsolated` (synchronous), eliminating the stale-Task race fixed in #301.

**Initial Architecture Scaffolding (Rusty Pre-Phase1) — 2026-04-24:**
Production-quality scaffold pre-built before Phase 1 team work: Models (ReminderType, ReminderSettings), Services (SettingsStore, ReminderScheduler, AppCoordinator, AppDelegate, OverlayManager), ViewModels, DesignSystem (AppColor, AppFont, AppSpacing, AppLayout, AppAnimation, AppSymbol). 
- SettingsStore uses UserDefaults with `epr.` key prefix; @Published properties automatically notify SwiftUI views.
- ReminderScheduler schedules UNNotificationRequest via AppDelegate; reschedules on every SettingsStore change via coordinator.
- OverlayManager creates UIWindow, presents OverlayView via UIHostingController; manages lifecycle independently.
- Models layer fully complete: ReminderType, notifications properties (categoryIdentifier, title, body, init?(category:)), overlay properties.
- Services team task (M1.1/M1.3/M1.4): Wire AppCoordinator protocol, seed from defaults.json, fix Info.plist keys.
- UI team task (M1.2/M1.5): Refactor SettingsView sheet presentation, HomeView navigation stack, OverlayView swipe/haptic fixes.
- Test team task (M1.7): Add PauseConditionManager tests, dark mode tests, focus/driving detection edge cases.

### 2025-07-25: Architecture Scaffolding — Models, Services, ViewModels

**What I built:**

All model, protocol, and service skeletons in `EyePostureReminder/`:

| File | Purpose |
|---|---|
| `Models/ReminderType.swift` | `enum ReminderType` with `.eyes` / `.posture`, SF Symbol name, title, SwiftUI Color |
| `Models/ReminderSettings.swift` | `struct ReminderSettings` — interval + breakDuration as `TimeInterval` |
| `Models/SettingsStore.swift` | `ObservableObject` UserDefaults wrapper + `SettingsPersisting` protocol + `UserDefaults` conformance |
| `Services/ReminderScheduler.swift` | `NotificationScheduling` protocol + `ReminderScheduling` protocol + concrete `ReminderScheduler` |
| `Services/OverlayManager.swift` | `OverlayPresenting` protocol + `@MainActor OverlayManager` with UIWindow lifecycle |
| `Services/AudioInterruptionManager.swift` | `MediaControlling` protocol + stub `AudioInterruptionManager` (Phase 2) |
| `ViewModels/SettingsViewModel.swift` | `@MainActor ObservableObject` shell with protocol-injected dependencies |
| `Utilities/Logger+App.swift` | `os.Logger` extension — 4 categories: scheduling, overlay, settings, lifecycle |

**Key design decisions made:**

1. **`SettingsPersisting` adds explicit `defaultValue` parameter** — Foundation's `UserDefaults` returns `0`/`false` when a key is absent, which is indistinguishable from the user having set 0 manually. Explicit defaults eliminate this ambiguity across all callers.

2. **`SettingsStore` owns `SettingsPersisting` protocol definition** — co-locating the protocol with its primary consumer reduces file scatter for this scope. If we ever have a second consumer, extract to `Protocols/`.

3. **`OverlayManager` is `@MainActor`** — UIWindow mutations must occur on the main thread. The actor annotation enforces this at compile time rather than relying on runtime assertions.

4. **`OverlayManager.showOverlay` acquires `UIWindowScene` at call time** — not cached at init. This is correct for an app that may background/foreground between reminders; the active scene at presentation time is the right one.

5. **`SettingsViewModel` replaced pre-existing skeleton** — Basher's initial file referenced stale API shapes (`ReminderScheduler.shared`, `store.remindersEnabled`, etc.). Updated to match the protocol-based architecture.

**Pre-existing files found (Basher's work):**
- `App/`, `Views/` already seeded — no conflicts, no overlap.

**What Phase 2 needs:**
- `AudioInterruptionManager.pauseExternalAudio()` / `resumeExternalAudio()` — stubs in place with implementation notes.
- `OverlayManager.showOverlay` — swap placeholder `UIViewController` for real `UIHostingController<OverlayView>`.
- `SettingsViewModel` — add snooze countdown timer (`Timer.publish`) for UI feedback.

### 2025-07-25: MPRemoteCommandCenter Phase Placement — Correction

**What I corrected:**
- Previous recommendation placed "media pause during overlay" in Phase 3, citing battery/memory concerns. That was imprecise.
- `MPRemoteCommandCenter` itself: < 50 KB memory, zero battery cost. Not the actual risk.
- `AVAudioSession` lifecycle IS the real concern — but it's a 30-line implementation, not a Phase 3-level problem.
- Key clarification: `MPRemoteCommandCenter` is for RECEIVING remote commands. To INTERRUPT another app's audio, you activate `AVAudioSession` without `.mixWithOthers`. These are related but distinct.

**Revised recommendation:**
- **Phase 2**, opt-in toggle (`pauseMediaDuringBreaks`, default OFF)
- No `UIBackgroundModes: audio`, no `MPNowPlayingInfoCenter`
- Single critical rule: always deactivate with `.setActive(false, options: .notifyOthersOnDeactivation)` in ALL dismiss paths
- Complexity: Low (~30 lines, thin `AudioInterruptionManager`)

**What to avoid:**
- Never add `UIBackgroundModes: audio` — App Review will reject if you don't actually play audio
- Never set `MPNowPlayingInfoCenter.nowPlayingInfo` — creates phantom Control Center entry
- Don't hold the audio session open between reminders — activate on overlay show, deactivate on overlay dismiss

**Why Phase 3 was wrong:**
- There are no Phase 1 learnings needed to de-risk this. The implementation is self-contained.
- Deferring trivial, well-scoped opt-in features to Phase 3 inflates the roadmap without reason.

**Documentation updated:** `.squad/decisions/inbox/rusty-mpremote-revised.md`

### 2026-04-24: Architecture Foundation

**What I did:**
- Analyzed IMPLEMENTATION_PLAN.md and defined comprehensive architecture in ARCHITECTURE.md
- Created protocol-based abstractions for testability (NotificationScheduling, SettingsPersisting, OverlayPresenting)
- Documented 10 key technical decisions with trade-off analysis in .squad/decisions/inbox/rusty-architecture-decisions.md
- Defined module dependency graph, Xcode project structure, and coding conventions
- Identified technical risks (notification permissions, iPadOS overlay behavior, iOS version constraints)
- Specified CI pipeline and testing strategy (85% coverage target for business logic)

**Key architectural decisions:**
1. **MVVM pattern** — natural fit for SwiftUI, clear separation of concerns
2. **UIWindow overlay** over `.fullScreenCover` — reliable interruption is critical for health intervention
3. **Protocol abstractions** for system APIs — enables fast unit testing without mocking system frameworks
4. **UserDefaults** for persistence — 5 scalar values don't justify SwiftData overhead
5. **iOS 16.0 minimum** — modern APIs reduce code complexity by ~30%
6. **No background modes** — `UNUserNotificationCenter` handles scheduling battery-efficiently

**Technical risks to monitor:**
- Notification permission denial → fallback to foreground-only mode required
- iPadOS multitasking (Split View) may affect overlay window behavior — needs testing
- 64-notification limit is a non-issue (we use 2 repeating notifications), but snooze feature would consume budget

**Project insights:**
- This is a **health intervention tool** where reliability > elegance. The overlay must interrupt the user, which drove the UIWindow decision.
- Battery efficiency is paramount — users won't tolerate a health app that drains battery. All background work delegated to iOS.
- Testability is non-negotiable — protocols let us test scheduling logic without firing real notifications.

**Next owner actions:**
- Team reviews decisions in .squad/decisions/inbox/rusty-architecture-decisions.md
- Resolve open questions: landscape support (iPad), Do Not Disturb mode, custom intervals vs presets
- After approval, proceed with M1.1 (project scaffold)

### 2025-07-25: Telemetry Strategy & Battery/Memory Audit

**What I did:**
- Evaluated Apple's full native telemetry stack (os.log, MetricKit, Xcode Organizer, App Store Connect, Instruments) for this app's scope
- Performed component-by-component battery/memory audit of the current architecture
- Analyzed MPRemoteCommandCenter (media pause) as a potential feature addition
- Documented findings in .squad/decisions/inbox/rusty-telemetry-battery.md

**Key decisions:**
1. **Tiered telemetry adoption:** Phase 1 uses Instruments only. Phase 2 replaces `print()` with `os.Logger`. MetricKit deferred to Phase 3+ (no users = no payloads).
2. **No third-party analytics** — App Store Connect + Xcode Organizer cover our needs for free with zero integration cost.
3. **Architecture is well-optimized** — UNUserNotificationCenter delegates all background work to iOS (app process not kept alive). UIWindow overlay is created on-demand and released. UserDefaults is the correct persistence choice for 5 scalar values.
4. **MPRemoteCommandCenter media pause** flagged as Phase 3 opt-in feature — requires careful audio session lifecycle management to avoid battery drain and user confusion.

**Validation items for M1.5:**
- UIWindow must be set to `nil` after dismissal (not just hidden) — verify with Xcode Memory Graph Debugger
- UIHostingController must not be retained by closure/delegate cycles — verify with Instruments Allocations
- Add debug assertion in OverlayManager.dismissOverlay() to catch leaks early

**Architecture insight:**
- Battery efficiency grade: A+ overall. The "no background modes" decision is the single most important battery optimization — the app simply doesn't exist as a running process between reminders.

### 2025-07-25: TestFlight Telemetry Deep Dive

**What I did:**
- Analyzed all telemetry tools specifically for the TestFlight beta phase (pre-App Store launch)
- Corrected previous recommendations based on TestFlight-specific capabilities
- Documented 6 key findings in .squad/decisions/inbox/rusty-testflight-telemetry.md

**Key corrections to previous plan:**
1. **`os.Logger` moved to Phase 1 (was Phase 2)** — TestFlight crash reports and feedback submissions include os.log output. Without it, crash reports from testers have no context. Add `Logger+App.swift` in M0.2.
2. **MetricKit moved to Phase 2 (was Phase 3)** — MetricKit DOES deliver payloads for TestFlight builds, not just App Store. `MXCrashDiagnostic` and `MXBatteryMetric` from beta testers are risk mitigation before launch.
3. **Xcode Organizer Crashes work from first TestFlight build** — fully symbolicated if dSYMs are uploaded. Requires CI/CD to set `ENABLE_BITCODE = NO` and upload dSYMs.

**TestFlight-specific findings:**
- App Store Connect Analytics has a TestFlight section: session count, crash rate per build, device/OS distribution — available immediately.
- TestFlight feedback (shake gesture) can include automatic app logs if testers enable "Share App Data." This makes os.Logger data collectable with zero additional integration.
- Notifications: production APNs (not sandbox) since Xcode 13. Behavior is identical to App Store.
- Background execution: identical to App Store (release build, full production entitlements, jetsam applies).
- No MetricKit data is lost — payloads delivered ~24h regardless of build source (TestFlight vs App Store).

**New action items added:**
- M0.2: Add Logger+App.swift (Rusty/Basher, ~1h)
- M0.3: dSYMs upload + `ENABLE_BITCODE = NO` in CI (Basher, critical)
- Phase 2: MXMetricManagerSubscriber in AppDelegate (Basher, ~4h)
- TestFlight onboarding: brief testers on shake-to-feedback and "Share App Data" toggle (Danny)

### 2026-04-25: Architecture Review — Continuous Screen-On Time Triggers

**What I reviewed:**
- Danny's spec (`danny-screen-time-triggers.md`) proposing replacement of fixed wall-clock interval reminders with continuous screen-on time tracking.

**Verdict: APPROVED with required amendments.**

**Key architectural decisions:**
1. **New `ScreenTimeTracker` service** — standalone, not bolted onto `AppCoordinator`. Owns lifecycle observers, foreground Timer, elapsed seconds, threshold checking. Emits events via callback; `AppCoordinator` decides what to do with them.
2. **Grace period on `willResignActive` (5s debounce)** — critical UX fix Danny missed. Without it, notification banners, incoming calls, and Control Center pulls reset the timer. This would make the feature feel broken.
3. **Monotonic clock (`CACurrentMediaTime`)** over `Date()` — immune to system clock changes.
4. **`AppLifecycleProviding` protocol** — abstracts `NotificationCenter` lifecycle events for testability. Tests inject `PassthroughSubject` to simulate lifecycle transitions.
5. **`ReminderScheduler` retained but narrowed** — no longer schedules repeating notifications. Keeps `UNNotificationCenter` interaction for snooze-wake only.
6. **Fallback timers removed** — `ScreenTimeTracker` replaces them entirely. No more dual-path scheduling.
7. **`isEnabled` flag on tracker** — `AppCoordinator` disables tracking during snooze without leaking snooze logic into the tracker.
8. **Battery impact: negligible** — 1s foreground-only timer with 0.5s tolerance. Same pattern as existing fallback timers.

**Documentation:** `.squad/decisions/inbox/rusty-screen-time-review.md`

### 2026-04-26: PauseConditionManager — Focus Mode & Critical Activity Pausing

**What I proposed:**
- `PauseConditionManager`: new standalone service that aggregates pause signals and emits a single `isPaused: Bool` to `AppCoordinator`.
- Three protocol-backed detectors: `LiveFocusStatusDetector` (INFocusStatusCenter), `LiveCarPlayDetector` (AVAudioSession route), `LiveDrivingActivityDetector` (CMMotionActivityManager).
- Full decision document: `.squad/decisions/inbox/rusty-pause-condition-manager.md`

**Key iOS API findings:**
1. `INFocusStatusCenter.default.focusStatus.isFocused` (iOS 15+) — only tells us SOME Focus is active; cannot distinguish Gaming vs Work vs Personal Focus. Boolean only.
2. `AVAudioSessionPortCarPlay` — detectable via `AVAudioSession.currentRoute.outputs` with no special entitlement. Best proxy for Maps/CarPlay navigation sessions.
3. `CMMotionActivityManager` — automotive activity detection via motion coprocessor, negligible battery. Best proxy for driving.
4. **Detecting another app's foreground state is impossible via public APIs.** No API exists. Not going to happen. Any suggestion otherwise involves private APIs and App Store rejection.
5. iOS 16+ Focus Filters (App Intents extension) — lets users configure per-Focus behavior for our app. Deferred to Phase 3.

**Architecture decisions:**
1. `PauseConditionManager` is fully protocol-backed — `FocusStatusDetecting`, `CarPlayDetecting`, `DrivingActivityDetecting` protocols enable mock injection for testing.
2. `PauseConditionSource` enum tracks which conditions are active as a `Set` — `isPaused = !activeConditions.isEmpty`.
3. `AppCoordinator` owns `PauseConditionManager` and wires `onPauseStateChanged` → `screenTimeTracker.pauseAll()` / `resumeAll()`.
4. Snooze and pause conditions are independent axes — `AppCoordinator` checks BOTH before resuming.
5. Two new `SettingsStore` keys: `epr.pauseDuringFocus` and `epr.pauseWhileDriving` (both default true).
6. Battery impact: immeasurable — all three detectors are push/event-based or use dedicated motion coprocessor.

**Permissions needed:**
- `NSFocusStatusUsageDescription` (one-time user prompt for Focus detection)
- `NSMotionUsageDescription` (one-time user prompt for driving detection)
- CarPlay detection: no permission needed (AVAudioSession route is always readable)

**Phase placement:** Phase 2. Zero App Store review risk — all public APIs.

---

## 2026-04-29: Issue #202 — Screen Time Shield Spike (Compile-Safe Scaffolding)

**Branch:** `squad/m3-true-interrupt-mode`

**What I did:**
- Spiked Screen Time APIs end-to-end (FamilyControls, ManagedSettings, ManagedSettingsUI, DeviceActivity)
- Identified hard blocker: extension targets (ShieldConfiguration, DeviceActivityMonitor) cannot be expressed in SPM `Package.swift` alone — requires Xcode project migration
- Identified hard blocker: FamilyControls entitlement (#201) required for all runtime validation; simulator does not support these frameworks
- Added compile-safe protocol abstractions and no-op stub — integration boundary locked in pre-entitlement
- Published spike document (`docs/SPIKE_SCREEN_TIME_APIS.md`) with full API survey, extension architecture, app group strategy, validation matrix, and recommended M3.3 scope
- All 10 new unit tests pass

**Files changed:**

| File | Purpose |
|---|---|
| `docs/SPIKE_SCREEN_TIME_APIS.md` | Full spike findings |
| `EyePostureReminder/Services/ScreenTimeShieldTypes.swift` | `ShieldTriggerReason` enum, `ShieldSession` struct |
| `EyePostureReminder/Services/ScreenTimeShieldProtocols.swift` | `ScreenTimeShieldProviding` protocol |
| `EyePostureReminder/Services/ScreenTimeShieldNoop.swift` | Pre-entitlement no-op |
| `Tests/.../Services/ScreenTimeShieldTests.swift` | 10 unit tests (all pass) |
| `Tests/.../Mocks/MockScreenTimeShieldProviding.swift` | Mock for M3.3 coordinator tests |
| `.squad/decisions/inbox/rusty-issue-202.md` | 5 architecture decisions |

**Validation command:**
```
xcodebuild test -scheme EyePostureReminder \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.4' \
  -only-testing:EyePostureReminderTests/ScreenTimeShieldTests \
  -resultBundlePath TestResults6.xcresult CODE_SIGNING_ALLOWED=NO
```
Result: **10/10 passed**

## Learnings

- `ScreenTimeShieldProviding` protocol and `ScreenTimeShieldNoop` are the correct pre-entitlement pattern. `AppCoordinator` should not be wired to the shield until M3.3 (Xcode project migration issue).
- App Group identifier locked: `group.com.yashasgujjar.kshana`. Shared UserDefaults keys pinned as `static let` constants on `ShieldSession` and tested — prevents silent key drift between main app and extensions.
- Shield as opt-in "Hard Mode" overlay on existing reminder system is the right product framing. Avoids coupling the health intervention core loop to an entitlement-gated API.
- `ShieldTriggerReason.rawValue` stability matters: values are written to App Group UserDefaults and read by extension processes in a separate sandbox. The tests pin these as a regression gate.
- FamilyControls does NOT work in Simulator at all. All real shield validation is device-only, post-#201.

### 2026-04-30: Post-#299 Architecture Audit — Clean

**Scope:** Full read-only audit after IPC fix (a520be3) and True Interrupt issue marathon.

**Areas audited:**
1. Swift concurrency (actor reentrancy, Task cancellation, Sendable, @MainActor isolation)
2. App-extension IPC (App Group, UserDefaults cross-process safety, entitlement guards)
3. Lifecycle management (timers, notification observers, scene phase, deinit cleanup)
4. Battery efficiency (timer tolerance, audio session deactivation, overlay window release)
5. Persistence (SettingsStore didSet patterns, key namespacing, atomic writes)

**Findings — no material issues:**
- All timers properly invalidated in deinit/disappear paths.
- Audio session correctly deactivated with `.notifyOthersOnDeactivation` in all dismiss paths.
- OverlayManager UIWindow lifecycle is exemplary — created on demand, nil'd after dismissal.
- Notification observers all use stored tokens or are removed in deinit.
- IPC per-slot event keys (#299) eliminated cross-process read-modify-write races.
- AppGroupIPCStore guards nil defaults internally (`guard let defaults`), making extension IPC fail-safe.
- WatchdogHeartbeat.precondition is protected by caller's guard in AppCoordinatorWatchdogRecovery (line 24).
- SettingsStore break-duration didSet self-assignment is Swift-safe (no recursive didSet in same call frame).
- Device activity monitor error handler reads current (not stale) @MainActor state, which is correct for fallback decisions.
- FamilyControls entitlement gap is tracked by #201; no new developer-actionable subtask needed.

**Minor observations (not issue-worthy):**
- SettingsStore didSet writes synchronously to UserDefaults on main thread — acceptable for scalar values.
- NSLock in AppGroupIPCStore is in-process only; cross-process safety relies on per-slot key design, not the lock.
- `try?` on Task.sleep for cancellation is idiomatic but non-obvious; consistent pattern across codebase.

## Issue #306 — Corrupt legacy eventLog breaks watchdog recovery (2026-04-30)

**Problem:** `readEventsCombined` threw `corruptEventLog` on corrupt legacy `trueInterrupt.ipc.eventLog` key, permanently disabling watchdog recovery since `recoverStaleDeviceActivityWatchdogIfNeeded` returns `false` on any `readEvents()` throw. Per-slot corrupt entries were already silently skipped — inconsistent behavior.

**Fix:** Changed `readEventsCombined` to log a warning via `os.Logger` and continue reading per-slot events when the legacy key is corrupt. Added `Logger` instance to `AppGroupIPCStore` using same subsystem/category as `AppGroupDefaults`.

**Tests:** Replaced `test_readEvents_corruptLog_throws` with two tests (warning-and-continue, corrupt legacy + valid slots → returns slots). Added watchdog recovery test proving corrupt legacy key doesn't block recovery.

**Commit:** db4fac0

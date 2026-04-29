## Learnings

### 2026-04-26: Architecture Audit v2 — Deeper Pass

**Scope:** Full re-read of all key files (AppCoordinator, ScreenTimeTracker, PauseConditionManager, OverlayManager, AnalyticsLogger, MetricKitSubscriber, ReminderScheduler, SettingsViewModel, AppDelegate, Package.swift).

**Key new findings (beyond v1):**

1. **🔴 P0: ScreenTimeTracker and its protocol lack `@MainActor`** — all access is main-thread in practice (Timer, NotificationCenter observers), but no compile-time enforcement. This will fail under Swift 6 strict concurrency. Protocol `ScreenTimeTracking` must also be annotated.
2. **🟡 P1: PauseConditionManager and detector protocols also lack `@MainActor`** — same class of issue. `PauseConditionProviding` callbacks cross isolation boundaries without Sendable guarantees.
3. **🟡 P1: Analytics events `.reminderTriggered`, `.overlayDismissed`, `.overlayAutoDismissed`, `.appSessionEnd` are defined but never emitted** — analytics system has gaps that undermine its debugging value.
4. **🟢 P2: `AppDelegate.coordinator` is strong (not weak)** — safe in single-window app but defensive improvement for multi-scene.
5. **🟢 P2: `resumeAll()` doesn't reset elapsed counters (asymmetric with `pauseAll()`)** — intentional design, but undocumented.

**v1 P1s confirmed still open:** AnalyticsEvent Sendable, MetricKitSubscriber unregistered.

**Score:** 8/10 (down from 8.5). Report: `.squad/decisions/inbox/rusty-arch-pass-v2.md`

### 2026-04-26: Edge Case Analysis — Quality Pass (Issues #26–#29)

**Scope:** Full read of AppCoordinator, ScreenTimeTracker, OverlayManager, PauseConditionManager, ReminderScheduler, SettingsStore, AppDelegate, EyePostureReminderApp.

**Four confirmed bugs filed:**

| # | Issue | Severity | Root cause |
|---|---|---|---|
| #26 | PauseConditionManager stale state when pause-setting toggled mid-condition | High | `update()` only called on detector callbacks, not on settings changes — `activeConditions` never re-evaluated when `pauseDuringFocus`/`pauseWhileDriving` flips |
| #27 | Active overlay stays visible when driving/CarPlay pause fires | Medium-High | `onPauseStateChanged(true)` only calls `screenTimeTracker.pauseAll()`, never `overlayManager.dismissOverlay()` |
| #28 | ScreenTimeTracker elapsed counter wiped on break-duration change | Medium | `setThreshold` always resets `elapsed[type] = 0` — called for all reminder settings changes, not just interval changes |
| #29 | Snooze-wake notification is user-visible banner; dismissed banner = dead snooze on killed app | Low-Medium | `scheduleSnoozeWakeNotification` sets title/body; `didReceive` never fires if user swipes banner away; killed-app self-heals only on next manual open |

**Key architecture invariants confirmed safe:**
- `ScreenTimeTracker` grace period (5s) correctly handles notification banners, incoming calls, Control Center pulls.
- `OverlayManager` overlay queue handles concurrent eye+posture threshold hits.
- `AppCoordinator.onPauseStateChanged(false)` correctly checks snooze state before resuming.
- `wasInBackground` flag correctly gates `handleForegroundTransition` to genuine background→foreground only.
- `OverlayView` uses `Timer.scheduledTimer` which auto-pauses on `willResignActive` — device-sleep countdown drift is NOT an issue.
- `scenePhase .active` calls `presentPendingOverlayIfNeeded()` safely — `pendingOverlay` is nil-checked and cleared on first use.
- Periodic `UNNotificationTrigger` (legacy scheduler path) is dead code post-ScreenTimeTracker migration — the 60s minimum trigger interval constraint cannot be hit.

**Findings ruled out (not bugs):**
- Force-quit during overlay: all `onDismiss` callbacks are `{}` — no state to corrupt. Self-heals on relaunch.
- Clock/DST changes: snooze uses `date.timeIntervalSinceNow` at schedule time, not stored interval. `max(0, ...)` handles forward time jumps. Backward jumps extend snooze — acceptable edge case.
- Short intervals (<60s): blocked by ScreenTimeTracker's `threshold > 0` guard. UNTimeIntervalTrigger min is not hit.
- CarPlay raw port string `"CarPlay"`: matches Apple's SDK raw value. Fragile but not wrong.

### 2026-04-25: Architecture Review — Updated ARCHITECTURE.md (04:35 spawn)
- **Deliverable:** ARCHITECTURE.md rewritten with 6 major corrections
- **Corrections:** Module graph accuracy, protocol definitions, SPM structure, trigger model, AppConfig initialization, onboarding state machine
- **Impact:** New authority for impl team; resolved ambiguities in Services/Views boundaries; informed Basher's DI protocol design (#13, #14)
- **Quality note:** Corrections validate Rusty's edge case analysis (#26–#29) — state machine invariants properly documented post-review.


## Session 6 Update: Screen-Time Triggers Architecture Finalized

**Session:** 2026-04-24T20:58Z – 2026-04-24T21:37Z

### Architecture Review Complete ✅

Reviewed Danny's screen-time spec and approved with **6 required amendments** (documented in Decision 3.2):

**Critical Amendment — Grace Period (5s debounce):**
```swift
func handleWillResignActive() {
    pauseTimer()  // stop incrementing immediately
    resetTask = Task { [weak self] in
        try? await Task.sleep(nanoseconds: UInt64(5.0 * 1_000_000_000))
        guard !Task.isCancelled else { return }
        self?.resetElapsedTime()
    }
}

func handleDidBecomeActive() {
    if let resetTask {
        resetTask.cancel()  // came back within grace period
        resumeTimer()
    } else {
        startTracking()  // genuine screen-off (grace expired)
    }
}
```

**Why this matters:** Without the grace period, notification banners, incoming calls, and Control Center pulls would reset the timer to zero. User loses 19 minutes of accumulated time because a text arrived — feature feels broken.

### Implementation Status

Basher implemented ScreenTimeTracker per architecture spec (Decision 3.4):
- ✅ Standalone service (not in AppCoordinator)
- ✅ 5s grace period with Task-based cancellation
- ✅ Monotonic clock (`CACurrentMediaTime()`)
- ✅ `isEnabled` flag for snooze suppression
- ✅ `Timer.tolerance = 0.5` for battery coalescing
- ✅ Build: **BUILD SUCCEEDED**

### Module Structure Realized

```
Services/
├── ScreenTimeTracker.swift (NEW) — lifecycle + timer + thresholds
├── ReminderScheduler.swift (NARROWED) — UNNotifications for snooze-wake only
├── AppCoordinator.swift (UPDATED) — subscribes to tracker events, wires to overlays
└── OverlayManager.swift — unchanged

Dependency flow:
  AppCoordinator → ScreenTimeTracker (owns, start/stop/reset)
  ScreenTimeTracker → (callback) → AppCoordinator (what to do with threshold events)
  AppCoordinator → OverlayManager (present reminders)
```

### Testing Strategy Documented

For Livingston's unit tests:
- `MockTimerFactory` — fires ticks on demand (no real timers in tests)
- `AppLifecycleProviding` protocol — tests inject `PassthroughSubject` for lifecycle events
- `MockTimeProvider` — clock is mockable
- Test cases: grace period, threshold firing, multi-threshold handling, snooze suppression, settings reschedule, system clock immunity

### Next: Testing Phase

Livingston will implement ScreenTimeTracker unit tests using mock factories + mock lifecycle provider. 8 test cases documented in architecture review; ~60-80 lines of test code per case.



## 2026-04-25 — Architecture: Wave 2 Testing Strategy Documentation

**Status:** ✅ Complete  
**Scope:** Testing architecture patterns and conventions documented in ARCHITECTURE.md

### Orchestration Summary

- **Testing Layers Defined:** Unit (manager + detectors), Integration (cross-component), UI (XCUITest)
- **Conventions Established:** Mocking patterns, fixture factory, async test patterns
- **XCUITest Requirements Documented:** Blocker (SPM limitation) and workaround (add .xcodeproj)
- **Data Flow Diagrams:** Testing architecture visually documented
- **Orchestration Log:** Filed at `.squad/orchestration-log/2026-04-24T23-19-18Z-rusty.md`

### Architecture Decisions

- Layered testing aligns with clean MVVM architecture
- Fixture factory pattern for detector mocks (reusable across test suites)
- Test environment flags via launchArguments for reproducible UI testing
- Documented test data patterns (UserDefaults mocking, NotificationCenter test doubles)

### Next Phase

Testing infrastructure documented and ready. XCUITest blocker (Phase 2) documented in decisions.md.


## Learnings

### 2026-04-25 — ARCHITECTURE.md Codebase Audit

Performed a full audit of the production codebase vs ARCHITECTURE.md (which was written early and had drifted significantly). Key findings:

**Structural deltas from early doc:**
- No `Protocols/` folder exists — all protocols are co-located with their primary implementation file. This is actually a better DX than a separate folder for a project at this scale.
- Project is SPM (`Package.swift`), not `.xcodeproj`. Build commands in the doc referenced `-project` flags that don't work.
- `DefaultsLoader` was documented but never existed — the real class is `AppConfig` with a static `AppConfig.load(from:)` factory. The design is cleaner than the doc described (Codable struct + `fallback` static, no separate loader type needed).

**Net-new services not documented at all:**
- `ScreenTimeTracker` — the entire trigger model changed from periodic `UNNotification` repeating triggers to a continuous screen-on timer. This is a big architectural shift: `ReminderScheduler` is now narrowed to snooze-wake notifications only.
- `AudioInterruptionManager` — `MediaControlling` protocol + `AVAudioSession.soloAmbient` approach, with the invariant that `resumeExternalAudio()` must be called in every dismiss path.
- `AppCoordinator` now conforms to `ReminderScheduling` — this is the injection point for `SettingsViewModel`, not the raw `ReminderScheduler`.

**Onboarding:** Fully implemented (4 files, 3-screen PageTabView), `hasSeenOnboarding` gate in `ContentView`, `OnboardingScreenWrapper` animation helper with reduced-motion support.

**Phase 2 features shipped:**
- Haptics (`hapticsEnabled` in SettingsStore)
- Snooze (full snooze state machine in SettingsStore + AppCoordinator)
- Smart Pause (PauseConditionManager + three live detectors, all tested)

**Protocol signature update:** `SettingsPersisting` now requires explicit `defaultValue:` parameters on all read methods — this eliminates the silent-zero/false class of bug that bit us before. The old doc showed the pre-fix signature.

**Lesson:** Architecture docs written at project start become actively misleading within a few sprints. Consider requiring ARCHITECTURE.md to be in the PR diff for any service-layer change.

### 2025-07-25 — Full Architecture Quality Review (READ-ONLY)

Performed a comprehensive architecture quality audit across all 6 dimensions. Summary:

**MVVM compliance (Strong):** Clean 3-layer separation (Views → ViewModels → Services). One issue: `SettingsView` uses a `SettingsViewModelBox` wrapper pattern that leaves `viewModel` nil during first render, requiring `?.` chaining everywhere. Should refactor to inject VM directly.

**Protocol usage (Strong):** Every service has a testable protocol: `NotificationScheduling`, `ReminderScheduling`, `OverlayPresenting`, `MediaControlling`, `ScreenTimeTracking`, `SettingsPersisting`, `PauseConditionProviding`, plus 3 detector protocols. Mocks exist for all. `AppCoordinator.scheduler` is correctly typed as `ReminderScheduling` (protocol).

**Module structure (Good):** Clean folder layout: App/, Models/, Services/, ViewModels/, Views/, Utilities/, Resources/. Protocols co-located with implementations (pragmatic for this scale). No misplaced files found.

**Swift concurrency (Good):** `@MainActor` correctly applied to all UI-touching types (SettingsStore, OverlayManager, AppCoordinator, PauseConditionManager, ScreenTimeTracker). `async/await` used for notification center calls. One concern: `OverlayView` uses `DispatchQueue.main.asyncAfter` for animation callbacks — not a bug but mixes paradigms.

**DI (Good with one issue):** `AppCoordinator` init accepts all dependencies as optional protocol types — excellent. `OverlayManager.shared` singleton still exists (line 63) but is only used as a default; the coordinator injects it via `OverlayPresenting`. `MetricKitSubscriber.shared` is a true singleton — acceptable for a diagnostic service.

**Battery/performance (Excellent):** `ScreenTimeTracker` uses a 1-second Timer with 0.5s tolerance (coalescing-friendly). Grace period mechanism prevents unnecessary resets on brief interruptions. No polling or background processing. Audio session activated only during overlays. Reschedule debounce (300ms) prevents slider thrashing.


## Team Sync — 2026-04-25T04:35

**Corrections Validated:**
- Module graph, protocols, SPM structure, trigger model, AppConfig, onboarding all corrected
- Basher's DI design (ScreenTimeTracking, PauseConditionProviding injection) aligns with updated architecture
- Livingston's coverage analysis confirms Services layer strength (46%)

**Next:** ARCHITECTURE.md now authoritative for Phase 2 completion and Phase 3 planning


## Archive

### 2025-07-25 — Initial Architecture Scaffolding

Early architecture foundational work: Models, Services, ViewModels, DesignSystem scaffolding with all protocol, service skeleton definitions. Pre-Phase 1 architecture decisions. Preserved for reference; superseded by Phase 1-2 implementations and updated ARCHITECTURE.md audit (2026-04-25).

### 2026-04-26 — Quality Sweep: Architecture Review (Grade A)

**Quality sweep findings from 8-agent parallel audit:**

1. **OverlayManager singleton is dead code** — `static let shared` duplicates DI protocol. Coordinator is the only correct owner. Refactor post-Phase-1.

2. **SettingsView ViewModel box pattern needs refactoring** — `@StateObject` wrapping optional means `viewModel` is `nil` during first render, forcing optional chaining. Should construct in init or pass as parameter.

3. **Protocol extraction per ARCHITECTURE.md** — `SettingsPersisting`, `NotificationScheduling`, `MediaControlling` scattered across services. Recommend `Protocols/` directory for future discoverability (not urgent for Phase 1).

4. **Timer.publish more idiomatic** — `OverlayView` uses `Timer(timeInterval:repeats:)` + `RunLoop.main`. Consider `Timer.publish(...).onReceive` for iOS 16+ (suggestion, not blocking).

5. **Cross-cutting impact:** Linus audit identified SettingsView body decomposition as priority W-1. Coordinate with Linus on extraction strategy (Snooze section ~90 lines, Smart Pause section ~80 lines).

6. **Documentation stale:** ARCHITECTURE.md build instructions ("swift build / swift test") contradict README (xcodebuild required). Update Section 3 pre-submission.

**Next owner action:** Post-Phase-1, ~~remove OverlayManager singleton~~ ✅ Done (Issue #114) and refactor SettingsView ViewModel pattern.

### 2025-07-25 — Issue #114: Removed OverlayManager.shared singleton

**What I did:**
- Deleted `static let shared = OverlayManager()` from `OverlayManager.swift` (was line 63).
- Changed `AppCoordinator.init` default from `OverlayManager.shared` to `OverlayManager()` — each coordinator now owns a fresh instance, proper DI.
- Rewrote `OverlayManagerTests` to use `makeManager()` factory instead of `.shared`. Removed 2 singleton-identity tests (`test_shared_isNotNil`, `test_shared_returnsSameInstance`) that no longer apply. Eliminated `tearDown` that cleaned shared state.
- Updated doc comments in `AppCoordinator.swift` and `AppCoordinatorTests.swift`.
- All 38 OverlayManager + AppCoordinator tests pass. Build clean, zero warnings on changed files.

### 2026-04-26 — Issue #110: UI Test Architecture Proposal

**What I did:**
- Analyzed all 31 XCUITest methods across 4 files (`HomeScreenTests`, `OnboardingFlowTests`, `SettingsFlowTests`, `OverlayTests`) — all use `XCUIApplication` launch/query patterns incompatible with SPM test targets.
- Evaluated 5 options: minimal xcodeproj, full xcodeproj, ViewInspector, Xcode-generated project, Swift Testing macros.
- **Recommended Option 1: Minimal .xcodeproj containing only the UITest bundle target.** App and unit tests stay in Package.swift. Zero changes to existing test files.
- Ruled out ViewInspector — cannot test app launch, multi-view flows, overlay window presentation, or accessibility in rendered context. Would require full rewrite of all 31 tests.
- Ruled out Swift Testing — no XCUITest equivalent; irrelevant to the problem.
- Ruled out `swift package generate-xcodeproj` — deprecated/removed; Xcode's transient workspace doesn't support adding targets.
- Proposed CI integration: separate `ui-test` job in ci.yml (UI tests are slower and flakier than unit tests).
- Proposed `uitest` subcommand for `scripts/build.sh`.
- Estimated effort: 3-4 hours total across team.

**Documentation:** `.squad/decisions/inbox/rusty-ui-test-architecture.md`



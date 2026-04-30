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


## Project Context

- **Owner:** Yashasg
- **Project:** kshana (formerly Eye & Posture Reminder) — a lightweight iOS app with True Interrupt Mode via Screen Time APIs
- **Stack:** Swift, SwiftUI (iOS 16+), MVVM, UserNotifications, UIKit overlay, UserDefaults, FamilyControls (Phase 3+)
- **Created:** 2026-04-24


## 2026-04-29 — True Interrupt Mode Architecture & Test Strategy

**Task:** Update architecture and test strategy docs for True Interrupt Mode.  
**Status:** ✅ Complete — orchestration log filed

**Key deliverables:**
- **Four-target extension architecture:** Main app + DeviceActivityMonitor + ShieldConfiguration + ShieldAction
- **App Groups communication:** UserDefaults bridge (no shared memory, no direct calls)
- **ShieldConfiguration constraints:** Data-only, no animations. Static logo via custom SF Symbol is practical limit. YinYangEyeView impossible.
- **Graceful degradation:** Both Phase 2 (overlay) and Phase 3 (shield) coexist. Falls back to notifications if shield unavailable.
- **Distribution gating:** FamilyControls entitlement approval required for external distribution (case ID 102881605113)
- **Files updated:** ARCHITECTURE.md § 5.5, TEST_STRATEGY.md § 3.5 & 4.7 (EXT-01 through EXT-10 device tests)

**Key learnings:**
1. ShieldConfiguration is a data struct, not a view — no custom layouts/animations
2. Extensions cannot open main app directly — use App Group flag + deep-link notification
3. Simulator does not support Screen Time APIs — physical device testing mandatory
4. All Phase 3 code can be written locally immediately; external distribution blocked until approval

**Decision merged into `.squad/decisions.md`.**


## Learnings

- **SPM fundamentally cannot host XCUITest targets.** SPM's `.testTarget` creates XCTest unit test bundles only. XCUITest requires a UITest bundle target type (`com.apple.product-type.bundle.ui-testing`), which is an Xcode project concept with no SPM equivalent. This is an Apple toolchain limitation, not a configuration issue.
- **Minimal xcodeproj is the pragmatic bridge.** When an SPM-first project needs XCUITest, the lowest-maintenance solution is an xcodeproj that contains ONLY the UITest target, referencing the SPM-built app. Drift risk is minimal because the xcodeproj has no app target to keep in sync.
- **ViewInspector tests view structure, not rendered behavior.** It's a complement for view-level unit tests, not a replacement for flow-based UI tests that verify navigation, accessibility, and multi-screen interactions.
- **`swift package generate-xcodeproj` is dead.** Deprecated since Swift 5.6. Not a viable path for any tooling decisions going forward.

### 2026-04-26: Restful Grove Redesign — Full Architecture Review

**What I reviewed:**

Complete code quality and architecture review of the Restful Grove visual redesign (Issues #159–#167, Phases 1–4). Covered DesignSystem.swift (322 lines), Components.swift (182 lines), all view files, font integration, animation patterns, and MVVM compliance.

**Verdict:** Ready to merge. No critical issues. Two minor warnings (dead legacy radius tokens, SettingsView size at 556 lines).

**Key observations:**

- Design token architecture is solid: 9 semantic colors, 4 corner radii, 6 spacing values, well-documented with WCAG ratios
- 100% token adoption across all view files — zero hardcoded values escaped the QA pass
- AppFont/AppTypography dual-namespace pattern works well (facade + implementation) but needs a clarifying doc comment
- All animations properly guarded with `@Environment(\.accessibilityReduceMotion)` — consistent if/else pattern across 9+ files
- Dynamic Type fully supported via `.custom(name, size:, relativeTo:)` on all Nunito text styles
- Nunito font registration via CoreText is valid; Info.plist `UIAppFonts` is recommended but not required
- CalmingEntrance ViewModifier is a clean, reusable animation component with proper reduce-motion handling
- SoftElevation correctly adapts between light (shadow) and dark (border overlay) modes


## Learnings

- **Dual font namespaces (AppFont ↔ AppTypography) are maintainable when the facade layer is pure pass-through.** The key is to enforce a convention: define tokens in AppTypography, reference via AppFont at call sites. New contributors need a doc comment to understand this.
- **Legacy design tokens should be removed in the same PR that introduces replacements.** The `overlayCornerRadius`/`cardCornerRadius` → `radiusSmall`/`radiusCard`/`radiusLarge`/`radiusPill` migration left dead code. Always grep for usage before merging.
- **CoreText programmatic font registration is reliable for SPM bundle contexts.** `CTFontManagerRegisterGraphicsFont` works where Info.plist `UIAppFonts` cannot reference SPM `.module` bundle resources. This is the correct pattern for our project structure.
- **556 lines in a single view file is the monitoring threshold.** SettingsView is well-decomposed with private structs, but extraction to separate files should happen before it hits ~600 lines.
- **Final verification pass (2026-04-26): Restful Grove redesign is SHIP-READY.** 889 tests, 0 failures. Zero raw `Color.*` or system font literals in Views layer. All `withAnimation` and `.animation` calls are guarded by `reduceMotion`. Design token adoption is 100% across DesignSystem, Components, SettingsView, OverlayView, HomeView, and all Onboarding screens. `IconContainer.font(.system(...))` is the sole computed-size exception — intentional, since the icon scales relative to its container `size` parameter. Architecture is clean MVVM with protocol-injected dependencies.
- **SVG-to-SwiftUI-Path conversion via `addArc()` is cleaner than translating SVG `d` paths.** For geometric shapes like yin-yang, expressing the geometry as arc operations is more maintainable and readable than raw cubic bezier control points. Document the approach in ARCHITECTURE.md when introducing custom Shape conformers.
- **Phase-based animation state machines should use `@State` booleans with `DispatchQueue.main.asyncAfter` for sequencing.** SwiftUI's `withAnimation` doesn't natively support chained phases — the asyncAfter pattern is the established workaround. Always guard with `hasStarted` to prevent re-triggering on view re-render.

### 2026-04-27: YinYangEyeView Architecture Pattern Documentation

- **Context:** Documented the established architectural pattern for custom animated branding components in the app.
- **Decision:** `YinYangEyeView` uses custom SwiftUI `Shape` / `Path` drawing (not SF Symbols or image assets) with a two-phase animation state machine (Spin → Breathe).
- **Rationale:** Resolution-independent, direct design-token integration, per-layer animation control. Two-phase state machine sequences animations cleanly (SwiftUI lacks native chaining). Reduce-motion compliance via `@Environment(\.accessibilityReduceMotion)`.
- **ARCHITECTURE.md updates:** Documented pattern in §4.8. Any future custom animated branding components should follow the same Shape + phase-based approach.
- **Design tokens used:** Existing Restful Grove tokens (`AppColor.primaryRest`, `AppColor.surfaceTint`) — no new tokens introduced.
- **Decision artifact:** `.squad/decisions/inbox/rusty-yinyang-arch.md` → merged into decisions.md

### 2025-07-18: Battery Life & Performance Audit

- **Context:** Full battery/performance audit requested by Yashas. Reviewed all 33 Swift source files across Services, Models, ViewModels, Views, App, and Utilities layers.
- **Overall Grade: B+** — No critical battery drains. 3 minor warnings, 12 good practices confirmed.
- **Key Findings:**
  - ScreenTimeTracker timer (1s with 0.5s tolerance, pauses on background) is correctly implemented
  - All detection systems (Focus, CarPlay, driving) use event-driven patterns — zero polling
  - No UIBackgroundModes declared — app does zero work when suspended
  - Consistent `[weak self]` across all closures — no retain cycles found
  - All animations respect `accessibilityReduceMotion`
  - Startup path is clean: only 3 lightweight operations before first frame
- **3 Warnings (all P3/P4):**
  1. OverlayView countdown timer missing `tolerance` (1-line fix)
  2. YinYang breathing animation lacks `onDisappear` lifecycle control
  3. OnboardingView sets `UIPageControl.appearance()` in struct init (runs on every struct creation)
- **Artifacts:** `docs/performance-audit.md`, `rusty-issues.json` (15 findings)


## Learnings

- **Timer tolerance is a one-line battery optimization that should be standard practice.** Every `Timer` in the codebase should set tolerance to at least 10-20% of the interval. The ScreenTimeTracker does this (0.5s on 1s timer); the OverlayView countdown does not. Add tolerance wherever timers are created.
- **`.repeatForever` SwiftUI animations should always have lifecycle control.** Without `onDisappear` cleanup, the animation continues keeping the GPU compositor active even when the view is off-screen. For continuous animations, pair `onAppear` start with `onDisappear` stop.
- **`UIAppearance` proxy calls in SwiftUI struct `init()` are a code smell.** SwiftUI recreates structs frequently — appearance proxy calls should live in a `static let` initializer or `.onAppear` with a guard, not in the struct's `init`.
- **CMMotionActivityManager is the correct battery-efficient alternative to CLLocationManager for activity detection.** It runs on the dedicated motion coprocessor, not the main CPU or GPS hardware. This was validated as the right choice for driving detection in kshana.

**Apple Developer Setup Walkthrough (Rusty) — 2026-04-26:**
Provided step-by-step guide for Certificates, Identifiers & Profiles setup. Bundle ID confirmed as `com.yashasg.eyeposturereminder`. Capabilities needed: Push Notifications (for UNUserNotificationCenter), Focus Status Reading (entitlement already in .entitlements file). No App Groups, HealthKit, or Background Modes entitlements required. App uses SPM-only build (no .xcodeproj in main target). Developer will need to create Xcode project or use xcodebuild for archive/upload.


## 2026-04-28 — Apple Developer Portal Setup

**Session:** 2026-04-28T22:46:23Z (Rusty + Virgil parallel)

**Task:** Provide guidance on Apple Developer portal setup (Certificates, Identifiers & Profiles) for TestFlight/App Store submission workflow.

**Outcome:** ✅ Complete

**Deliverables:**
- Bundle ID finalized: `com.yashasg.eyeposturereminder`
- Capabilities guidance: Push Notifications + Focus Status entitlements
- Certificate type strategy: Apple Distribution for both TestFlight and App Store
- Provisioning profile guidance: Xcode Automatic Signing (dev), App Store provisioning profile (distribution)
- Xcode project note: SPM-only app may need explicit .xcodeproj for archive workflow

**Decision filed:** `.squad/decisions/decisions.md` — merged from inbox

**Coordination note:** Virgil identified Bundle ID case mismatch in UITests/project.yml. Unified guidance provided to yashasg: use `com.yashasg.eyeposturereminder` (lowercase) as single source of truth and align UITests before archive.


## Learnings

### 2026-04-28: iOS Platform Feasibility — Overlay-Over-Other-Apps Is Impossible

**Trigger:** User questioned why overlays only appear within kshana and not while using TikTok, Safari, etc.

**Core finding:** iOS does NOT allow App Store apps to display custom UI over other apps. There is no permission, no entitlement, no Settings toggle that enables this. The platform wall is absolute for regular App Store apps.

**What the current code does (and does NOT do):**
- `ScreenTimeTracker` (`EyePostureReminder/Services/ScreenTimeTracker.swift`) ticks ONLY while kshana is foreground-active. Timer stops the instant the user backgrounds kshana or opens another app.
- `OverlayManager` (`EyePostureReminder/Services/OverlayManager.swift`) creates a `UIWindow` inside kshana's process. Cannot reach over another app's window.
- `ReminderScheduler.scheduleReminders(using:)` (`EyePostureReminder/Services/ReminderScheduler.swift`) — the correct cross-app mechanism — is explicitly marked "never called in production" and "superseded." It was intentionally disabled in favour of foreground-only ScreenTimeTracker.
- `AppCoordinator.scheduleReminders()` (`EyePostureReminder/Services/AppCoordinator.swift`) calls `scheduler.cancelAllReminders()` then only configures ScreenTimeTracker. No `UNNotificationRequest` is ever scheduled for real cross-app delivery.

**The correct model for this app:**
1. **Local Notifications (`UNNotificationRequest`)** are the ONLY App Store-legal way to interrupt a user in another app. Banner appears over TikTok → user taps → kshana opens → overlay shows. This is the notification-tap-to-open path, which IS wired in `AppCoordinator.handleNotification()`. It just has no notifications feeding it.
2. Re-enable `ReminderScheduler.scheduleReminders(using:)` in production. Remove "superseded" status.
3. `ScreenTimeTracker` can supplement for foreground precision (wall-clock vs screen-time accuracy) but cannot be the sole trigger.

**Files requiring changes:**
- `Services/AppCoordinator.swift` — reinstate `scheduler.scheduleReminders(using:)`, remove `cancelAllReminders()` as the only scheduling action
- `Services/ReminderScheduler.swift` — remove dead-code comments, restore production path
- `Services/ScreenTimeTracker.swift` — keep for foreground precision, not sole trigger
- `Resources/Localizable.xcstrings` — audit `onboarding.welcome.body` ("Runs quietly — you'll barely notice it") against actual notification-tap UX

**Decision filed:** `.squad/decisions/inbox/rusty-ios-reminder-feasibility.md`

### 2026-04-28: Screen Time Shield Path — Correction to Prior Assessment

**Trigger:** User pushed back: "apps like LookAway do the exact thing" after we said overlay-over-other-apps is impossible.

**The correction:** Our prior statement was accurate but materially incomplete. We listed "Screen Time / Parental Controls" as "Apple-internal only." That was WRONG as of iOS 16. The FamilyControls framework + DeviceActivity + ManagedSettings (the "Screen Time Shield" path) IS available to third-party developers with entitlement approval. LookAway uses this path.

**How Screen Time Shield actually works:**
1. App registers `DeviceActivitySchedule` + threshold events (e.g., 20 minutes of total screen use)
2. `DeviceActivityMonitor` app extension fires when threshold reached
3. Extension calls `ManagedSettingsStore().shield.applicationCategories = .all()` (or specific apps)
4. iOS enforces a **system-managed full-screen shield overlay** — appears over the current app mid-session, or over any app the user tries to open
5. `ShieldActionExtension` handles button taps — can remove shield and reset the monitoring cycle

**What the shield IS and is NOT:**
- IS: A system-enforced, cross-app interrupt. Appears over the current foreground app. Survives app switches.
- IS NOT: Arbitrary custom SwiftUI drawn over another app. The shield UI is system-managed. You can customize: title, subtitle, primary/secondary button label text only. Background, button style, layout are all system-controlled. No custom animations.

**Entitlement requirements:**
- `com.apple.developer.family-controls` entitlement — requires manual Apple approval at developer.apple.com (NOT auto-granted)
- `AuthorizationCenter.shared.requestAuthorization(for: .individual)` — iOS 16+ mode for self-monitoring (not just parental control)
- 3 new app extension targets: `DeviceActivityMonitor`, `ShieldConfigurationExtension`, `ShieldActionExtension`
- App Groups entitlement for shared state between main app and extensions
- Requires `.xcodeproj` (extension targets cannot live in SPM Package.swift)

**App Store compliance for kshana:**
- Likely YES under `.individual` authorization mode (iOS 16+). Apple explicitly added `.individual` for self-monitoring wellness apps, not just parental controls.
- Other wellness/self-control apps (OpalApp, one-sec, Roots) have shipped using this path
- Still requires FamilyControls entitlement approval — Apple reviews use case; timeline not guaranteed

**MVP vs longer-term guidance:**
- **MVP (now):** Local Notifications — correct call, already partially wired, near-zero risk, days to ship
- **Phase 3+:** Screen Time Shield as "True Interrupt Mode" if Yashasg decides the product warrants it. Needs entitlement request filed with Apple as pre-work (weeks lead time).

**Correction to prior decision:** `rusty-ios-reminder-feasibility.md` should have its claim that Screen Time is "Apple-internal only" struck. All recommendations in that decision remain correct, but the omission of the Shield path was an error.

**Decision filed:** `.squad/decisions/inbox/rusty-screen-time-shield-path.md`

---

### 2026-04-29: Interrupt Mode Deep Proof — DeviceActivity + Screen Time Shield

**Trigger:** Yashasg directive: "local reminders are just noise, useless — look into interrupt mode more. If we can leverage Apple Screen Time API, good, but if the app is just setting screen time then it's a waste."

**Investigation scope:** All 8 product/architecture questions answered from first principles + web validation. No code written yet.

**Verdict: kshana CAN be genuinely more than a settings/reminder app.** The DeviceActivity + ManagedSettings Shield mechanism produces real, cross-app, system-enforced interrupts. The Shield appears over TikTok. The user cannot ignore it by swiping a notification banner. This is the correct long-term architecture for a health intervention tool.

**Key findings from deep investigation:**

1. **Recurring break interruptions: YES.** DeviceActivityMonitor extension fires on threshold (e.g., 20 min of total app use). Extension calls `ManagedSettingsStore().shield.applicationCategories = .all()`. Shield appears immediately over whatever app the user is in. Cycle repeats after break if monitoring is restarted. Known caveat: threshold delivery is system-batched — expect ±1-2 minute imprecision, not millisecond accuracy.

2. **FamilyActivityPicker not required for kshana's use case.** Shielding all apps (`ManagedSettingsStore().shield.applicationCategories = .all()`) and monitoring total device usage do NOT require user to pick specific apps via FamilyActivityPicker. The only required user action is the one-time FamilyControls system authorization sheet. Picker is only needed if tracking/shielding specific named apps.

3. **Temporary shield lift: achievable via ShieldAction pattern A.** User taps "Start Break" → ShieldAction extension removes shield + restarts DeviceActivity monitoring. No built-in auto-lift timer — the extension controls this. For a wellness app, trust-the-user Pattern A is correct. Hard-enforcement break timers (Pattern B) are parental-control territory.

4. **ShieldAction limits:** Primary + secondary button only. Text labels customizable. No custom SwiftUI. No custom background. Custom logo image IS supported (since iOS 16.1). Shield copy (title, subtitle) is attributed string — bold and foreground color supported.

5. **Total device use: YES, with caveats.** DeviceActivity can monitor cumulative time across ALL apps without FamilyActivityPicker. This is the right signal for eye breaks. What's impossible: detecting "eyes actually on screen vs phone face-up on desk," posture sensor data, lock screen interaction time, sub-1-minute precision.

6. **Engineering scope confirmed (Virgil's document is accurate):** 3 extension targets, App Groups, xcodeproj via XcodeGen, 4 provisioning profiles, 4 entitlements files. FamilyControls entitlement requires manual Apple approval — no SLA, typically days to weeks.

7. **Prototype spike plan:** ~5-6 hours of code. Throw-away project, 1-minute threshold for testability. 7 concrete success criteria. BLOCKED on FamilyControls entitlement approval — cannot validate shield behavior on device without it.

8. **App Store acceptance: high likelihood** under `.individual` mode for self-wellness. Opal, one-sec, Roots all approved. Use the exact wording from `rusty-interrupt-mode-proof.md` for the entitlement request. File today.

9. **Local notification guidance: KEEP as working fallback, NOT the product promise.** Notifications serve users who don't grant Screen Time permission and users who prefer gentle reminders. But the product identity is "break interrupt," not "notification reminder." Shield makes the identity real.

**Phase-gate criteria defined:** 5 gates (G1–G5) before Phase 3 Shield implementation is green-lit. G1 (entitlement approval) is the only external dependency — file immediately to start the clock.

**Immediate action items:**
1. File FamilyControls entitlement request at developer.apple.com/contact/request/family-controls-distribution — TODAY
2. Complete Phase 2 notification path in TestFlight
3. After entitlement approval: build spike project
4. After spike passes 7/7 success criteria: Virgil creates XcodeGen project.yml, Rusty wires ScreenTimeShieldManager

**Decision filed:** `.squad/decisions/inbox/rusty-interrupt-mode-proof.md`

**Learnings from this investigation:**
- `ManagedSettingsStore().shield.applicationCategories = .all()` does NOT require FamilyActivityPicker. FamilyActivityPicker is only for specific app token selection/monitoring. This is a common misconception in developer community answers.
- DeviceActivity threshold event timing is NOT reliable at sub-minute granularity in iOS 17/18. Community-confirmed drift of 30–90 seconds past threshold. Design features assuming "approximately N minutes" not "exactly N minutes."
- ShieldAction extension has limited background execution time (~30s). No heavy logic, no image loading, no network calls in extensions.
- DeviceActivity monitoring does NOT auto-repeat after threshold fires. You must explicitly call `DeviceActivityCenter.startMonitoring()` again after each break cycle. This is a sharp edge that causes many apps to fail their recurrence loop.
- FamilyControls `.individual` mode is Apple's deliberate policy expansion in iOS 16 for self-wellness apps. It is not a parental control workaround. Use `.individual` exclusively and state this clearly in the entitlement request.


## 2026-04-29T05:05:06Z: Interrupt Mode Pivot — Squad Orchestration

**Orchestration logs filed:**
- `2026-04-29T05-05-06Z-rusty-ios-overlay-feasibility.md` — overlay audit, decision corrected
- `2026-04-29T05-05-06Z-rusty-screen-time-shield-path.md` — complete viable architecture path
- `2026-04-29T05-05-06Z-rusty-interrupt-mode-proof.md` — deep proof + phase gates

**Session log:** `.squad/log/2026-04-29T05-05-06Z-interrupt-mode-pivot.md`

**Decisions merged:** All 9 inbox files → canonical `.squad/decisions/decisions.md`, inbox cleared.

---

### 2026-04-28: Shield UI Customization — Detailed Research (Yashasg question)

**Trigger:** Yashasg asked whether the animated SwiftUI `YinYangEyeView` can be used inside the Shield, whether a special entitlement is really required, and what it actually takes to implement Shield UI customization.

**Research summary:**

1. **What ShieldConfiguration can customize:**
   - Title text, subtitle text, primary button label, secondary button label — all iOS 16+
   - Custom background color (disables system blur) — iOS 17+ only
   - Background blur material — iOS 17+ only
   - Icon — SF Symbol only (iOS 16), or custom SF Symbol from asset catalog (iOS 17+ via `Image("symbolName")`)
   - Layout, font face, button style, animations — **completely locked, cannot be changed**

2. **YinYangEyeView in the Shield: Impossible.**
   - The Shield is a data struct (`ShieldConfiguration`), not a view canvas. No SwiftUI, no UIKit views, no animations can be injected.
   - Static logo IS possible as a custom SF Symbol: design the yin-yang geometry as an SVG following SF Symbols spec, import into `Assets.xcassets` as a Symbol Set (Xcode: New Symbol Image Set), reference via `Image("kshana.yinyang")`.
   - Custom PNG raster is NOT reliably supported — SF Symbol is the only safe path.
   - iOS 16 fallback: use a system SF Symbol (e.g., `circle.lefthalf.filled`).

3. **ShieldAction button handling:**
   - Primary + secondary buttons only. `.close` or `.defer` verdicts.
   - Extension CAN write to App Group shared container (pass data to main app).
   - Extension CANNOT directly open the main app via URL scheme.
   - Indirect "open kshana" path: write flag to App Group → schedule local notification with kshana:// deep link → user taps → kshana opens.
   - Network requests, DeviceActivity direct calls, complex logic: all blocked in extension sandbox.
   - "Start Break" → `.defer` + App Group flag. "Snooze" → `.defer` + snooze timestamp to App Group. "Skip" → `.close`.

4. **Frameworks involved:**
   - Main app: `FamilyControls`, `ManagedSettings`, `DeviceActivity`
   - Extension targets (3): `DeviceActivityMonitor`, `ShieldConfigurationExtension`, `ShieldActionExtension`
   - All targets share App Group entitlement

5. **Entitlement — why it's not self-service:**
   - `com.apple.developer.family-controls` is NOT a standard capability checkbox. Requires manual Apple approval via https://developer.apple.com/contact/request/screenshielding/
   - Apple screens for legitimate digital wellbeing / parental control use cases
   - Reason: Screen Time APIs can restrict any app on the device — Apple gates this to prevent stalkerware abuse
   - kshana's self-wellness use case qualifies under `.individual` mode

6. **Minimum spike to prove Shield UI customization:**
   - ~1 dev day, 3 new extension targets, physical device only (Simulator does not support Screen Time APIs)
   - Verify: custom title/subtitle, system blur background, primary "Start Break" button → App Group flag, secondary "Skip" → `.close`
   - BLOCKED until FamilyControls entitlement approved

**Decision artifact filed:** `.squad/decisions/inbox/rusty-shield-ui-customization.md`

**New learnings added:**
- Custom PNG raster images are NOT supported for ShieldConfiguration icon — SF Symbol or custom SF Symbol only
- iOS 17 adds `backgroundColor` and `backgroundBlurStyle` to ShieldConfiguration — iOS 16 is blur-only, no background control
- ShieldAction extension cannot open the main app directly — indirect path via App Group + local notification is the correct pattern
- Shield extension targets cannot live in SPM Package.swift — requires `.xcodeproj`

---


## Scribe Orchestration (2026-04-29)

**Action:** Orchestration log filed + decisions merged to canonical decisions.md

- Orchestration log: `.squad/orchestration-log/2026-04-29T05-19-56Z-rusty-shield-ui-customization.md`
- Session log: `.squad/log/2026-04-29T05-19-56Z-shield-ui-entitlement-research.md`
- Merged into: `.squad/decisions.md` — "Decision: Shield UI Customization — Data-Only, No Arbitrary Views Allowed"
- Inbox file deleted after merge

**Team impact:** Rusty's Shield UI research is now canonical reference for all team members. Team can review customization constraints and spike scope. Spike ready to execute immediately upon FamilyControls entitlement approval by Apple. Product decision on app-restriction feature should drive Phase 3 scheduling.

---


## 2026-04-28: True Interrupt Mode Architecture Documentation

**What I did:**
- Comprehensive architecture documentation for Phase 3+ True Interrupt Mode pivot
- Updated ARCHITECTURE.md with new §5.5 (10+ sections) covering FamilyControls + extension architecture
- Updated docs/TEST_STRATEGY.md with §3.5 extension mocks, §4.7 device-only tests, Phase 3 regression matrix
- Documented distribution gating, entitlement approval dependency, design constraints

**Key documentation added:**

1. **ARCHITECTURE.md §5.5.1–5.5.10:**
   - Two-mode interrupt strategy (overlay Phase 1-2, shield Phase 3+)
   - Four-target app extension architecture (main + 3 extensions)
   - FamilyControls authorization flow (one-time user prompt)
   - DeviceActivityMonitor extension entry point + ManagedSettingsStore API usage
   - ShieldConfiguration data-only limitations (text/icon/buttons only, no animations)
   - ShieldAction extension button handling + App Group communication patterns
   - Local notification fallback (Phase 2-3 bridge)
   - OverlayManager role in Phase 3 (fallback, not primary)
   - App Group state schema (11 keys defined)
   - Distribution gating: entitlement approval blocks external distribution

2. **TEST_STRATEGY.md §3.5 Extension Mocks:**
   - `MockManagedSettingsStore` — tracks shield application calls
   - `MockAppGroupUserDefaults` — isolated App Group state for testing
   - `MockAuthorizationCenter` — mocks FamilyControls auth without prompts
   - Extension target test structure with fixtures

3. **TEST_STRATEGY.md §4.7 Device-Only Tests:**
   - 10 manual test cases (EXT-01 to EXT-10)
   - Prerequisites (entitlement, physical device, SDK support)
   - Coverage: shield triggering, text rendering, button behavior, state sync, fallback, authorization denial, notification fallback, threshold repetition, snooze

4. **Phase 3 Regression Matrix:**
   - File change triggers for extension targets
   - Device-only requirement emphasized
   - Regression gate updates for CI

**Critical decisions documented:**
- Shield UI cannot host YinYangEyeView animation — data struct limitation
- Static logo via custom SF Symbol is the only visual customization
- Both Phase 2 overlay and Phase 3 shield can coexist (graceful degradation)
- FamilyControls entitlement required for all 4 targets
- Simulator does not support Screen Time APIs (physical device mandatory)
- Extension communication only via App Groups shared container
- ShieldAction cannot directly open main app — use local notification indirect path

**References established:**
- Apple case ID 102881605113 (pending entitlement approval)
- Entitlement request form: https://developer.apple.com/contact/request/family-controls-distribution
- Depends on Virgil's CI/CD provisioning profile setup for 4 targets × 2 signing modes

**Outcome:** Complete architecture reference for Phase 3+ implementation. Product team can now make informed decision on app-restriction feature scope. Dev team has clear spike definition and device test matrix. No code written; pure architecture + documentation.

---



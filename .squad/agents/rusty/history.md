# Project Context

- **Owner:** Yashasg
- **Project:** Eye & Posture Reminder — a lightweight iOS app with background timers and full-screen overlay reminders for eye breaks (20-20-20 rule) and posture checks
- **Stack:** Swift, SwiftUI (iOS 16+), MVVM, UserNotifications, UIKit overlay, UserDefaults
- **Created:** 2026-04-24

## Core Context

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

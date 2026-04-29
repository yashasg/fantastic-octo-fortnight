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

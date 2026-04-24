# Project Context

- **Owner:** Yashasg
- **Project:** Eye & Posture Reminder — a lightweight iOS app with background timers and full-screen overlay reminders for eye breaks (20-20-20 rule) and posture checks
- **Stack:** Swift, SwiftUI (iOS 16+), MVVM, UserNotifications, UIKit overlay, UserDefaults
- **Created:** 2026-04-24

## Learnings

<!-- Append new learnings below. Each entry is something lasting about the project. -->

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

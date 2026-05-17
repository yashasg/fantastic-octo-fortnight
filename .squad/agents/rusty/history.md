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

**## Pre-May-2026 Summary (Consolidated from 100+ entries)**
- **Architecture Foundation (2026-04-24):** Comprehensive protocol-based architecture documented in ARCHITECTURE.md; MVVM + UIWindow overlay + UserDefaults; iOS 16.0 minimum; 85% coverage target.
- **Telemetry Strategy (2025-07-25):** Tiered approach — Phase 1: Instruments only; Phase 2: os.Logger + MetricKit; Phase 3+: no third-party analytics. App battery efficiency grade A+.
- **TestFlight Telemetry (2025-07-25):** os.Logger moved to Phase 1 (TestFlight needs context logs); MetricKit moved to Phase 2 (payloads available on beta builds); Xcode Organizer crashes work from first build.
- **MPRemoteCommandCenter Placement (2025-07-25):** Phase 2 opt-in feature, not Phase 3 — 30-line `AudioInterruptionManager`, low complexity; never use `UIBackgroundModes: audio` without actual audio playback.
- **Services Scaffold (2025-07-25):** All model, protocol, and service skeletons completed: ReminderType, ReminderSettings, SettingsStore (UserDefaults wrapper), ReminderScheduler, OverlayManager, AudioInterruptionManager, SettingsViewModel, Logger+App.
- **Key architectural decisions:** MVVM pattern; UIWindow overlay for reliability; protocol abstractions for testability; UserDefaults for 5 scalars; iOS 16.0+; no background modes.
- **Open questions resolved:** Landscape support deferred (Portrait-lock for health intervention); Do Not Disturb mode will dismiss overlay per health-app UX pattern; presets-only intervals confirmed for Phase 1.

---

## 2026-05-15 — Release-Config CI Compatibility Audit (kshana / EyePostureReminder)
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

### 2026-05-04: #462 Phase A Micro-slice — OnboardingView Accessibility Poster Factory Seam

- **Architecture decision:** Removed eager concrete construction from `OnboardingView` by resolving `AccessibilityNotificationPosting` via optional injection plus fallback factory.
- **Pattern:** For DI/SRP micro-slices, keep API behavior stable with `Dependency? = nil` + `makeDependency` factory and verify fallback/bypass in focused unit tests.
- **User preference captured:** Continue Ralph loop in tiny, surgical slices with behavior preservation and explicit build/test validation.
- **Key file paths:** `EyePostureReminder/Views/Onboarding/OnboardingView.swift`, `Tests/EyePostureReminderTests/Views/OnboardingViewTests.swift`, `.squad/decisions/inbox/rusty-onboarding-poster-factory-seam.md`.

---

## 2026-05-14 — Apple Developer Support Reply: Reviewer-Approved, Pending Send

**Status note:** Danny (PM) drafted, Frank (Legal) reviewed and approved with minor edits. Final send-ready reply merged to `.squad/decisions.md`. Yashas will send to Johnny at Apple (case 102881605113).

**Key decision:** Reply frames FamilyControls/DeviceActivity/ManagedSettings entitlements as *only* sanctioned path to core product feature (enforceable break-time boundaries), not optional add-on. Business justification: TestFlight → App Store gating; delay impacts user acquisition, credibility positioning as Digital Wellbeing tool, team resource allocation.

**Reusable pattern documented:** Apple correspondence approach (product narrative + distribution impact + sanctioned-only signaling + offer to escalate) now in decisions for TestFlight/App Store appeals, future entitlements.


## 2026-05-14 — Apple Reply v2 Current Send-Ready Draft (case 102881605113)

**Update:** v1 apple reply draft approved by Frank has been superseded by v2 (plain-prose rewrite) per user feedback.

**Status:** v2 is now current send-ready draft. Substance identical to v1; formatting/voice only changed from markdown-heavy structure to natural plain prose (no labeled sections, no markdown syntax).

**Why:** Yashasg rejected v1 for sounding "AI-generated" due to markdown formatting and labeled section headers. v2 preserves all factual claims and legal review; only the writing style changed to sound authentically human.

**Next step:** Awaiting Yashas to review v2 and send to Apple (case 102881605113).

---

## 2026-05-14 — Product Behavior: Break Shielding Focus/Driving Mode Suppression

**Date:** 2026-05-14  
**Source:** Apple Developer Support reply (case 102881605113) sent to Johnny  
**Captured Behavior:** kshana suppresses break shielding when iOS device is in Focus Mode or Driving Mode  

**Product Implication:**
The app respects user-defined system DND contexts. Wellness breaks are *offered*, never forced during user-signaled quiet time.

**Architecture Constraint (for future decisions):**
- The app MUST NOT shield apps when the device is in Focus Mode or Driving Mode
- This is an active product behavior, not a bug or edge case to ignore
- Any future architecture changes (e.g., new timer logic, new entitlement usage) must preserve this constraint
- Triage and feature decisions should factor in: "Does this break the focus/driving mode suppression?"

**Reuse Cases:**
- Product roadmap: Focus-mode awareness is a core differentiator vs. generic break reminders
- Future App Review appeals: "kshana respects user-defined iOS system signals — not invasive"
- Marketing: "Digital Wellbeing alignment — respects Focus Mode and Driving Mode"
- Testing & validation: Test scenarios must include focus/driving mode toggles

**Related Decision:** See `.squad/decisions.md` → "Apple Developer Support Reply — Sent" entry for full context.


## 2026-05-14: Google Swift Style Guide Adopted (Audit #646)

**Event:** Full-codebase audit completed. Google Swift Style is now canonical for all new work. Baseline: 53 files, 9,164 LOC audited across Views/ViewModels (Linus), Services/Utilities (Basher), App/Models (Saul).

**Key for Rusty:** Future architecture decisions should respect Google Swift Style, particularly in these high-impact rule areas per the audit:
1. **Doc comments on public API:** Services audit found 6 missing doc comments on public singletons and methods. Set this as expectation for any new service layer work.
2. **Access-control discipline:** One file-level extension access control violation (AppCoordinator.swift:657) and one access-level leak (AppCategoryPickerView:139). Emphasize: Use explicit member-level access modifiers; never file-level on extensions. Verify public computed properties are truly public.
3. **Column-limit / line-wrapping:** 25 violations in Views. When reviewing PRs, flag lines >100 chars and require wrapping per Google's line-wrapping rules (Section 5.4).

**Related:** GitHub Issue #646 contains full audit findings, violation tracker, and remediation roadmap. Branch: chore/coding-standards-audit.

**Reuse:** When making architecture decisions (DI protocols, service abstractions, API boundaries), mention Google Swift Style conformance as a design criterion.


- 2026-05-15: Team now has explicit frontend/backend/devops/product team grouping. See `.squad/team.md` "## Teams" section. Frontend (Linus/Livingston/Saul), Backend (Basher/Yen/Benedict), DevOps (Virgil), Product (Danny/Tess/Reuben/Turk/Frank/Roman), Cross-cutting (you). Routing decisions now respect layer ownership; coordinate architecture across team boundaries.

---

## Session: Deconflict #677 Issue Scope (2024)

### Context
Issue #677 ("Decommission legacy MVVM types — PHASE 2") was an umbrella tracking the full Phase 2 MVVM-to-TCA migration work. Two sub-issues (#701 and #702) were subsequently carved out and deferred to unblock parallel engineering:
- #701: SettingsStore ObservableObject strip (blocks on TCA Dependencies mutable access)
- #702: View migrations + AppCoordinator reference erasure (blocks on TCA reducer stabilization)

### Decision
Rewrote #677's issue body to clearly delineate residual scope vs. deferred work:

**Residual #677 scope:**
- AppCoordinator stack deletion (5 files, 1,351 LoC)
- SettingsViewModel deletion (451 LoC + tests)
- SelectedAppsState ObservableObject strip

**Deferred to #701 & #702** (full sub-issue specs already written)

**Rationale:** Scope ambiguity creates friction during review and parallel work. An umbrella's body must always reflect current state, not the initial vision. The pattern here—"umbrella-with-deferrals body update"—works for future TCA migration phases.

### Learnings
- **2026-05-15: Team consolidation — 7 teams collapsed to 2 (Dev + Strategy).** You are now explicitly on the **Dev team** alongside Rusty, Linus, Livingston, Saul, Basher, Yen, Benedict, Virgil. Dev team owns code, tests, build, and CI. Strategy team (Danny, Tess, Reuben, Turk, Frank, Roman, Toulour, Denham, Sponder, Bashir, Matsui, Bruiser) handles product, design, research, legal, audits, and ASO. Scribe and Ralph remain on the roster outside both teams (silent infra). Use GitHub label `team:dev` for issue routing; see .squad/streams.json for canonical Dev workstream folder scopes.
1. **Umbrella issues need live-updating bodies.** When sub-issues are carved out post-filing, update the parent to avoid reviewer confusion. A stale umbrella body is a source of ground-truth conflicts.
2. **Deferred sub-issues require explicit links.** The new body calls out #701 and #702 by number and one-line scope, so context is immediate.
3. **Residual scope must be quantified.** Line counts + file lists make it clear what work remains and allow reviewers to spot scope creep.
4. **This pattern reusable for Phase 3 & beyond.** As the TCA migration continues, new umbrellas will accrue deferrals—standardize the body structure (Scope, Deferred To, Pre-requisites, etc.) to keep navigation consistent.

---

---

## Session: Split Issue #735 by File Ownership (2025-05-16)

### Context
Issue #735 bundled two related docs-drift issues (`ROADMAP.md` and `UX_FLOWS.md`) that describe the project's current architecture as MVVM/AppCoordinator-orchestrated, when that pattern is being decommissioned post-Phase 2 TCA migration. However, the two files have different team owners:
- **ROADMAP.md**: Product narrative & milestones (squad:rusty territory)
- **UX_FLOWS.md**: Engineering behavior contracts & flow diagrams (squad:saul/Frontend territory)

### Decision
Split #735 into two sibling issues by file ownership:

**#741** (`ROADMAP.md`, Product)
- Owned by squad:rusty (architect closest to Product)
- L6 header rewrite + Phase-3+ bullets re-anchored from MVVM to TCA
- Same blocker pattern (#677, #701, #702)
- Same priority (p2) and sweep scope (alongside #725)

**#742** (`UX_FLOWS.md`, Frontend Engineering)
- Owned by squad:saul (Frontend code reviewer, would review rewrite anyway)
- Flow diagrams (§2.x, §6.x, §6.7, §8.x) re-drawn from AppCoordinator methods to Store reducers
- ContentView paragraph updated to reflect TCA state-driven onboarding
- Same blocker pattern and priority

**#735** marked as "Superseded by #741 + #742" with banner + original body preserved as tombstone. Added explanatory comment; left open per team convention (owner closes when ready).

### Learnings
- **2026-05-15: Team consolidation — 7 teams collapsed to 2 (Dev + Strategy).** You are now explicitly on the **Dev team** alongside Rusty, Linus, Livingston, Saul, Basher, Yen, Benedict, Virgil. Dev team owns code, tests, build, and CI. Strategy team (Danny, Tess, Reuben, Turk, Frank, Roman, Toulour, Denham, Sponder, Bashir, Matsui, Bruiser) handles product, design, research, legal, audits, and ASO. Scribe and Ralph remain on the roster outside both teams (silent infra). Use GitHub label `team:dev` for issue routing; see .squad/streams.json for canonical Dev workstream folder scopes.

1. **Split bundled docs-drift issues by file ownership.** When a docs issue spans multiple files with different team owners, splitting by file (not by aspect or urgency) yields clearer accountability and review gates. The pattern: Extract file-specific evidence, AC, and Refs into each child; keep parent as tombstone.

2. **Docs-drift blockers and timelines cross team boundaries.** Both ROADMAP.md and UX_FLOWS.md drift is triggered by the same in-flight work (#677, #701, #702). Coordinating fix timing ensures all four canonical docs (ARCHITECTURE.md, IMPLEMENTATION_PLAN.md, ROADMAP.md, UX_FLOWS.md) transition together from MVVM-era to TCA-era in a single sweep PR. This avoids "piecemeal docs updates" antipattern.

3. **Tombstone parent issues clarify intent.** By prepending a banner to #735's body ("Superseded by #741 + #742") and adding an explanatory comment, future readers see the split rationale and can navigate the family without confusion. Leaving the parent open (vs. closing immediately) respects the owner's privilege to decide when the family is "done."

4. **Reuse this split pattern for future docs sweeps.** The decomposition logic (identify team boundaries, extract evidence by file, preserve blockers & priority in children) is generalizable. Next time a bundled docs issue spans Frontend/Backend/Product, apply the same split-by-ownership template.

### Refs

New issues: #741 (ROADMAP.md), #742 (UX_FLOWS.md)
Parent issue: #735 (now superseded, kept as tombstone)
Related: #725 (parent docs sweep), #677, #701, #702 (blockers)

## 2026-05-15 — New Strategy & Compliance Team Established

2026-05-15: New Strategy & Compliance team added (6 members: Toulour/Denham/Sponder/Bashir/Matsui/Bruiser). They file issues; remediation routes to existing dev/test/review team. See team.md and routing.md.

## Learnings

### 2026-05-15 — Release-Config CI Compatibility Audit (kshana / EyePostureReminder)

**Project architecture note:** Main app is a Swift Package (Package.swift executableTarget), NO main xcodeproj. Unit tests run via `xcodebuild test -scheme EyePostureReminder`. UITests use `UITests/EyePostureReminderUITests.xcodeproj`.

**Release-config compatibility findings:**

1. **`#if DEBUG` is the dominant risk pattern.** The codebase correctly uses `#if DEBUG` to gate UITest backdoors out of production (per #350/#405 settings-reset vulnerability). This same gate covers test-critical hooks:
   - `UITestMode.swift` — entire implementation (launch-arg parsing) is `#if DEBUG`. UITests completely broken under Release.
   - `AppDelegate.swift` — `preSeedUITestDefaults()`, `applyUITestLaunchArguments()` both `#if DEBUG`. UITest seeding broken.
   - `EyePostureReminderApp.swift` — three pre-seed/injection methods all `#if DEBUG`. Onboarding and overlay UITests broken.
   - `HomeView.swift` — AppStorage property + two helper methods `#if DEBUG`. Screen time simulation broken.
   - `AnalyticsLogger.swift` — `testEventHandler` hook `#if DEBUG`. 3 unit tests fail at runtime (empty captured-events array).

2. **`@testable import` scope:** 105 `@testable import` usages across 97 test files, targeting `EyePostureReminder` and `ScreenTimeExtensionShared`. For SPM, `ENABLE_TESTABILITY=YES` in the xcodebuild command is required and sufficient — xcodebuild propagates it through the SPM target graph.

3. **Test files with `#if DEBUG` guards:**
   - `HomeViewLaunchContextResolverTests.swift` — ENTIRE class (12 tests) inside `#if DEBUG`. Silent test drop, not a failure.
   - `AppDelegateTests.swift` — 1 test method inside `#if DEBUG`. Silent drop.
   - `SettingsStoreSeedTests.swift` — 1 test method has `#if DEBUG / #else XCTSkip`. Will XCTSkip under Release.

4. **Assertions:** `assert()` at OverlayManager.swift:316 and `assertionFailure()` at AnalyticsLogger.swift:373 become no-ops under Release. Neither causes test failures but both guard real invariants — recommended to convert to `precondition`/`preconditionFailure`.

5. **Zero risk categories:** No `@inline`, `@inlinable`, `@_transparent`, `@_optimize`, `unowned`, or `withUnsafePointer` usages in app/extension code. No Swift Testing (`@Test`) macros. `#Preview` blocks are unguarded but compile fine in all configurations. OSLog usage is test-safe.

6. **SPM and custom configurations:** SPM has no xcodeproj for the main target. Custom compilation conditions can be injected via `OTHER_SWIFT_FLAGS="-DCI"` in the xcodebuild invocation — this flows through to SPM target builds and makes `#if CI` active in source. Only activate on test/build-for-testing commands, never on production builds.

**Recommended pattern — `#if DEBUG || CI`:** Replace all 22 `#if DEBUG` guards covering test infrastructure in the 5 app files listed above. The `CI` flag is set only on CI test xcodebuild calls, keeping production binaries clean. This is the minimal-change, secure approach for SPM-based projects.

**Configuration strategy decision:** Option (b) — CI-derived config via `OTHER_SWIFT_FLAGS="-DCI"` on top of `-configuration Release`, NOT plain Release (breaks tests) and NOT Debug+WMO (misses `-O` goal). ~25 lines changed across 5 files.

**Pre-flight source change checklist:**
- `UITestMode.swift` — `#if DEBUG` → `#if DEBUG || CI` (1 block)
- `AppDelegate.swift` — `#if DEBUG` → `#if DEBUG || CI` (3 blocks)
- `EyePostureReminderApp.swift` — `#if DEBUG` → `#if DEBUG || CI` (3 blocks)
- `HomeView.swift` — `#if DEBUG` → `#if DEBUG || CI` (3 blocks)
- `AnalyticsLogger.swift` — `#if DEBUG` → `#if DEBUG || CI` (2 blocks)
- `HomeViewLaunchContextResolverTests.swift` — `#if DEBUG` → `#if DEBUG || CI` (1 guard, recovers 12 tests)

**Sign-off gate:** All 1985+ tests must pass; UITest shards all green; coverage ≥ 80%; confirm `-DCI` NOT present in production archive build settings.

## 2026-05-17 — Release-Config CI Compatibility Audit (COMPLETED)

Orchestration log written: `.squad/orchestration-log/2026-05-17T08-57-37Z-rusty.md`. Audit completed; blocking call issued.

### Key Findings

**HIGH-severity blockers identified:**

| Category | Count | Severity | Root Cause |
|---|---|---|---|
| `#if DEBUG` — UITest backdoors in 5 app files | 22 total | **High** | Security model correctly gates test hooks; same gate breaks Release config. |
| `@testable import` + ENABLE_TESTABILITY | 105 usages | **High** | SPM Release default is `ENABLE_TESTABILITY=NO`; test compilation fails. |
| UITest xctestrun PlistBuddy hardcoding | 1 path | High | build.sh line 663 hardcodes `Debug-iphonesimulator`. |
| `#if DEBUG` in test files (silent drops) | 3 | Med | 12 tests silently disappear; 1 test method drops; 1 XCTSkips. |

**Zero-risk categories:** No `@inline`, `@inlinable`, `unowned`, `withUnsafePointer`, Swift Testing macros, or optimizer-sensitive code patterns found.

### Decision & Blocking Call

**Issued: HIGH-severity blocking call.** Release-config CI switch WILL BREAK 3 unit tests + entire UITest suite without coordinated source changes.

**Recommended strategy: Option (b) — CI-derived config via `OTHER_SWIFT_FLAGS="-DCI"` on test xcodebuild only.**

Source changes required (~25 lines, 5 files):
- Replace `#if DEBUG` → `#if DEBUG || CI` in: UITestMode.swift, AppDelegate.swift, EyePostureReminderApp.swift, HomeView.swift, AnalyticsLogger.swift
- Optionally recover 12 silent-drop tests: add guard to HomeViewLaunchContextResolverTests.swift

**Pre-flight gate (HARD):** Source changes must land and pass green on current Debug CI baseline BEFORE Virgil's Release-config CI diff merges.

### Decision Merged

Release-config compatibility decision merged into `.squad/decisions.md` as part of phased CI optimization plan. Skill document written: `.squad/skills/release-config-ci-audit/SKILL.md`.

### Status

Awaiting: (1) Yashas approval to proceed; (2) Source changes PR submission + review; (3) Green validation on Debug baseline; (4) Release-config CI switch (Virgil).

### Learnings

- **2026-05-17: Release-config audit pattern for SPM-based projects.** For any SPM project (no xcodeproj) considering Release config switch: (1) audit all `#if DEBUG` guards for test-critical code, (2) verify `@testable import` count + ENABLE_TESTABILITY impact, (3) check for hardcoded build-artifact paths (e.g., PlistBuddy), (4) recommend `OTHER_SWIFT_FLAGS="-DCI"` injection mechanism for CI-only test hooks.
- **Compilation condition injection in SPM:** Use `OTHER_SWIFT_FLAGS="-DCI"` in xcodebuild invocation — flows through to SPM targets and enables `#if CI` checks. This is the only mechanism for custom conditions in SPM without adding a real xcodeproj or config.
- **Security gate + test infrastructure coupling:** When `#if DEBUG` guards security-sensitive code (UITest backdoors), ensure test-critical hooks are NOT within the same guard. Either extract hooks to separate `#if CI` guard, or widen guard to `#if DEBUG || CI` when safe. This decouples security (production cleanliness) from test requirements (debug features for CI).

## 2026-05-17 — #if DEBUG Blocker Scope Narrowed (UI Tests Off CI)

**Event:** User directive captured — UI tests disabled on CI until TCA rewrite ships (Work Item #806 filed by Livingston).

**Scope Update:** The 22 `#if DEBUG` guards identified in the Release-config audit split into **two buckets:**

| Bucket | Guards | Affected Tests | CI Impact | Status |
|---|---|---|---|---|
| **UITest-specific** (UITestMode, AppDelegate UITestArgs, EyePostureReminderApp UITest hooks, HomeView UITest backdoors) | ~9 | UI test suite (~500 tests) | ✅ No longer a CI blocker (UI tests off CI) | Not in scope now |
| **Unit-test-affecting** (AnalyticsLogger injection + 14 `#if DEBUG`-wrapped test files) | ~13 | 3 unit tests + 12-14 silently-dropped tests | Still blocks Release CI baseline | Still a blocker |

**Key Implication:** Blocker shrinks from "22 guards breaking UITests + unit tests" to "AnalyticsLogger + unit-test files" (~13 guards) — narrower scope, same `#if DEBUG → #if DEBUG || CI` fix pattern. No change to the sign-off gate or pre-flight checklist.

**Timeline:**
1. UI tests stay off CI during TCA rewrite work (Work Item #806, assigned to Livingston)
2. Once TCA rewrite ships + re-enable gate cleared, UITest guards will need `#if DEBUG || CI` updates IF/WHEN we bring UI tests back to Release-config CI (future decision)
3. For immediate Release-config CI switch: focus on AnalyticsLogger + unit-test files only

**Related Decision:** `.squad/decisions.md` — "2026-05-17 — User Directive: UI Tests Disabled on CI Until TCA Rewrite"

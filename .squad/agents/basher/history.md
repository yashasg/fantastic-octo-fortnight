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

## 2026-04-29T05:05:06Z: Squad Orchestration — Interrupt Mode Pivot

**Orchestration logs filed:**
- `2026-04-29T05-05-06Z-basher-background-reminder-audit.md` — P0 audit findings
- `2026-04-29T05-05-06Z-basher-restore-hybrid-reminders.md` — hybrid model implementation, commit aa7be3e

**Session log:** `.squad/log/2026-04-29T05-05-06Z-interrupt-mode-pivot.md`

**Decisions merged:** All 9 inbox files → canonical `.squad/decisions/decisions.md`.

## 2026-04-29 — #204 Unblocked Compile-Safe Slice (Basher + Linus)

**Issue:** #204 M3.4 FamilyControls Authorization & App/Category Picker UI
**Branch:** `squad/m3-true-interrupt-mode`

### New service/model files
- **`ScreenTimeAuthorizationProviding.swift`** — `ScreenTimeAuthorizationStatus` enum (4 cases, all `Sendable`) + `ScreenTimeAuthorizingProviding` protocol. No `FamilyControls` import. `localizedStatusKey` property drives Settings status row copy.
- **`ScreenTimeAuthorizationNoop.swift`** — Pre-entitlement noop. Always returns `.unavailable`. Default injected by `AppCoordinator`.
- **`SelectedAppsState.swift`** — `@MainActor ObservableObject`. App Group `UserDefaults` (`group.com.yashasgujjar.kshana`). Stores `SelectedAppsMetadata` (categoryCount, appCount, lastUpdated — `Codable`, no opaque FamilyControls tokens). Init accepts any `UserDefaults` for test isolation.
- **`AppCoordinator`** — Added `screenTimeAuthorization: ScreenTimeAuthorizingProviding` (injectable, default `ScreenTimeAuthorizationNoop()`).

### Test files
- `MockScreenTimeAuthorizationProviding.swift` — call-recording mock with `stubbedStatus`, `stubbedRequestResult`, `reset()`.
- `ScreenTimeAuthorizationTests.swift` — 17 tests: noop behaviour, enum raw values, `localizedStatusKey` stability, mock call recording.
- `SelectedAppsStateTests.swift` — 18 tests: `SelectedAppsMetadata` codability/equality, `SelectedAppsState` init/persistence/reinit. All use isolated `UserDefaults` suites.

### Persistence constants (stable — shared with extension targets)
- App Group: `group.com.yashasgujjar.kshana`
- Enabled key: `trueInterrupt.enabled`
- Metadata key: `trueInterrupt.selectionMetadata`

### Build verified: `./scripts/build.sh test` → ✓ Tests passed (35 new tests)

## 2026-04-30 — Services/Lifecycle Read-Only Audit (post-#299)

### Audit Scope
Services: AppCoordinator, ReminderScheduler, ScreenTimeTracker, OverlayManager, PauseConditionManager, ScreenTimeAuthorizationNoop, WatchdogHeartbeat, AppGroupIPCStore, SettingsViewModel, SelectedAppsState, ScreenTimeExtensions/Shared.

### P0 Finding: #306 — readEventsCombined throws hard on corrupt legacy eventLog key

**Root cause:** `readEventsCombined` (introduced in #299 commit a520be3) throws `StoreError.corruptEventLog` when the legacy `trueInterrupt.ipc.eventLog` key is corrupt. Per-slot corrupt entries are silently skipped (consistent behavior). Since `clearEvents()` has no production call site, a corrupt legacy key permanently blocks `readEvents()` and therefore `recoverStaleDeviceActivityWatchdogIfNeeded`. Watchdog recovery returns `false` on any `readEvents()` error.

**Fix:** Downgrade `throw StoreError.corruptEventLog` in the legacy read path to a warning log + continue, consistent with per-slot skip behavior.

**Owner:** Tess (squad:tess) — reviewer-lockout on #299 artifact.

**Issue filed:** #306

### All other service paths clean
- ScreenTimeTracker: stale-tick race fixed (tickingGeneration, commit 587bf38); resetTask cancel-before-reassign confirmed fixed (from #118)
- AppCoordinator: snooze guard path correct; notificationAuthStatus refreshed before snooze gate in scheduleReminders()
- PauseConditionManager: focusMode initial state seeded (from #119)
- OverlayManager: scene-activation drain observer present (from #133)
- WatchdogHeartbeat: per-slot writes are cross-process safe (#299)
- pruneEventSlots: counts only slot keys (not legacy), slight inaccuracy when legacy events exist — self-corrects, not critical
- Snooze/cancel behavior correct in SettingsViewModel; cancelAllReminders() snooze-wake path uses last-known notificationAuthStatus (pre-existing, no new issue)

## 2026-04-30 — PR #411 CI segv triage (SettingsStore)

- Reproduced CI-style failures locally as `Test crashed with signal segv` in `SettingsStoreTests` (not assertion failures).
- Root cause: mutating `@Published` break-duration properties from inside their own `didSet` caused unstable test-runner crashes under Xcode 26.4 simulator runs.
- Fix: moved eyes/posture break durations to private published storage + validated computed setters, preserving validation/persistence behavior without self-assignment in observers.
- Validation: targeted failing classes now pass; full `./scripts/build.sh test` passes; `./scripts/build.sh build` and `./scripts/build.sh lint` pass.

## 2026-04-30 — SettingsStore recursion fix implemented (Scribe update)

Orchestration log recorded at 2026-04-30T09:27:10Z. Fix approved and documented in decisions.md:
- Commit `04f73cd`: Implemented backing-storage + computed-setter pattern
- Eliminates recursive @Published self-assignment in eyesBreakDuration and postureBreakDuration
- Local validation: lint, build, test all passing
- Preserves validation, persistence, UI reactivity, and API surface
- Ready for merge — awaiting final CI validation

## 2026-04-30 — #354 Focus entitlement parity for distribution

- Fixed App Store/TestFlight capability drift by adding `com.apple.developer.focus-status = true` to `EyePostureReminder.Distribution.entitlements`.
- Added regression coverage in `DistributionEntitlementsTests` to assert the distribution entitlement file keeps Focus status enabled.
- Validation: `./scripts/build.sh all` passed after change (build + lint + tests).

## Learnings

- For service callbacks consumed by `@MainActor` coordinators, declare callback properties as `@MainActor` function types at the protocol boundary (e.g., `(@MainActor (ReminderType) -> Void)?`) to get compile-time isolation guarantees and remove `MainActor.assumeIsolated` crash traps.
- Conforming mocks/no-op stubs must match the actor-annotated callback signatures; this keeps tests compile-safe while preserving behavior.

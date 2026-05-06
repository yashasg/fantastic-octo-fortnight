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

## 2026-05-04T00:20:00Z: #462 Phase A — AppDelegate Optional Notification Factory Seam (COMPLETED)

- Slice: updated `AppDelegate` to use an optional `makeNotificationCenter` factory seam resolved in `init`, preserving default `UNUserNotificationCenter.current()` behavior while removing eager concrete default-argument coupling.
- Validation: `./scripts/build.sh build` ✅ and `./scripts/build.sh test` ✅ (2053 tests, 0 failures).
- Scope: `EyePostureReminder/App/AppDelegate.swift`, `Tests/EyePostureReminderTests/Services/AppDelegateTests.swift`.

## Learnings

- For AppDelegate notification delegate wiring, prefer `makeNotificationCenter: (() -> UserNotificationCenterDelegating)? = nil` and resolve fallback once in `init`; this keeps production singleton behavior while enabling explicit nil-factory seams and bypass assertions in tests.
- Keep AppDelegate seam tests surgical: one test for factory-used when `notificationCenter` is nil, and one test for explicit-center-bypasses-factory.
- User preference reinforced: continue #462 with tiny DI/SRP micro-slices only, each validated with full `./scripts/build.sh build` and `./scripts/build.sh test`.
- Key file paths: `EyePostureReminder/App/AppDelegate.swift`, `Tests/EyePostureReminderTests/Services/AppDelegateTests.swift`, `.squad/skills/notification-center-factory-seam/SKILL.md`.

## 2026-05-04T00:17:02Z: #462 Phase A — Micro-slice Orchestration (COMPLETED)

**Phase A Micro-slice Delivery:**
- **Branch:** basher/462-phasea-appdelegate-optional-notification-factory
- **Commit:** c7f6f9c4afce8779f889f7f0fcc56e9a9e098f92
- **PR:** https://github.com/yashasg/fantastic-octo-fortnight/pull/591

**Three Seams Delivered:**
1. **AppDelegate Notification Center Optional Factory Seam** — `makeNotificationCenter: (() -> UserNotificationCenterDelegating)? = nil` with precedence-ordered resolution (explicit notificationCenter, explicit factory, production fallback)
2. **AppDelegate Launch Arguments Provider Seam** — `launchArgumentsProvider: () -> [String]` closure with fallback to `{ CommandLine.arguments }`, enables deterministic test coverage of provider fallback path
3. **AppDelegate UI-test Overlay Consumer Seam** — DEBUG-only `consumeUITestOverlayType()` helper that reads from injected `uiTestDefaults`, parses overlay type, clears key; decouples `EyePostureReminderApp` from `UserDefaults.standard` singleton

**Validation:**
- `./scripts/build.sh build` ✅
- `./scripts/build.sh test` ✅ (2053 tests, 0 failures)
- Commit ready for PR #591 review

**Scope:**
- `EyePostureReminder/App/AppDelegate.swift`
- `EyePostureReminder/App/EyePostureReminderApp.swift`
- `Tests/EyePostureReminderTests/Services/AppDelegateTests.swift`

**Decision Records Added to decisions.md:**
- `Decision: AppDelegate Notification Center Optional Factory Seam`
- `Decision: #462 Phase A DI/SRP — AppDelegate Launch Arguments Provider Seam`
- `Decision: #462 Phase A DI/SRP — AppDelegate UI-test overlay consumer seam`
- `Basher Decision: Snooze wake delay uses injected DateProviding`
- `Decision: PR #586 CI Build & Test should not run lint`

**Learnings:**
- Phase A optional-factory pattern now cohesive across seams: `AppDelegate` notification center, launch provider, and UI-test overlay all follow precedence-ordered resolution with fallback closure semantics.
- DI/SRP seams cluster well: AppDelegate initialization, production singleton defaults, and test-seam boundaries remain clean and surgical.
- Multi-seam PR orchestration: Basher successfully executed Phase A micro-slice scope including three tightly-coupled DI refactors with unified validation before PR submission.

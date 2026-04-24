# Project Context

- **Owner:** Yashasg
- **Project:** Eye & Posture Reminder — a lightweight iOS app with background timers and full-screen overlay reminders for eye breaks (20-20-20 rule) and posture checks
- **Stack:** Swift, SwiftUI (iOS 16+), MVVM, UserNotifications, UIKit overlay, UserDefaults
- **Created:** 2026-04-24

## Learnings

<!-- Append new learnings below. Each entry is something lasting about the project. -->

### 2026-04-24 — Test Strategy Created

- Created `docs/TEST_STRATEGY.md` — full test strategy for Phase 1.
- **Test pyramid:** 70% unit / 20% integration / 10% UI. Target ~100 automated tests.
- **Coverage targets:** Models 90%, Services 80%, ViewModels 80%, Views 60%.
- **Four mocks defined:** `MockNotificationScheduler`, `MockOverlayPresenter`, `MockAudioSession`, `MockUserDefaults` — all map to their protocol counterparts in ARCHITECTURE.md.
- **100 test scenarios** across Settings persistence (13), Notification scheduling (15), Overlay logic (13), Permission flow (7), App lifecycle (5), Edge cases (8).
- **Device matrix:** iPhone SE (small/min target), iPhone 15 Pro (primary), iPad Pro 12.9" (large/multitasking risk).
- **Accessibility checklist** covers VoiceOver, Dynamic Type 200%, Reduce Motion, High Contrast — all from UX_FLOWS.md spec.
- **Bug triage:** P0 blocker (crash/data loss), P1 major (significant UX impairment), P2 minor (tolerable), P3 cosmetic.
- **Regression strategy:** milestone-by-milestone re-test focus + high-risk file → test mapping.
- Key risk noted: `MediaControlling` protocol not yet in ARCHITECTURE.md — included speculatively for AVAudioSession mocking. Should be confirmed with Rusty before implementation.
- CI gate established: all unit tests pass + ≥ 80% coverage on Models/Services/ViewModels per PR.

### 2026-04-24 — Phase 1 Test Suite Implemented

- Created `Tests/EyePostureReminderTests/` with 4 test files (110+ test methods) and 3 mock classes.
- **Test structure:** `Mocks/` (infrastructure), `Models/` (ReminderTypeTests, SettingsStoreTests), `Services/` (ReminderSchedulerTests), `ViewModels/` (SettingsViewModelTests).
- **Mocks created:** `MockNotificationCenter` (full `NotificationScheduling` impl with call history + pending queue simulation), `MockSettingsPersisting` (in-memory dict-backed `SettingsPersisting`), `MockReminderScheduler` (call-count tracking `ReminderScheduling`).
- `SettingsPersisting` protocol uses `defaultValue:` labeled parameters (not the standard UserDefaults API) — mocks must match this signature.
- `SettingsViewModel` is `@MainActor` — test class must be `@MainActor` too; inner `Task{}` dispatches require a short `Task.sleep` await in tests before asserting call counts.
- `NotificationScheduling` protocol is defined inside `ReminderScheduler.swift` (not a separate Protocols/ file); same for `SettingsPersisting` inside `SettingsStore.swift`.
- Preset intervals spec: [600, 1200, 1800, 2700, 3600] seconds (10/20/30/45/60 min). Preset durations: [10, 20, 30, 60] seconds. Both validated in SettingsStoreTests.
- Package.swift updated to add `testTarget("EyePostureReminderTests")` depending on the executableTarget.
- Tests require iOS simulator to run (UIKit dependency in main target). `swift build` on macOS host will fail on UIKit import — this is expected. Use `xcodebuild test` with an iOS simulator runtime.
- `FailOnceNotificationCenter` helper class added inline in ReminderSchedulerTests to verify that a scheduling failure for one type doesn't block other types.


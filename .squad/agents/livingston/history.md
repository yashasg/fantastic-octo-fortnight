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

# Virgil — History

## Core Context

- **Project:** Eye & Posture Reminder — lightweight iOS app with background timers and overlay reminders
- **Stack:** Swift, SwiftUI (iOS 16+), MVVM, UserNotifications, UIKit overlay, UserDefaults
- **Owner:** Yashas
- **Joined:** 2026-04-24

## Learnings

- **iOS versioning is strictly numeric.** Apple requires `CFBundleShortVersionString` as dot-separated integers (e.g., `1.0.0`) and `CFBundleVersion` as a strictly increasing integer for TestFlight. No letters, hashes, or dashes allowed. Commit hashes cannot be used as versions — they get rejected server-side by App Store Connect.
- **Proposed versioning scheme (2025-07-17):** Semantic versioning for marketing version (manual bump), `github.run_number` for build number (auto), commit SHA embedded as custom `EPRCommitHash` Info.plist key for traceability. Git tags in `v1.0.0` format, annotated, created after successful upload. Full decision in `.squad/decisions/inbox/virgil-versioning.md`.
- **Build number strategy:** Using `github.run_number` is the simplest auto-increment for build numbers — guaranteed unique, guaranteed increasing, zero maintenance. Timestamp-based alternatives (e.g., `YYYYMMDDHHmm`) work but are harder to reason about and can collide on fast re-runs.

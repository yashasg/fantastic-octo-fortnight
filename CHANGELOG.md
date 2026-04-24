# Changelog

All notable changes to Eye & Posture Reminder are documented here.

Format: `vMAJOR.MINOR.PATCH[-prerelease]`  
Versioning strategy: `0.x.x` during TestFlight beta, `1.0.0` at App Store launch.

---

## v0.1.0-beta — TestFlight Beta

### Phase 0: Foundation
- Swift Package Manager project scaffold (iOS 16+, SwiftUI, MVVM)
- CI/CD pipeline: GitHub Actions build, test, lint on `macos-14`
- Architecture established: Models → Services → ViewModels → Views
- Design system: `AppColor`, `AppFont`, `AppSpacing` tokens
- SwiftLint configuration (120-char line length, SwiftUI-friendly ruleset)
- `scripts/build.sh` unified build/test/lint/clean runner

### Phase 1: MVP
- **Settings:** Interval and break duration pickers, haptics toggle, persisted via `UserDefaults`
- **Notifications:** `UNUserNotificationCenter` scheduling with per-type debounce (300 ms)
- **Overlay:** Full-screen UIKit window overlay with countdown ring, swipe-up dismiss, auto-dismiss
- **Integration:** `AppCoordinator` wires services; background/foreground lifecycle management
- **Snooze:** 5 min / 15 min / 30 min / rest-of-day options with dual wake mechanism (in-process Task + silent notification); max 2 consecutive snoozes
- **Haptics:** `UIImpactFeedbackGenerator` on overlay appear/dismiss; `UINotificationFeedbackGenerator` on auto-complete
- **Accessibility:** Dynamic Type, Reduce Motion, VoiceOver countdown live region, `accessibilityViewIsModal`
- **Tests:** 65+ unit tests; 80 %+ coverage across Models, Services, ViewModels

### Phase 2: Polish
- **Onboarding:** First-launch notification permission request flow
- **Haptics refinement:** Generator lifecycle with `.prepare()` in `onAppear` for instant response
- **Snooze UI:** `SnoozeOption` enum with formatted labels in OverlayView action sheet
- **Accessibility:** Countdown ZStack split into static label + live `.accessibilityValue`
- **Design tokens:** `ReminderType.color` migrated to `AppColor` design system

---

*Build numbers are assigned automatically by CI (`github.run_number`).*  
*Commit hash embedded as `EPRCommitHash` in Info.plist for traceability.*

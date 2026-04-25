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
- **Onboarding:** 3-screen first-launch flow (welcome, notification permission, setup) with `hasSeenOnboarding` persistence
- **Smart Pause:** Automatic reminder pause via Focus Mode detection, CarPlay detection, and CMMotionActivityManager driving detection; `PauseConditionManager` aggregates all conditions
- **Screen-Time Triggers:** `ScreenTimeTracker` replaces wall-clock timers — reminders fire after continuous screen-on time only (M2.7)
- **Snooze UI:** `SnoozeOption` enum with 4 duration options (5m / 15m / 30m / rest-of-day), max 2 consecutive snoozes, formatted labels in OverlayView action sheet
- **Data-Driven Configuration:** Asset Catalog color tokens (ReminderBlue, ReminderGreen, WarningOrange, PermissionBanner, PermissionBannerText, WarningText), String Catalog (~35 strings), `defaults.json` seed values (M2.8)
- **Disclaimer UI & Legal Docs:** In-app `LegalDocumentView` rendering bundled TERMS.md, PRIVACY.md, DISCLAIMER.md (M2.4)
- **App Icon & Launch Screen:** Production app icon and branded launch screen (M2.5)
- **Analytics:** `AnalyticsLogger` structured event logging via `os.Logger` with two-tier privacy annotations (`.public` for categorical labels, `.private` for values)
- **MetricKit:** `MetricKitSubscriber` for passive OS-level crash/performance diagnostic payloads
- **ServiceLifecycle:** Uniform start/stop lifecycle protocol for all services
- **Haptics refinement:** Generator lifecycle with `.prepare()` in `onAppear` for instant response
- **Accessibility:** Dynamic Type, Reduce Motion, VoiceOver countdown live region with `accessibilityViewIsModal`; countdown ZStack split into static label + live `.accessibilityValue`
- **Localization:** String Catalog with ~35 user-facing strings; localization-ready
- **Design tokens:** `ReminderType.color` migrated to `AppColor` design system; all colors via Asset Catalog with dark/light variants
- **Bug fixes:** Overlay double-present guard, notification debounce (300 ms), snooze wake reliability (dual wake mechanism)

---

*Build numbers are assigned automatically by CI (`github.run_number`).*  
*Commit hash embedded as `EPRCommitHash` in Info.plist for traceability.*

# Eye & Posture Reminder – iOS App Roadmap

> **Status:** Planning → Execution  
> **Target Platform:** iOS 16+, Swift, SwiftUI + UIKit  
> **Architecture:** MVVM, UserNotifications, UIWindow overlay  
> **Team:** 8 members across PM, Design, Architecture, Dev, QA, Review

---

## Executive Summary

Transform the **IMPLEMENTATION_PLAN.md** concept into a shippable iOS app through 4 sequential phases:

- **Phase 0: Foundation** – Project scaffolding, architecture setup, CI/CD, design system
- **Phase 1: MVP** – Core reminder scheduling + overlay functionality
- **Phase 2: Polish** – UX refinements, onboarding, haptics, accessibility
- **Phase 3: Advanced (Optional)** – iCloud sync, widgets, watchOS companion

Each phase delivers a testable, reviewable increment. Phase 0-2 are required for App Store submission. Phase 3 is post-launch enhancement.

---

## Team Roster & Responsibilities

| Member | Role | Primary Focus |
|---|---|---|
| **Danny** | Product Manager | Roadmap, scope, acceptance criteria, backlog prioritization |
| **Tess** | UI/UX Designer | Visual design, interaction flows, accessibility patterns |
| **Reuben** | Product Designer | User research, journey maps, onboarding flows |
| **Rusty** | Architect | System design, framework selection, performance strategy |
| **Linus** | iOS UI Developer | SwiftUI views, UIKit overlay, animation implementation |
| **Basher** | iOS Services Developer | Background scheduling, notification handling, persistence |
| **Livingston** | Tester | Test plans, manual/automated QA, edge case validation |
| **Saul** | Code Reviewer | Code quality, standards enforcement, security review |
| **Frank** | Legal Advisor | Terms of Service, Privacy Policy, legal compliance (joined Phase 2) |

---

## Phase 0: Foundation (Week 1-2)

**Goal:** Establish technical and design foundations for rapid feature development.

### Milestones

#### M0.1: Xcode Project Setup
- **Owner:** Basher (Services Dev)
- **Deliverables:**
  - Xcode project created with bundle ID `com.yashasg.eyeposture` (adjust org as needed)
  - iOS deployment target set to 16.0
  - SwiftUI app lifecycle configured (`@main` entry point)
  - Folder structure matching architecture (App, Models, Services, ViewModels, Views)
  - `.gitignore` configured for Xcode (exclude `xcuserdata`, `DerivedData`)
  - README.md with build instructions
- **Dependencies:** None
- **Duration:** 1 day
- **Acceptance Criteria:**
  - Project builds successfully on simulator (iPhone 14 Pro)
  - Runs "Hello World" SwiftUI view without errors

#### M0.2: Architecture Scaffolding
- **Owner:** Rusty (Architect)
- **Deliverables:**
  - `ReminderType.swift` enum skeleton (`.eyes`, `.posture`)
  - `ReminderSettings.swift` model struct (interval, breakDuration)
  - `SettingsStore.swift` UserDefaults wrapper (read/write methods stubbed)
  - `ReminderScheduler.swift` protocol + empty implementation
  - `OverlayManager.swift` protocol + empty implementation
  - `SettingsViewModel.swift` ObservableObject shell
  - Architecture decision record (ADR) documenting MVVM rationale
- **Dependencies:** M0.1 complete
- **Duration:** 2 days
- **Acceptance Criteria:**
  - All files compile with no warnings
  - Protocol contracts defined for testability
  - ADR reviewed and approved by team

#### M0.3: CI/CD Pipeline
- **Owner:** Basher (Services Dev) + Saul (Code Reviewer)
- **Deliverables:**
  - GitHub Actions workflow for:
    - Build validation on PR (xcodebuild)
    - Unit test execution
    - SwiftLint static analysis
  - `.swiftlint.yml` configuration (standard rules)
  - Xcode schemes configured for testing
- **Dependencies:** M0.1, M0.2 complete
- **Duration:** 2 days
- **Acceptance Criteria:**
  - CI passes on main branch
  - Pull requests blocked until CI green
  - Lint violations fail the build

#### M0.4: Design System Foundation
- **Owner:** Tess (UI/UX Designer)
- **Deliverables:**
  - Color palette definition (semantic naming: primary, secondary, background, surface)
  - Typography scale (headline, body, caption sizes)
  - Spacing system (4pt grid)
  - SF Symbol icon selections for eyes/posture
  - Figma prototype of Settings screen and Overlay screen (low-fidelity)
- **Dependencies:** None (parallel work)
- **Duration:** 3 days
- **Acceptance Criteria:**
  - Figma link shared with team
  - Color contrast meets WCAG AA standards
  - Design reviewed by Reuben and Linus

#### M0.5: User Journey Mapping
- **Owner:** Reuben (Product Designer)
- **Deliverables:**
  - User journey map: first-time user → permission grant → first reminder → habit formation
  - Pain point analysis (e.g., permission denial, notification fatigue)
  - Accessibility persona scenarios (VoiceOver user, low vision, motor impairment)
  - Recommendations for Phase 1 scope refinements
- **Dependencies:** None (parallel work)
- **Duration:** 2 days
- **Acceptance Criteria:**
  - Journey map reviewed in team sync
  - At least 3 accessibility scenarios documented
  - Findings inform Phase 1 work items

#### M0.6: Test Strategy Document
- **Owner:** Livingston (Tester)
- **Deliverables:**
  - Test plan template for each phase
  - Unit test coverage targets (80% for Services, ViewModels)
  - UI test scope definition (critical paths only)
  - Manual test checklist for each milestone
  - Bug triage process (P0-P3 severity levels)
- **Dependencies:** M0.2 complete (needs architecture context)
- **Duration:** 2 days
- **Acceptance Criteria:**
  - Test strategy approved by Danny
  - Team understands coverage expectations
  - Test plan integrated into CI workflow

### Phase 0 Success Criteria
- ✅ Xcode project builds without errors
- ✅ CI/CD pipeline operational with lint + tests
- ✅ Architecture contracts defined and reviewed
- ✅ Design system documented in Figma
- ✅ User journeys mapped with accessibility considerations
- ✅ Test strategy agreed upon

### Phase 0 Risks & Open Questions
- **Risk:** Team unfamiliar with UserNotifications API → **Mitigation:** Rusty to create spike/prototype in M0.2
- **Risk:** Design system too minimal for Phase 2 polish → **Mitigation:** Tess to include expansion notes in M0.4
- **Question:** Should we support iOS 15 or stick to iOS 16+? → **Decision:** iOS 16+ confirmed (SwiftUI List features, `.ultraThinMaterial`)

---

## Phase 1: MVP (Week 3-5)

**Goal:** Core functionality – users can configure reminders, receive notifications, and see full-screen overlays.

### Milestones

#### M1.1: Persistent Settings
- **Owner:** Basher (Services Dev)
- **Deliverables:**
  - `SettingsStore.swift` implementation with UserDefaults read/write
  - Default values: eyes (1200s / 20s), posture (1800s / 10s), remindersEnabled (true)
  - Unit tests for save/load/clear operations
  - `SettingsViewModel` binding to SettingsStore
- **Dependencies:** M0.2 (architecture), M0.6 (test plan)
- **Duration:** 2 days
- **Acceptance Criteria:**
  - Settings persist across app restarts
  - Unit tests achieve 90% coverage
  - ViewModel publishes changes on save

#### M1.2: Settings UI
- **Owner:** Linus (iOS UI Dev)
- **Deliverables:**
  - `SettingsView.swift` with SwiftUI Form layout
  - Toggle for "Enable Reminders"
  - Two expandable sections (eyes, posture) with:
    - Picker: "Remind me every" (10/20/30/45/60 min)
    - Picker: "Break duration" (10/20/30/60 s)
  - `ReminderRowView.swift` reusable component
  - Live binding to SettingsViewModel
- **Dependencies:** M1.1 (SettingsViewModel), M0.4 (design system)
- **Duration:** 3 days
- **Acceptance Criteria:**
  - UI matches Figma design
  - Changes save immediately to UserDefaults
  - Accessible labels for VoiceOver
  - UI tests verify picker interactions

#### M1.3: Notification Scheduling
- **Owner:** Basher (Services Dev)
- **Deliverables:**
  - `ReminderScheduler.swift` full implementation:
    - `scheduleAll()` – cancels pending, creates UNTimeIntervalNotificationRequests
    - `reschedule()` – called on settings changes
    - `cancelAll()` – cleanup method
  - UNAuthorizationOptions requested on first launch
  - Notification content (title, body, sound) per reminder type
  - Unit tests with mocked UNUserNotificationCenter
- **Dependencies:** M1.1 (SettingsStore)
- **Duration:** 3 days
- **Acceptance Criteria:**
  - Notifications fire at configured intervals (test with 10s intervals)
  - Notifications repeat automatically
  - Permission denial handled gracefully (alert shown)
  - Unit tests verify scheduling logic

#### M1.4: AppDelegate & Notification Handling
- **Owner:** Basher (Services Dev)
- **Deliverables:**
  - `AppDelegate.swift` conforms to UNUserNotificationCenterDelegate
  - `willPresentNotification` → triggers overlay if app is foreground
  - `didReceiveNotificationResponse` → triggers overlay if app opened from background
  - Notification permission request on first launch
- **Dependencies:** M1.3 (ReminderScheduler)
- **Duration:** 2 days
- **Acceptance Criteria:**
  - Foreground notifications trigger overlay (no system banner)
  - Background notifications open app and show overlay
  - Lock screen notifications appear correctly
  - Edge case: overlay not shown if device locked

#### M1.5: Overlay Window Implementation
- **Owner:** Linus (iOS UI Dev)
- **Deliverables:**
  - `OverlayManager.swift` implementation:
    - `show(reminderType:duration:)` – creates UIWindow at `.alert + 1` level
    - `dismiss()` – tears down window, releases memory
  - `OverlayView.swift` SwiftUI view:
    - Semi-transparent blur background
    - SF Symbol icon (eye.fill / figure.stand)
    - Title text ("Time to rest your eyes" / "Time to check your posture")
    - Countdown timer with circular progress ring
    - Dismiss button (X) in top-right
    - Swipe-down gesture to dismiss
  - Auto-dismiss after break duration (DispatchQueue.asyncAfter)
  - UIHostingController bridge from UIKit to SwiftUI
- **Dependencies:** M0.4 (design system), M1.4 (notification handling)
- **Duration:** 4 days
- **Acceptance Criteria:**
  - Overlay appears above all other content (including keyboard)
  - Countdown updates every second
  - Dismissible via button or swipe
  - Auto-dismisses after configured duration
  - No memory leaks (Instruments validation)
  - Accessibility: `accessibilityViewIsModal = true`, dismiss button labeled

#### M1.6: Integration & Edge Case Handling
- **Owner:** Basher (Services Dev) + Linus (iOS UI Dev)
- **Deliverables:**
  - Queue logic: if overlay is active, queue next reminder instead of stacking windows
  - Foreground-only fallback if notifications denied (timer-based)
  - Settings prompt to re-enable notifications
  - Dark/Light mode validation
  - iPad layout testing (full-screen overlay)
- **Dependencies:** M1.5 (overlay), M1.3 (scheduler)
- **Duration:** 2 days
- **Acceptance Criteria:**
  - No overlapping overlays
  - Fallback timer works without notifications
  - "Open Settings" deep link functional
  - Dark mode rendering correct

#### M1.7: MVP Testing
- **Owner:** Livingston (Tester)
- **Deliverables:**
  - Manual test pass on devices: iPhone 14 Pro, iPad Pro
  - Test scenarios:
    - First launch → permission flow
    - Change settings → verify reschedule
    - Background notification → overlay on tap
    - Force quit → notifications still fire
    - Denial handling → fallback mode
    - Accessibility: VoiceOver navigation
  - Bug report for P0/P1 issues
  - Regression test suite (UI tests)
- **Dependencies:** M1.6 (integration complete)
- **Duration:** 3 days
- **Acceptance Criteria:**
  - Zero P0 bugs (blockers)
  - All critical paths pass
  - Accessibility audit complete
  - Test report delivered to Danny

#### M1.8: Code Review & Refactoring
- **Owner:** Saul (Code Reviewer)
- **Deliverables:**
  - Full code review of Phase 1 PRs
  - SwiftLint violations resolved
  - Performance audit (Instruments: CPU, memory)
  - Security check: no hardcoded credentials, proper use of UserDefaults
  - Code comments for complex logic (e.g., notification delegate flow)
  - Refactoring pass for duplication
- **Dependencies:** M1.7 (testing complete)
- **Duration:** 2 days
- **Acceptance Criteria:**
  - All PRs approved
  - No lint violations
  - Memory usage < 30 MB idle
  - CPU usage < 5% between reminders

### Phase 1 Success Criteria
- ✅ Users can set reminder intervals and break durations
- ✅ Notifications fire on schedule and repeat automatically
- ✅ Full-screen overlay appears with countdown and dismiss functionality
- ✅ Settings persist across app restarts
- ✅ Notification permissions requested and handled
- ✅ Edge cases covered (denial, force quit, low power mode)
- ✅ Accessibility: VoiceOver support functional
- ✅ Zero P0/P1 bugs from testing
- ✅ Code reviewed and performance validated

### Phase 1 Risks & Open Questions
- **Risk:** UNUserNotificationCenter repeat behavior unreliable → **Mitigation:** Manual reschedule fallback if needed
- **Risk:** Overlay window doesn't dismiss correctly → **Mitigation:** Extensive testing in M1.5
- **Question:** Should "snooze" be in MVP? → **Decision:** Defer to Phase 2 (complexity vs. value trade-off)

---

## Phase 2: Polish (Week 6-7)

**Goal:** Elevate UX with onboarding, haptics, refined animations, and App Store readiness.

### Milestones

#### M2.1: Onboarding Flow
- **Owner:** Reuben (Product Designer) + Linus (iOS UI Dev)
- **Deliverables:**
  - 3-screen onboarding flow:
    1. Welcome (app value proposition)
    2. Notification permission education (why we need it)
    3. Quick settings preview (default intervals shown)
  - "Get Started" CTA → triggers permission request
  - "Skip" option (goes directly to settings)
  - First-launch flag in UserDefaults (show once)
  - SwiftUI PageView or TabView for horizontal swipe
- **Dependencies:** M1.2 (SettingsView), M0.5 (user journey)
- **Duration:** 3 days
- **Acceptance Criteria:**
  - Onboarding shows only on first launch
  - Permission request follows immediately after onboarding
  - Skip option works correctly
  - Animations smooth (60 fps)

#### M2.2: Haptic Feedback
- **Owner:** Linus (iOS UI Dev)
- **Deliverables:**
  - Haptic feedback on overlay appearance (`UINotificationFeedbackGenerator.notification(.warning)`)
  - Haptic on dismiss (`.success`)
  - Settings toggle for haptics on/off (stored in UserDefaults)
  - Ensure haptics respect device silent mode
- **Dependencies:** M1.5 (overlay)
- **Duration:** 1 day
- **Acceptance Criteria:**
  - Haptics fire appropriately
  - No haptics if device in silent mode or user disabled
  - Energy impact negligible (Instruments validation)

#### M2.3: Snooze Action
- **Owner:** Basher (Services Dev)
- **Deliverables:**
  - UNNotificationAction: "Snooze 5 min" added to notification category
  - Handler in `didReceiveNotificationResponse` to reschedule single notification
  - Snooze count limit (max 2 snoozes per reminder instance)
  - UI indication if snoozed (optional toast in overlay)
- **Dependencies:** M1.4 (notification handling)
- **Duration:** 2 days
- **Acceptance Criteria:**
  - Snooze action appears in notification
  - Reminder fires again after 5 min
  - Limit enforced (no infinite snoozes)

#### M2.3b: Smart Pause – Focus Mode & Driving Detection
- **Owner:** Rusty (Architect) + Basher (Services Dev)
- **Deliverables:**
  - `PauseConditionManager` service aggregating three detectors:
    - Focus Status Detector: Uses `INFocusStatusCenter` (iOS 16+, requires `com.apple.intents` entitlement)
    - CarPlay Detector: Uses `AVAudioSession.currentRoute` (no special entitlement)
    - Driving Activity Detector: Uses `CMMotionActivityManager` coprocessor (requires Info.plist `NSMotionUsageDescription`)
  - Integration with `AppCoordinator`: `isPaused` state → `screenTimeTracker.pauseAll()` / `resumeAll()`
  - Pause logic: Focus active OR CarPlay active OR driving detected → no reminders
  - Unit tests with protocol mocks for all three detectors
- **Dependencies:** M1.3 (ReminderScheduler), Phase 1 complete
- **Duration:** 4 days
- **Acceptance Criteria:**
  - Reminders pause when Focus Mode active or driving detected
  - Timers resume from previous elapsed time when pause cleared
  - CarPlay route change correctly detected
  - All three detectors tested independently via mocks
  - Info.plist permissions documented and included

#### M2.4: Disclaimer UI
- **Owner:** Reuben (Product Designer) + Linus (iOS UI Dev)
- **Deliverables:**
  - Onboarding screen (4th screen post-permission): Disclaimer notice linking to legal docs
  - Settings section: "Legal & Privacy" with links to:
    - Terms of Service (docs/legal/TERMS.md)
    - Privacy Policy (docs/legal/PRIVACY.md)
    - Disclaimer (docs/legal/DISCLAIMER.md)
  - In-app WebView or link to external docs
  - "I Agree" checkbox on onboarding (required to proceed)
- **Dependencies:** M2.1 (onboarding), legal docs from Frank
- **Duration:** 2 days
- **Acceptance Criteria:**
  - Disclaimer displays on first launch onboarding
  - All three legal docs accessible from Settings
  - "I Agree" flag persisted in UserDefaults
  - Links open correctly (in-app or system browser)

#### M2.5: App Icon & Launch Screen
- **Owner:** Tess (UI/UX Designer)
- **Deliverables:**
  - App icon design (1024x1024 master, all required sizes generated)
  - Launch screen (static image or SwiftUI view)
  - Icon follows iOS design guidelines (no transparency, rounded square applied by system)
  - Launch screen matches app branding (minimal, non-interactive)
- **Dependencies:** M0.4 (design system)
- **Duration:** 2 days
- **Acceptance Criteria:**
  - Icon renders correctly in App Library and Home Screen
  - Launch screen displays without delay
  - Design approved by Danny

#### M2.6: Accessibility Refinements
- **Owner:** Linus (iOS UI Dev) + Livingston (Tester)
- **Deliverables:**
  - VoiceOver labels refined for all UI elements
  - Dynamic Type support (text scales with user preference)
  - Reduce Motion support (disable overlay animations if enabled)
  - High Contrast mode validation
  - Color blindness simulation testing (Sim Daltonism tool)
- **Dependencies:** M1.2 (Settings UI), M1.5 (Overlay UI)
- **Duration:** 2 days
- **Acceptance Criteria:**
  - All interactive elements have accessible labels
  - Text readable at 200% scale
  - Animations disabled if Reduce Motion on
  - High contrast colors meet WCAG AAA

#### M2.7: Polish Testing & Bug Fixes
- **Owner:** Livingston (Tester)
- **Deliverables:**
  - Full regression pass on all Phase 1 + Phase 2 features
  - Device matrix: iPhone SE (small screen), iPhone 14 Pro, iPad Pro
  - Low Power Mode validation
  - Notification stress test (rapid interval changes)
  - Bug fixes for all P0/P1/P2 issues
  - Final accessibility audit
- **Dependencies:** M2.6 (accessibility complete)
- **Duration:** 3 days
- **Acceptance Criteria:**
  - Zero P0/P1 bugs
  - All devices tested
  - Accessibility audit passed

#### M2.8: Data-Driven Configuration
- **Owner:** Basher (Services Dev) + Linus (iOS UI Dev) + Tess (UI/UX Designer)
- **Deliverables:**
  - **Asset Catalog:** 6 semantic color tokens (`reminderBlue`, `reminderGreen`, `reminderWarning`, `overlayBackground`, `surfaceBackground`, `labelSecondary`) with dark/light variants. `DesignSystem.swift` `UIColor(dynamicProvider:)` calls removed.
  - **String Catalog:** `Localizable.xcstrings` with ~35 user-facing keys covering all six view files. Bare string literals replaced with `Text("key")` / `String(localized:)`.
  - **`defaults.json`** (bundled): reminder intervals, break durations, haptic + snooze defaults, feature flags (~10 values). `DefaultsLoader.swift` seeds `UserDefaults` on first launch only.
  - **`SettingsStore.resetToDefaults()`** re-seeds from `defaults.json` (same first-launch code path).
  - Unit tests for `DefaultsLoader` with fixture bundle injection.
- **Dependencies:** M1.1 (SettingsStore), M0.4 (design system), M2.1 (Onboarding — all copy in scope)
- **Duration:** 3 days
- **Acceptance Criteria:**
  - Zero `UIColor(dynamicProvider:)` calls in Swift — all colors via Asset Catalog
  - Zero bare string literals in views — all via String Catalog keys
  - `defaults.json` included in Copy Bundle Resources build phase
  - Settings seed correctly on first launch and survive restart
  - `resetToDefaults()` re-seeds correctly
  - App renders correctly in light and dark mode
  - SwiftLint passes with no new violations
  - Unit tests for `DefaultsLoader` pass

#### M2.9: App Store Preparation
- **Owner:** Danny (Product Manager) + Saul (Code Reviewer)
- **Deliverables:**
  - App Store Connect listing:
    - Description (150-word value prop)
    - Keywords (search optimization)
    - Screenshots (5 required: onboarding, settings, overlay examples)
    - Privacy policy (even if minimal data collection)
  - Release notes for v1.0
  - TestFlight beta submission (internal testing)
  - Final code review and version tagging (v1.0.0)
- **Dependencies:** M2.7 (testing complete)
- **Duration:** 2 days
- **Acceptance Criteria:**
  - App Store listing complete
  - TestFlight build submitted
  - Privacy policy published
  - Version tagged in Git

### Phase 2 Success Criteria
- ✅ Onboarding flow guides new users smoothly
- ✅ Haptic feedback enhances tactile experience
- ✅ Snooze action functional with limits
- ✅ Smart Pause pauses reminders during Focus Mode, CarPlay, or driving
- ✅ Disclaimer UI displayed on onboarding and accessible in Settings
- ✅ App icon and launch screen polished
- ✅ Accessibility meets WCAG AA (ideally AAA)
- ✅ All devices tested (iPhone, iPad, accessibility modes)
- ✅ App Store listing ready
- ✅ TestFlight build live for beta testing
- ✅ Data-driven config: colors via Asset Catalog, copy via String Catalog, settings seeded from `defaults.json`

### Phase 2 Risks & Open Questions
- **Risk:** Smart Pause detectors conflict (e.g., focusing while driving) → **Mitigation:** Logical OR aggregates all signals; testing validates priority
- **Risk:** Onboarding adds complexity to first-launch → **Mitigation:** Keep to 4 screens max (added disclaimer), allow skip
- **Risk:** Haptics drain battery more than expected → **Mitigation:** Measure in M2.2 with Instruments
- **Question:** Should we include a "rate the app" prompt? → **Decision:** Defer to post-launch (avoid interrupting UX)

---

## Phase 3: Advanced Features (Post-Launch, Optional)

**Goal:** Differentiate with iCloud sync, widgets, and watchOS companion for power users.

### Milestones

#### M3.1: iCloud Settings Sync
- **Owner:** Basher (Services Dev)
- **Deliverables:**
  - Migrate SettingsStore to `NSUbiquitousKeyValueStore`
  - Conflict resolution strategy (last-write-wins)
  - Sync status indicator in settings ("Syncing..." / "Synced ✓")
  - Fallback to local UserDefaults if iCloud unavailable
  - Unit tests for sync scenarios
- **Dependencies:** Phase 1 complete
- **Duration:** 4 days
- **Acceptance Criteria:**
  - Settings sync across devices within 5 seconds
  - No data loss on conflict
  - Graceful degradation if iCloud off

#### M3.2: Home Screen Widget
- **Owner:** Linus (iOS UI Dev)
- **Deliverables:**
  - WidgetKit extension
  - Widget shows: "Next eye break in 12 min" + "Next posture check in 18 min"
  - Timeline provider updates every minute
  - Small, medium, large widget sizes
  - Deep link to settings on tap
- **Dependencies:** M1.1 (SettingsStore for reading intervals)
- **Duration:** 5 days
- **Acceptance Criteria:**
  - Widget updates accurately
  - Battery impact < 1% per day
  - Renders correctly in all sizes

#### M3.3: watchOS Companion App
- **Owner:** Linus (iOS UI Dev) + Basher (Services Dev)
- **Deliverables:**
  - watchOS target in Xcode project
  - Glance view: countdown to next reminder
  - Haptic on watch when reminder fires (if phone nearby)
  - Settings sync from iOS app (no duplicate configuration UI)
  - Complications for watch faces (corner, circular)
- **Dependencies:** M3.1 (iCloud sync for settings)
- **Duration:** 7 days
- **Acceptance Criteria:**
  - watchOS app installs automatically with iOS app
  - Haptics fire on watch
  - Complications show accurate countdowns

#### M3.4: Advanced Testing & Release
- **Owner:** Livingston (Tester) + Saul (Code Reviewer)
- **Deliverables:**
  - Testing for iCloud sync edge cases (airplane mode, account switch)
  - Widget performance testing (battery, memory)
  - watchOS testing on physical watch
  - Code review for new components
  - App Store update submission (v1.1.0)
- **Dependencies:** M3.1, M3.2, M3.3 complete
- **Duration:** 3 days
- **Acceptance Criteria:**
  - All new features tested
  - Performance benchmarks met
  - v1.1.0 submitted to App Store

### Phase 3 Success Criteria
- ✅ Settings sync via iCloud across devices
- ✅ Home Screen widget displays next reminder times
- ✅ watchOS companion functional with haptics
- ✅ Battery impact < 2% additional per day (all features combined)
- ✅ v1.1.0 released successfully

### Phase 3 Risks & Open Questions
- **Risk:** watchOS development expertise lacking on team → **Mitigation:** Linus to complete watchOS tutorial before M3.3
- **Risk:** Widget timeline updates impact battery → **Mitigation:** Measure early in M3.2, adjust update frequency
- **Question:** Should we add Siri shortcuts? → **Decision:** Evaluate user feedback post-Phase 3; complexity high

---

## Dependency Map (Critical Path)

```
Phase 0:
  M0.1 (Xcode Setup)
    ↓
  M0.2 (Architecture) ——→ M0.3 (CI/CD)
    ↓                         ↓
  M0.6 (Test Strategy)       (parallel: M0.4 Design System, M0.5 User Journey)

Phase 1:
  M0.2 → M1.1 (Persistent Settings)
           ↓
  M0.4 → M1.2 (Settings UI) ←——————┐
           ↓                         |
  M1.1 → M1.3 (Notification Scheduling)
           ↓                         |
  M1.3 → M1.4 (AppDelegate)         |
           ↓                         |
  M1.4 → M1.5 (Overlay Window) ——→ M1.6 (Integration)
           ↓
  M1.6 → M1.7 (Testing) → M1.8 (Code Review)

Phase 2:
  M1.2 + M0.5 → M2.1 (Onboarding)
  M1.5 → M2.2 (Haptics)
  M1.4 → M2.3 (Snooze)
  M1.3 + Phase 1 → M2.3b (Smart Pause)
  M2.1 → M2.4 (Disclaimer UI)
  M0.4 → M2.5 (App Icon)
  M1.2 + M1.5 → M2.6 (Accessibility)
  M2.6 → M2.7 (Polish Testing) → M2.8 (Data-Driven Config) → M2.9 (App Store Prep)

Phase 3:
  Phase 1 → M3.1 (iCloud Sync)
  M1.1 → M3.2 (Widget)
  M3.1 → M3.3 (watchOS)
  M3.1 + M3.2 + M3.3 → M3.4 (Advanced Testing)
```

---

## Timeline Estimates

| Phase | Duration | End Date (from project start) |
|---|---|---|
| Phase 0: Foundation | 2 weeks | Week 2 |
| Phase 1: MVP | 3 weeks | Week 5 |
| Phase 2: Polish | 2 weeks | Week 7 |
| **App Store Submission** | — | **End of Week 7** |
| Phase 3: Advanced (optional) | 3 weeks | Week 10 |

**Total to v1.0 (App Store):** 7 weeks  
**Total to v1.1 (with Phase 3):** 10 weeks

---

## Open Questions & Decisions Needed

### Before Phase 0 Start
1. **Q:** Confirm app name and bundle ID with stakeholder  
   **Owner:** Danny  
   **Deadline:** Before M0.1

2. **Q:** Do we need analytics (Firebase, Mixpanel)?  
   **Owner:** Danny  
   **Deadline:** Before M1.8 (impacts privacy policy)

3. **Q:** Monetization strategy – free with IAP, paid upfront, or ads?  
   **Owner:** Danny  
   **Deadline:** Before M2.7 (impacts App Store listing)

### Before Phase 1 Start
4. **Q:** Should intervals be customizable to any value or limited to preset options?  
   **Owner:** Tess + Danny  
   **Deadline:** Before M1.2  
   **Recommendation:** Preset options for MVP (simpler UI, fewer edge cases)

5. **Q:** Notification sound – default or custom?  
   **Owner:** Tess  
   **Deadline:** Before M1.3  
   **Recommendation:** Default for MVP, custom sounds in Phase 3

### Before Phase 2 Start
6. **Q:** Should we collect user feedback in-app (feedback form)?  
   **Owner:** Reuben + Danny  
   **Deadline:** Before M2.7  
   **Recommendation:** Email link in settings (avoid complexity)

---

## Risk Register

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| UNUserNotificationCenter repeat behavior unreliable on all iOS versions | Medium | High | Early testing in M1.3; fallback to manual reschedule |
| Team lacks watchOS experience | High | Medium | Defer Phase 3 if needed; prioritize Phase 1+2 |
| Overlay window doesn't dismiss correctly (memory leak) | Low | High | Extensive testing + Instruments validation in M1.5 |
| App Store rejection for privacy policy | Low | High | Have privacy policy reviewed by legal before submission |
| Accessibility compliance failure | Medium | Medium | Dedicated testing in M2.5; use Accessibility Inspector |
| Haptic feedback drains battery more than expected | Low | Low | Measure in M2.2; make haptics optional |
| iCloud sync conflicts cause data loss | Medium | Medium | Implement last-write-wins + logging in M3.1 |

---

## Success Metrics (Post-Launch)

### User Engagement
- **Daily Active Users (DAU):** Target 60% of installs use app daily within first week
- **Retention (D7):** 40% of users still have app installed after 7 days
- **Reminder Completion Rate:** 70% of overlays dismissed naturally (not force-closed)

### Technical Performance
- **Crash-Free Rate:** 99.5%+ (measured via Xcode Organizer)
- **Battery Impact:** < 3% per day (iOS Battery Settings)
- **Average Memory Usage:** < 30 MB when idle
- **App Store Rating:** 4.0+ stars (target within first 50 reviews)

### Accessibility
- **VoiceOver Usage:** 5% of sessions (indicates accessibility adoption)
- **Dynamic Type Usage:** 15% of users (text scaling enabled)

---

## Appendix: Work Item Checklist Template

For each milestone, team members should complete:

### Development Checklist
- [ ] Code written and self-reviewed
- [ ] Unit tests written (if applicable) with > 80% coverage
- [ ] SwiftLint passes with no violations
- [ ] Manual testing on simulator (iPhone + iPad)
- [ ] Accessibility labels added for new UI components
- [ ] PR opened with description and screenshots
- [ ] Code reviewed by Saul
- [ ] PR merged to main

### Testing Checklist (Livingston)
- [ ] Manual test cases executed
- [ ] Edge cases validated (permission denial, force quit, etc.)
- [ ] Accessibility audit passed (VoiceOver, Dynamic Type)
- [ ] Bugs logged with severity (P0-P3)
- [ ] Regression tests updated (UI test suite)

### Design Checklist (Tess / Reuben)
- [ ] Figma designs finalized and shared
- [ ] Design reviewed by team (feedback incorporated)
- [ ] Implementation matches design spec
- [ ] Accessibility patterns followed (color contrast, touch targets)
- [ ] Dark mode variant validated

---

## Contact & Escalation

- **Scope Changes:** Escalate to Danny (Product Manager)
- **Technical Blockers:** Escalate to Rusty (Architect)
- **Design Conflicts:** Escalate to Tess (UI/UX Designer)
- **Quality Issues:** Escalate to Saul (Code Reviewer)

---

**Last Updated:** 2026-04-24  
**Document Owner:** Danny (Product Manager)  
**Status:** Ready for Phase 0 kickoff

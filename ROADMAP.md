# kshana — iOS App Roadmap

> **Status:** v0.2.0 (Restful Grove) shipped — Phase 1+2 complete; **PIVOT to True Interrupt Mode (Screen Time APIs)** — Phase 3 (Interrupt Mode MVP)  
> **Core Value Proposition:** True Interrupt Mode via Apple Screen Time APIs (FamilyControls + DeviceActivity + ManagedSettings) to pause distracting apps during break reminders. Local notifications are backup-only, not core.  
> **Target Platform:** iOS 16+ (17+ for full Screen Time API support)  
> **Architecture:** MVVM + Screen Time APIs (DeviceActivity, ManagedSettings, ShieldConfiguration), app groups, extension communication  
> **Team:** 13 members across PM, Design, Architecture, Dev, QA, Review, Legal, DevOps, Analytics

---

## Executive Summary

**kshana pivots to True Interrupt Mode.** Shipped **v0.2.0 (Restful Grove)** — Phase 1+2 complete with overlay reminders, smart pause, accessibility, yin-yang branding, 1,382 unit tests, 81%+ coverage. **Now pivoting to Phase 3 (Interrupt Mode MVP):** Core product value is Apple Screen Time APIs (FamilyControls authorization + DeviceActivity monitoring + ManagedSettings to shield distracting apps during breaks). Local notification reminders become backup-only, not the primary product promise. Phase 3 unblocks on entitlement approval (Case ID 102881605113). New phase includes: extension targets (ShieldConfiguration), device activity monitoring, app/category picker, managed settings + shield actions, app group shared state, pre-permission UX refinement, and legal/privacy updates for data controller terminology.

- **Phase 0: Foundation** ✅ – Project scaffolding, CI/CD, architecture, design system
- **Phase 1: MVP** ✅ – Reminders, overlay, settings (shipped)
- **Phase 2: Polish** ✅ – Onboarding, haptics, snooze, smart pause, accessibility, data-driven config, Restful Grove identity, yin-yang logo (shipped)
- **Phase 3: Interrupt Mode MVP** 🔄 – Screen Time APIs, app shielding, extension architecture, pre-permission UX, legal updates (in progress)

---

## Team Roster & Responsibilities

| Member | Role | Primary Focus |
|---|---|---|
| **Danny** | Product Manager | Roadmap, scope, acceptance criteria, backlog prioritization |
| **Tess** | UI/UX Designer | Visual design, interaction flows, accessibility patterns, design tokens |
| **Reuben** | Product Designer | User research, journey maps, onboarding flows, UX copy |
| **Rusty** | Architect | System design, framework selection, performance strategy, protocol design |
| **Linus** | iOS UI Developer | SwiftUI views, UIKit overlay, animations, String Catalog integration |
| **Basher** | iOS Services Developer | Background scheduling, notification handling, persistence, ScreenTimeTracker |
| **Livingston** | Tester | Unit/UI test plans, manual QA, edge case validation, accessibility audit |
| **Saul** | Code Reviewer | Code quality, standards enforcement, security review, PR sign-off |
| **Frank** | Legal Advisor | Terms of Service, Privacy Policy, legal compliance, disclaimer content |
| **Virgil** | CI/CD Developer | GitHub Actions pipeline, build optimization, binary caching, test infrastructure |
| **Turk** | Data Analyst | Success metrics tracking, post-launch analytics, user behavior (deferred Phase 3+) |
| **Ralph** | Code Formatter | SwiftLint enforcement, refactoring coordination |
| **Scribe** | Orchestration | Decision logging, team sync documentation, handoff notes |

---

## Phase 0: Foundation ✅ COMPLETE

**Goal:** Establish technical and design foundations for rapid feature development.

**Status:** Shipped w/ all milestones delivered. CI/CD pipeline operational, architecture established, design system in place (Asset Catalog, String Catalog, design tokens).

### Milestones (Completed)

#### M0.1: Xcode Project Setup ✅
- **Owner:** Basher (Services Dev)
- **Status:** ✅ Complete
- **Delivered:**
  - Xcode project with SPM (Swift Package Manager) scaffolding
  - iOS 16+ deployment target
  - SwiftUI app lifecycle, folder structure matching MVVM
  - CI/CD via GitHub Actions (build, test, lint on `macos-14`)

#### M0.2: Architecture Scaffolding ✅
- **Owner:** Rusty (Architect)
- **Status:** ✅ Complete
- **Delivered:**
  - MVVM architecture with Models, Services, ViewModels, Views layers
  - `ReminderType`, `ReminderSettings`, `SettingsStore` models defined
  - `ReminderScheduler`, `OverlayManager` protocols + implementations
  - Service layer established (`AppCoordinator` orchestrator added in Phase 2)

#### M0.3: CI/CD Pipeline ✅
- **Owner:** Virgil (CI/CD Dev), Saul (Code Reviewer)
- **Status:** ✅ Operational
- **Delivered:**
  - GitHub Actions: build, test, lint on every PR
  - SwiftLint 120-char line length, SwiftUI-friendly rules
  - `scripts/build.sh` unified build/test/lint/clean runner (by Virgil)
  - Binary caching optimization (by Virgil)

#### M0.4: Design System Foundation ✅
- **Owner:** Tess (UI/UX Designer)
- **Status:** ✅ Complete + EVOLVED
- **Delivered (Phase 0):**
  - Color palette, typography scale, spacing system, SF Symbol selections
  - Figma mockups of Settings and Overlay
- **Evolved (Phase 2):**
  - Asset Catalog with 6 semantic color tokens (dark/light variants via OS)
  - String Catalog (~35 user-facing strings, localization-ready)
  - All hardcoded colors migrated from `UIColor(dynamicProvider:)` to Asset Catalog

#### M0.5: User Journey Mapping ✅
- **Owner:** Reuben (Product Designer)
- **Status:** ✅ Complete
- **Delivered:**
  - User journey: first-time user → permission → first reminder → habit
  - Accessibility personas: VoiceOver, low vision, motor impairment scenarios
  - Findings drove Phase 2 onboarding + smart pause design

#### M0.6: Test Strategy Document ✅
- **Owner:** Livingston (Tester)
- **Status:** ✅ Complete + EVOLVED
- **Delivered (Phase 0):**
  - Test plan templates, 80% coverage targets, UI test scope
  - Bug triage (P0-P3 severity levels)
- **Evolved (Phase 1-2):**
  - 71+ unit tests across Models, Services, ViewModels (80%+ coverage achieved)
  - XCUITest scaffold for end-to-end flows (HomeScreen, Settings, Onboarding)
  - Integration tests for service wiring

### Phase 0 Success Criteria
- ✅ Project builds without errors (Swift Package Manager)
- ✅ CI/CD pipeline operational (GitHub Actions, SwiftLint, tests)
- ✅ MVVM architecture established and reviewed
- ✅ Design system in Figma + implemented in code
- ✅ User journeys mapped with accessibility scenarios
- ✅ Test strategy executed (80%+ coverage maintained)

---

## Phase 1: MVP ✅ COMPLETE

**Goal:** Core functionality – users can configure reminders, receive notifications, and see full-screen overlays with countdown and dismiss.

**Status:** Shipped. All core features implemented and tested. ~65 unit tests, accessibility support, settings persistence, notification scheduling, overlay window with haptics.

### Milestones (Completed)

#### M1.1: Persistent Settings ✅
- **Owner:** Basher (Services Dev)
- **Status:** ✅ Complete
- **Delivered:**
  - `SettingsStore.swift` wrapping UserDefaults with type-safe accessors
  - Default values: eyes (1200s / 20s), posture (1800s / 10s), remindersEnabled (true)
  - Unit tests with 90%+ coverage for save/load/clear
  - `SettingsViewModel` binds UI to store; publishes changes

#### M1.2: Settings UI ✅
- **Owner:** Linus (iOS UI Dev)
- **Status:** ✅ Complete
- **Delivered:**
  - `SettingsView.swift` with SwiftUI Form layout
  - Toggle for "Enable Reminders"
  - `ReminderRowView` components (interval + duration pickers)
  - Live binding to ViewModel; changes save immediately
  - Accessibility labels for VoiceOver

#### M1.3: Notification Scheduling ✅
- **Owner:** Basher (Services Dev)
- **Status:** ✅ Complete (EVOLVED to ScreenTimeTracker in Phase 2)
- **Original Deliverables:**
  - `ReminderScheduler` with `scheduleAll()`, `reschedule()`, `cancelAll()`
  - UNTimeIntervalNotificationRequests with repeat
  - Permission request on first launch
  - Unit tests with mocked UNUserNotificationCenter
- **Phase 2 Evolution:**
  - Wall-clock intervals replaced with `ScreenTimeTracker` (continuous screen-on time)
  - Screen ON/OFF detection via `UIApplication` lifecycle notifications
  - 5-second grace period on app backgrounding (tolerate brief interruptions)
  - No background modes declared; all timing while foreground

#### M1.4: AppDelegate & Notification Handling ✅
- **Owner:** Basher (Services Dev)
- **Status:** ✅ Complete
- **Delivered:**
  - `AppDelegate.swift` conforms to `UNUserNotificationCenterDelegate`
  - `willPresentNotification` → overlay if app foreground
  - `didReceiveNotificationResponse` → overlay on tap
  - Permission request on first launch
  - Fallback if permissions denied

#### M1.5: Overlay Window Implementation ✅
- **Owner:** Linus (iOS UI Dev)
- **Status:** ✅ Complete
- **Delivered:**
  - `OverlayManager.swift` (UIWindow at `.alert + 1` level)
  - `OverlayView.swift` (SwiftUI): blur background, SF Symbol, countdown ring, dismiss button, swipe-up dismiss
  - Auto-dismiss after configured duration (DispatchQueue.asyncAfter)
  - UIHostingController bridges UIKit ↔ SwiftUI
  - No memory leaks (validated with Instruments)
  - Accessibility: `accessibilityViewIsModal = true`

#### M1.6: Integration & Edge Case Handling ✅
- **Owner:** Basher (Services Dev) + Linus (iOS UI Dev)
- **Status:** ✅ Complete
- **Delivered:**
  - Queue logic: single overlay at a time (queues next reminder if active)
  - Foreground-only fallback if notifications denied
  - Settings prompt to re-enable notifications (deep link to iOS Settings)
  - Dark/Light mode rendering correct
  - iPad full-screen overlay tested

#### M1.7: MVP Testing ✅
- **Owner:** Livingston (Tester)
- **Status:** ✅ Complete
- **Delivered:**
  - Manual test on iPhone 14 Pro, iPad Pro
  - All critical paths: first launch, settings changes, notifications, force quit, denial handling
  - Accessibility audit: VoiceOver functional
  - Regression test suite (UI tests scaffolded)
  - Zero P0 bugs

#### M1.8: Code Review & Refactoring ✅
- **Owner:** Saul (Code Reviewer)
- **Status:** ✅ Complete
- **Delivered:**
  - Full code review of Phase 1 PRs
  - SwiftLint violations resolved (120-char lines enforced)
  - Performance audit: CPU < 5% idle, memory < 30 MB
  - Security check: no hardcoded secrets, proper UserDefaults usage
  - Code comments for complex logic

### Phase 1 Success Criteria
- ✅ Users can set reminder intervals and break durations
- ✅ Notifications fire and repeat automatically
- ✅ Full-screen overlay with countdown, dismiss button, swipe-up dismiss
- ✅ Settings persist across app restarts
- ✅ Notification permissions requested and handled
- ✅ Edge cases covered (denial, force quit, dark mode)
- ✅ VoiceOver accessibility functional
- ✅ Zero P0/P1 bugs
- ✅ 65+ unit tests, 80%+ coverage, code reviewed

---

## Phase 2: Polish 🔄 IN PROGRESS (~95% Complete)

**Goal:** Elevate UX with onboarding, haptics, smart pause, accessibility, data-driven config, and App Store readiness.

**Status:** Most milestones delivered. Screen-time triggers implemented (ScreenTimeTracker replacing wall-clock intervals). Smart pause complete (Focus Mode, CarPlay, driving detection). Onboarding, snooze, haptics, accessibility refined. Data-driven config via Asset Catalog (colors), String Catalog (copy), defaults.json (settings). App Store listing documented. Awaiting final submission.

### Milestones

#### M2.1: Onboarding Flow ✅
- **Owner:** Reuben (Product Designer) + Linus (iOS UI Dev)
- **Status:** ✅ Complete
- **Delivered:**
  - 3-screen onboarding: Welcome → Permissions → Setup
  - "Get Started" triggers permission request
  - "Skip" option available
  - First-launch flag in UserDefaults
  - SwiftUI TabView with horizontal swipe navigation
  - Accessibility: VoiceOver-friendly labels

#### M2.2: Haptic Feedback ✅
- **Owner:** Linus (iOS UI Dev)
- **Status:** ✅ Complete
- **Delivered:**
  - Haptic on overlay appearance (`.warning` notification)
  - Haptic on overlay dismiss (`.success`)
  - Haptic on snooze action
  - Toggle in settings to enable/disable haptics
  - Respects device silent mode and user preference
  - Energy impact negligible (< 0.1% battery per day)

#### M2.3: Snooze Action ✅
- **Owner:** Basher (Services Dev)
- **Status:** ✅ Complete
- **Delivered:**
  - 5 min / 15 min / 30 min / rest-of-day snooze options
  - Max 2 consecutive snoozes per reminder instance
  - Dual wake mechanism: in-process `Task` + silent notification
  - Unit tests for snooze limits and rescheduling
  - Snooze persisted across app backgrounding

#### M2.3b: Smart Pause – Focus Mode & Driving Detection ✅
- **Owner:** Rusty (Architect) + Basher (Services Dev)
- **Status:** ✅ Complete
- **Delivered:**
  - `PauseConditionManager` aggregating three detectors:
    - **Focus Status Detector:** Uses `INFocusStatusCenter` (iOS 16+, `com.apple.intents` entitlement)
    - **CarPlay Detector:** Uses `AVAudioSession.currentRoute` (no entitlement)
    - **Driving Activity Detector:** Uses `CMMotionActivityManager` coprocessor (`NSMotionUsageDescription` Info.plist)
  - Integration with `AppCoordinator`: `isPaused` state → timers pause/resume
  - Pause logic: Focus active OR CarPlay active OR driving detected → no reminders
  - Grace period: interruptions < 5s don't reset elapsed time
  - Unit tests with protocol mocks for all three detectors
  - 71 unit tests across all pause conditions

#### M2.4: Disclaimer UI ✅
- **Owner:** Reuben (Product Designer) + Linus (iOS UI Dev) + Frank (Legal Advisor)
- **Status:** ✅ Complete
- **Delivered:**
  - Onboarding disclaimer screen (post-permission, pre-Settings)
  - Settings section: "Legal & Privacy" with links to Terms, Privacy Policy, Disclaimer
  - "I Agree" checkbox required to proceed past onboarding
  - Legal docs committed to `docs/legal/` (managed by Frank)
  - LegalDocumentView for in-app WebView rendering

#### M2.5: App Icon & Launch Screen ✅
- **Owner:** Tess (UI/UX Designer)
- **Status:** ✅ Complete
- **Delivered:**
  - App icon design (1024x1024 master)
  - Icon in Asset Catalog (system rounds corners)
  - Launch screen (SwiftUI view with branding)
  - Renders correctly on Home Screen, App Library
  - Design meets iOS Human Interface Guidelines

#### M2.6: Accessibility Refinements ✅
- **Owner:** Linus (iOS UI Dev) + Livingston (Tester)
- **Status:** ✅ Complete
- **Delivered:**
  - VoiceOver labels refined for all UI elements
  - Dynamic Type support (text scales 100%–200%)
  - Reduce Motion support (overlay animations disabled if enabled)
  - High Contrast mode validation
  - Color blindness simulation testing
  - Countdown ZStack split into static label + live `.accessibilityValue`
  - Accessibility audit: WCAG AA compliance verified

#### M2.7: Screen-Time Triggers 🆕 ✅
- **Owner:** Basher (Services Dev) + Linus (iOS UI Dev)
- **Status:** ✅ Complete
- **Delivered:**
  - **Behavioral shift:** Wall-clock intervals → continuous screen-on time
  - `ScreenTimeTracker` service with foreground `Timer` + lifecycle observers
  - `UIApplication.didBecomeActiveNotification` (screen ON) / `willResignActiveNotification` (screen OFF)
  - 5-second grace period on app backgrounding (tolerate brief interruptions)
  - Two independent counters (eyes: 20 min, posture: 30 min)
  - Snooze disables tracker, resumes from 0 after snooze ends
  - No background modes declared; 1s Timer coalesces with system timers
  - Copy updated: "after X min of screen time" (not "every")
  - 71+ unit tests for grace period, independent thresholds, snooze suppression

#### M2.8: Data-Driven Configuration ✅
- **Owner:** Basher (Services Dev), Tess (UI/UX Designer), Linus (iOS UI Dev)
- **Status:** ✅ Complete
- **Delivered:**
  - **Asset Catalog:** 6 semantic color tokens with OS-managed dark/light variants
    - Colors: `reminderBlue`, `reminderGreen`, `reminderWarning`, `overlayBackground`, `surfaceBackground`, `labelSecondary`
    - All `UIColor(dynamicProvider:)` calls removed; DesignSystem.swift simplified
  - **String Catalog:** `Localizable.xcstrings` with 35+ user-facing keys
    - All bare string literals replaced with `Text("key")` / `String(localized:)`
    - Localization-ready; supports pluralization and variable interpolation
  - **`defaults.json` bundled:** Settings, intervals, break durations, feature flags (~10 values)
    - `DefaultsLoader` seeds `UserDefaults` on first launch only
    - `SettingsStore.resetToDefaults()` re-seeds from JSON (same code path)
  - Unit tests for `DefaultsLoader` with fixture bundle injection

#### M2.10: Yin-Yang Logo Animation (Restful Grove Redesign) ✅
- **Owner:** Tess (UI/UX Designer) + Linus (iOS UI Dev)
- **Status:** ✅ Complete
- **Context:** Part of the Restful Grove visual redesign (issues #158–#169). HTML prototype iterated through 10+ versions before final design approved.
- **Delivered:**
  - Custom yin-yang symbol drawn with SwiftUI `Path` (not SF Symbol icons)
  - Colors: Sage (`#2F6F5E` / `AppColor.primaryRest`) + Mint (`#EEF6F1` / `AppColor.surfaceTint`)
  - Two-phase animation sequence:
    1. **Spin:** 360° rotation over 2s with deceleration easing
    2. **Breathing pulse:** 4s scale-up, 4s scale-down, infinite loop
  - `accessibilityReduceMotion` support: static logo with no animation when Reduce Motion is enabled
  - Used on `HomeView` and `OnboardingView` as the primary brand mark
- **Design Decisions:**
  - SwiftUI `Path` chosen over SF Symbols for unique brand identity and precise color control
  - Sage/Mint palette aligns with Restful Grove's calming wellness aesthetic
  - Spin → breathe sequence conveys "settle in, then relax" — mirrors the app's purpose
  - Reduce-motion fallback ensures WCAG AA accessibility compliance

#### M2.9: App Store Preparation 🔄
- **Owner:** Danny (Product Manager) + Frank (Legal Advisor)
- **Status:** 🔄 IN PROGRESS
- **Delivered so far:**
  - App Store listing documented: description, keywords, privacy policy
  - Screenshots planned (5 key screens)
  - Privacy Policy filed: MetricKit diagnostics and App Store Connect analytics disclosed; no third-party SDKs
  - Disclaimer & legal docs completed (Frank)
  - Version scheme: v0.1.0-beta (TestFlight), v1.0+ (App Store)
  - **Outstanding:** Final code review, TestFlight submission (awaiting decision)

### Phase 2 Success Criteria
- ✅ Onboarding guides new users smoothly
- ✅ Haptic feedback enhances tactile experience (optional toggle)
- ✅ Snooze action functional with limits (max 2 consecutive)
- ✅ Smart Pause pauses reminders during Focus Mode, CarPlay, or driving
- ✅ Grace period tolerates brief interruptions (5s)
- ✅ Disclaimer UI displayed on onboarding and accessible in Settings
- ✅ App icon and launch screen polished
- ✅ Accessibility meets WCAG AA (all screens tested)
- ✅ Data-driven config: colors via Asset Catalog, copy via String Catalog, settings seeded from defaults.json
- ✅ All devices tested (iPhone SE, iPhone 14 Pro, iPad Pro, accessibility modes)
- 🔄 App Store listing ready (awaiting submission decision)

---

## Phase 3: Interrupt Mode MVP 🔄 IN PROGRESS

**Goal:** Pivot core product to Apple Screen Time APIs (FamilyControls + DeviceActivity + ManagedSettings) to shield distracting apps during break reminders. Local notifications become fallback only.

**Status:** In progress. Entitlement approval pending (Case ID 102881605113). Architecture spike complete. Extension targets and app/category picker in scope.

**Why This Pivot:**
kshana's overlay reminders are valuable, but iOS allows truly **interruptive** behavior only through Screen Time APIs. By integrating FamilyControls and DeviceActivity, we can:
1. **Shield apps** (block category or specific app) when a break reminder fires
2. **Enforce** the break (user cannot dismiss the shield immediately)
3. **Resume** monitoring when break ends
4. Provide **true interruption** (not just a reminder notification)

Local notification fallback ensures we gracefully degrade if Screen Time APIs unavailable or if user hasn't granted FamilyControls permission.

### Architecture Changes (Phase 3)

#### New Targets & Frameworks
- **App Group:** `group.com.kshana.screentime` (shared between main app and extensions)
- **Main App Entitlements:** `com.apple.developer.family-controls` (FamilyControls)
- **ShieldConfiguration Extension:** Implements `ShieldConfigurationProvider` protocol (ManagedSettingsUI)
- **ShieldAction Extension:** Implements `ShieldActionProvider` protocol for app/website unblocker buttons
- **New Services:**
  - `DeviceActivityMonitor` — observes screen time via DeviceActivity.monitoredDevices
  - `ManagedSettingsCoordinator` — configures shields via ManagedSettings
  - `AppCategoryPicker` — UI for category/app selection
  - `AppGroupBridge` — inter-process communication (main app ↔ extensions)

#### Data Flow (Phase 3)
```
Reminder fires (via ScreenTimeTracker)
    ↓
AppCoordinator.handleBreakNeeded()
    ↓
ManagedSettingsCoordinator.shieldAppsForBreak()
    ↓
ManagedSettings.apply() — shield config pushed to DeviceActivity
    ↓
ShieldConfiguration extension receives via ShieldConfigurationProvider
    ↓
Shield renders on device (user cannot bypass immediately)
    ↓
Break duration elapses
    ↓
ManagedSettingsCoordinator.clearShields()
    ↓
Device resumes normal activity
    ↓
(If break dismissed/snoozed, notification fallback sent)
```

### Milestones (Phase 3)

#### M3.1: Entitlement Approval Follow-up 🔴 BLOCKER
- **Owner:** Frank (Legal) + Danny (PM)
- **Status:** 🔴 BLOCKED (Case ID 102881605113)
- **Scope:**
  - Follow up on FamilyControls entitlement approval with Apple
  - Prepare entitlement request submission if rejected
  - Ensure privacy policy + terms updated for data controller role (Screen Time data)
- **Dependencies:** None (parallel track)
- **Duration:** 2–5 days (Apple review SLA)
- **Acceptance Criteria:**
  - Entitlement approved OR clear rejection reason received
  - Privacy policy updated if needed

#### M3.2: Screen Time Shield Spike 🔄
- **Owner:** Rusty (Architect)
- **Status:** 🔄 IN PROGRESS
- **Scope:**
  - Research ShieldConfiguration protocol, ManagedSettingsUI extension architecture
  - Prototype extension target scaffolding in Xcode
  - Validate app group communication (UserDefaults + file sharing)
  - Performance testing: extension launch time, shield render latency
- **Dependencies:** M3.1 (need entitlement approved)
- **Duration:** 4 days
- **Acceptance Criteria:**
  - Extension compiles and runs in simulator
  - App group communication verified (main app → extension)
  - Shield renders on DeviceActivity trigger

#### M3.3: Project & Extension Target Setup
- **Owner:** Basher (Services Dev) + Virgil (CI/CD)
- **Status:** 🔄 PLANNED
- **Scope:**
  - Add ShieldConfiguration extension target to Xcode project
  - Add ShieldAction extension target (optional first phase)
  - Configure Info.plist for extensions (NSExtensionPointIdentifier)
  - Add app group to main app + both extensions
  - Update CI/CD to build/test both targets
  - Code signing: ensure extension provisioning profiles included
- **Dependencies:** M3.2 spike complete
- **Duration:** 3 days
- **Acceptance Criteria:**
  - Both extension targets build without errors
  - CI/CD pipeline builds and signs both targets
  - App group shared container accessible from both targets

#### M3.4: Authorization + App/Category Picker
- **Owner:** Linus (iOS UI Dev) + Basher (Services Dev)
- **Status:** 🔄 PLANNED
- **Scope:**
  - FamilyControls authorization flow (request + gating)
  - App/category selection UI (form picker, category browser)
  - Persist selection to app group shared state
  - Fallback UI if authorization denied (show notification-only reminder)
  - UX copy for authorization screen (explain why we need Screen Time access)
- **Dependencies:** M3.3 targets ready
- **Duration:** 5 days
- **Acceptance Criteria:**
  - User can authorize FamilyControls on first launch
  - App/category picker populated with device apps
  - Selection persisted to app group store
  - Authorization denial gracefully falls back to notification reminders

#### M3.5: DeviceActivity Monitoring
- **Owner:** Basher (Services Dev)
- **Status:** 🔄 PLANNED
- **Scope:**
  - `DeviceActivityMonitor` service tracks screen-on time per app/category (via ScreenTime APIs)
  - Integrate with existing ScreenTimeTracker (bridge to new API)
  - Test DeviceActivity schedule updates
  - Edge cases: app backgrounding, device lock, multi-app scenarios
- **Dependencies:** M3.3, M3.4
- **Duration:** 4 days
- **Acceptance Criteria:**
  - DeviceActivityMonitor detects apps launched by user
  - Screen time accrual matches expected thresholds
  - Transitions to shield state on break reminder

#### M3.6: ManagedSettings Shielding + ShieldAction Extension
- **Owner:** Basher (Services Dev) + Linus (iOS UI Dev)
- **Status:** 🔄 PLANNED
- **Scope:**
  - `ManagedSettingsCoordinator` applies ManagedSettings.store.shield(applications: [...])
  - ShieldConfiguration extension provides customized shield UI (logo, messaging)
  - ShieldAction extension allows user to request app access ("I need 1 min" button) with confirmation
  - Shield dismissal triggers ManagedSettingsCoordinator.clearShields()
  - Logging: track shield duration, user interactions
- **Dependencies:** M3.5
- **Duration:** 6 days
- **Acceptance Criteria:**
  - ManagedSettings shield applies successfully during break
  - Shield UI renders with custom branding
  - User can request access; coordinator logs request
  - Shield clears after break or manual request

#### M3.7: App Group Shared State & Watchdog
- **Owner:** Basher (Services Dev)
- **Status:** 🔄 PLANNED
- **Scope:**
  - App Group (group.com.kshana.screentime) UserDefaults syncing config + state
  - Main app writes: authorized apps, shield schedule, last shield time
  - Extensions read: config for shield rendering
  - Optional watchdog: separate app extension that monitors break compliance (logs to shared container)
  - Testing: verify consistency across app/extensions under edge cases (app restart, extension crash)
- **Dependencies:** M3.6 (shield logic ready)
- **Duration:** 3 days
- **Acceptance Criteria:**
  - Main app and extensions share UserDefaults via app group
  - Extensions can read shield configuration
  - No race conditions under concurrent access
  - Logs persistent in app group container

#### M3.8: Pre-Permission UX Refinement
- **Owner:** Reuben (Product Designer) + Linus (iOS UI Dev)
- **Status:** 🔄 PLANNED
- **Scope:**
  - Onboarding redesign (Phase 2 was notification-centric; Phase 3 emphasizes Screen Time interruption)
  - New permission screen: "Let kshana pause distracting apps during breaks" (explain benefit + privacy)
  - App/category picker introduced as setup step (after permission granted)
  - Fallback messaging if FamilyControls unavailable (older iOS or denial)
  - Copy review: ensure language avoids "surveillance" (emphasize user control)
- **Dependencies:** M3.4 (authorization flow) + M3.8 design time
- **Duration:** 4 days
- **Acceptance Criteria:**
  - Onboarding flow explains Screen Time interruption
  - User understands privacy (data is local only, no cloud logging)
  - App picker reachable before first break reminder
  - Fallback messaging clear if permission denied

#### M3.9: Privacy & Legal Updates
- **Owner:** Frank (Legal) + Danny (PM)
- **Status:** 🔄 PLANNED
- **Scope:**
  - Privacy policy: disclose Screen Time data handling (only local device, no cloud storage)
  - Terms of Service: clarify app is not parental control software (user is device owner)
  - New disclaimer: "kshana uses Apple FamilyControls APIs for user-owned devices only"
  - Lawyer review before App Store resubmission
- **Dependencies:** M3.1 entitlement approval
- **Duration:** 3 days
- **Acceptance Criteria:**
  - Privacy policy reviewed by legal team
  - Terms clarify use case (wellness, not parental control)
  - No App Store rejection on data handling grounds

#### M3.10: CI/CD & Code Signing for Extensions
- **Owner:** Virgil (CI/CD Dev)
- **Status:** 🔄 PLANNED
- **Scope:**
  - Update GitHub Actions to build + sign extension targets
  - Extension provisioning profiles (development + distribution)
  - Entitlements file for extensions (app group, family controls, shield points)
  - TestFlight build includes extensions
  - App Store Connect setup: extension availability
- **Dependencies:** M3.3 targets + M3.1 entitlement approved
- **Duration:** 3 days
- **Acceptance Criteria:**
  - CI builds extensions without errors
  - TestFlight build includes both extensions
  - Code signing validation passes
  - App Store Connect accepts app + extensions

#### M3.11: Local Notification Fallback Positioning
- **Owner:** Basher (Services Dev) + Linus (iOS UI Dev)
- **Status:** 🔄 PLANNED
- **Scope:**
  - Refactor notification scheduling: only send if Screen Time shield fails/unavailable
  - Update notification copy to clarify it's a fallback ("Reminder: take a break")
  - New setting: "Remind me if shielding unavailable" (toggle, default on)
  - Logging: track which reminders used shielding vs. notification
- **Dependencies:** M3.6 (shields working)
- **Duration:** 2 days
- **Acceptance Criteria:**
  - Shields prioritized; notifications sent only as fallback
  - Fallback copy is distinct from shield messaging
  - Setting controls notification sending
  - Metrics distinguish shield vs. notification reminders

### Phase 3 Success Criteria
- ✅ FamilyControls entitlement approved (or clear path to approval)
- ✅ App successfully shields distracting apps during break reminders
- ✅ Extension targets compile and sign in CI/CD
- ✅ App group communication verified (main app ↔ extensions)
- ✅ User can authorize, select apps/categories, and receive interruptions
- ✅ Graceful fallback to notifications if Screen Time APIs unavailable
- ✅ Legal review complete; privacy policy updated
- ✅ TestFlight build includes extensions; ready for beta distribution
  - Haptics fire reliably on watch

#### M3.5: Advanced Testing & v1.1 Release
- **Owner:** Livingston (Tester) + Saul (Code Reviewer)
- **Status:** 🔄 PLANNED
- **Deliverables:**
  - iCloud sync edge case testing (offline, account switch, network interruptions)
  - Widget performance testing (battery, memory, update latency)
  - watchOS testing on physical watch (haptics, complications, sync)
  - XCUITest suite completion (all critical flows covered)
  - Code review for new components
  - Final version tagging and App Store update submission (v1.1.0)
- **Dependencies:** M3.1, M3.2, M3.3, M3.4 complete
- **Duration:** 3 days
- **Acceptance Criteria:**
  - All new features tested and verified
  - Performance benchmarks met (battery < 2% additional per day)
  - v1.1.0 submitted to App Store

### Phase 3 Success Criteria
- ✅ Dependency injection protocols in place (all services injectable)
- ✅ Settings sync via iCloud across devices
- ✅ Home Screen widget displays next reminder times accurately
- ✅ watchOS companion functional with haptics and complications
- ✅ Battery impact < 2% additional per day (all features combined)
- ✅ XCUITest suite comprehensive (80%+ coverage of user flows)
- ✅ v1.1.0 released successfully

### Phase 3 Risks & Open Questions
- **Risk:** watchOS development expertise gap on team → **Mitigation:** Linus to complete watchOS tutorial early in M3.4
- **Risk:** Widget timeline updates impact battery more than expected → **Mitigation:** Early measurement in M3.3, adjust update frequency as needed
- **Question:** Should we add Siri Shortcuts? → **Decision:** Evaluate post-Phase 3 based on user feedback
- **Question:** Multi-user support (Family Sharing)? → **Decision:** Defer to Phase 4 (v1.2+)

---

## Timeline & Status

| Phase | Status | Milestones | Notes |
|---|---|---|---|
| **Phase 0** | ✅ Complete | M0.1–M0.6 | 2 weeks; all foundation work shipped |
| **Phase 1** | ✅ Complete | M1.1–M1.8 | 3 weeks; MVP with 65+ unit tests, notifications, overlay |
| **Phase 2** | 🔄 ~95% | M2.1–M2.10 | 4 weeks; screen-time triggers, smart pause, onboarding, haptics, data-driven config, yin-yang logo animation, 7 quality passes, Restful Grove identity; App Store prep in final stages |
| **Phase 3** | 🔄 Started | M3.1–M3.5 | Planned 3+ weeks; DI refactoring in progress (issues #13-14); iCloud sync, widgets, watchOS deferred |

**Current Project Status:** v0.2.0 (Restful Grove) tagged and shipped. Awaiting decision on TestFlight/App Store submission (Phase 2 ~95%, Phase 3 optional).

---

## Open Issues & Backlog

| Issue | Status | Owner | Priority |
|---|---|---|---|
| #14 | 🔄 In Progress | Livingston | HIGH – Add ScreenTimeTracking protocol for DI |
| #13 | 🔄 In Progress | Livingston | HIGH – Inject PauseConditionManager via protocol |
| #12 | 🔄 In Progress | Livingston | HIGH – Add common Lifecycle protocol for services |
| #2 | 🔄 Blocked | Rusty | MEDIUM – Fill in legal document placeholders (Frank to complete) |

**Phase 2 Complete (Closed):** #11 (test fixes), #10 (integration tests), #9 (UI tests), #8 (test architecture), #7 (PauseConditionManager), #6 (pause tests), #5 (disclaimer UI), #4 (docs update), #3 (pause settings UI)

---

## Open Questions & Decisions Needed

### Before App Store Submission
1. **Q:** Approve TestFlight submission?  
   **Owner:** Danny  
   **Decision:** Pending — Phase 2 complete, ready to submit

2. **Q:** Should Phase 3 (iCloud, widgets, watchOS) be in v1.0 or v1.1?  
   **Owner:** Danny  
   **Recommendation:** Defer to v1.1 post-launch (Phase 2 scope sufficient for v1.0)

3. **Q:** Confirm bundle ID and App Store Connect account  
   **Owner:** Danny + Yashasg  
   **Deadline:** Before submission

### Post-Launch (Phase 3+)
4. **Q:** Enable analytics (Mixpanel, Firebase)?  
   **Owner:** Turk (Data Analyst)  
   **Deadline:** v1.2 or later (maintain zero-data-collection stance in v1.0/v1.1)

5. **Q:** Siri Shortcuts support?  
   **Owner:** Danny  
   **Recommendation:** Evaluate user feedback post-Phase 3

6. **Q:** Multi-user / Family Sharing?  
   **Owner:** Danny + Rusty  
   **Recommendation:** Phase 4 (v1.2+)

---

## Risk Register (Updated)

| Risk | Probability | Impact | Status | Mitigation |
|---|---|---|---|---|
| Dependency injection refactoring breaks tests | Medium | Medium | 🔄 Active | Livingston testing M3.1; existing tests guard against regressions |
| App Store submission delay | Low | High | 🔄 Active | Phase 2 complete; awaiting decision to proceed |
| watchOS development expertise gap | Medium | Low | 🔄 Active | Defer to M3.4; Linus to upskill early |
| Widget battery impact exceeds targets | Low | Low | 🔄 Active | Measure early in M3.3; adjust update frequency |
| iCloud sync conflicts (edge cases) | Low | Medium | 🔄 Active | Last-write-wins strategy + logging in M3.2 |
| Phase 3 timeline slips | Medium | Low | 🔄 Active | Phase 1+2 complete; Phase 3 is optional post-launch |

---

## Success Metrics (Current vs. Target)

### Technical Performance (Phase 1+2 Delivered)
- ✅ **Crash-Free Rate:** Target 99.5%+ (to measure post-launch)
- ✅ **Battery Impact:** < 3% per day (actual: ~1–2% measured via ScreenTimeTracker)
- ✅ **Average Memory Usage:** < 30 MB idle (validated)
- ✅ **Unit Test Coverage:** 81%+ (achieved: 1,382 unit tests + 53 UI tests across Models, Services, ViewModels, Views, Pause)

### User Experience (Phase 1+2 Delivered)
- ✅ **Onboarding Completion:** 90%+ of first-launch users reach Settings (to measure post-launch)
- ✅ **Accessibility:** WCAG AA compliance (verified; VoiceOver, Dynamic Type, Reduce Motion all functional)
- ✅ **Dark Mode:** Fully supported (Asset Catalog, system-managed light/dark variants)

### Design & Architecture (Phase 1+2 Delivered)
- ✅ **No Dependency Conflicts:** 🔄 In progress (M3.1 refactoring for full DI)
- ✅ **Native Config:** Asset Catalog (colors), String Catalog (copy), defaults.json (settings) — all integrated
- ✅ **Zero Third-Party Dependencies:** Maintained (SwiftUI, UIKit, UserNotifications only)

---

## Key Decisions Logged

- **Decision 1.1 (Basher, Phase 1):** SettingsViewModel owns preset options (canonical source)
- **Decision 1.2 (Linus, Phase 1):** Overlay swipe-UP dismiss (fixes earlier bug)
- **Decision 2.1 (Rusty + Basher, Phase 2):** Screen-time triggers replace wall-clock intervals; 5s grace period on app backgrounding
- **Decision 2.2 (Basher, Phase 2):** Dual snooze wake mechanism (in-process Task + silent notification); max 2 consecutive snoozes
- **Decision 2.3 (Basher, Phase 2):** Data-driven config via native Apple formats (Asset Catalog, String Catalog, defaults.json)
- **Decision 2.4 (Tess + Danny, Phase 2):** Yin-yang logo uses custom SwiftUI Path (not SF Symbols); Sage/Mint colors; spin→breathe animation with reduce-motion fallback (Restful Grove redesign)
- **Decision 3.1 (Livingston + Rusty, Phase 3):** Dependency injection refactoring to extract Lifecycle protocol and inject services via protocols

---

## Dependency Map (Critical Path – Updated)

```
Phase 0: Foundation ✅
  M0.1 (Xcode Setup)
    ↓
  M0.2 (Architecture) ──→ M0.3 (CI/CD) ✅
    ↓                         ↓
  M0.6 (Test Strategy)       (M0.4 Design, M0.5 Journeys) ✅
    ↓
  Phase 0 Complete ✅

Phase 1: MVP ✅
  M0.2 → M1.1 (Persistent Settings)
           ↓
  M0.4 → M1.2 (Settings UI) ←──────┐
           ↓                         |
  M1.1 → M1.3 (Notifications)       |
           ↓                         |
  M1.3 → M1.4 (AppDelegate)         |
           ↓                         |
  M1.4 → M1.5 (Overlay Window) ──→ M1.6 (Integration)
           ↓
  M1.6 → M1.7 (Testing) → M1.8 (Code Review) ✅

Phase 2: Polish 🔄 ~95%
  M1.2 + M0.5 → M2.1 (Onboarding) ✅
  M1.5 → M2.2 (Haptics) ✅
  M1.4 → M2.3 (Snooze) ✅
  M1.3 + Phase 1 → M2.3b (Smart Pause) ✅
  M2.1 → M2.4 (Disclaimer UI) ✅
  M0.4 → M2.5 (App Icon) ✅
  M1.2 + M1.5 → M2.6 (Accessibility) ✅
  Phase 1 → M2.7 (Screen-Time Triggers) ✅
  M1.1 + M0.4 + M2.1 → M2.8 (Data-Driven Config) ✅
  M0.4 + M2.5 → M2.10 (Yin-Yang Logo Animation) ✅
  M2.6 → M2.9 (App Store Prep) 🔄

Phase 3: Advanced 🔄 Partially Started
  Phase 2 → M3.1 (Dependency Injection Refactoring) 🔄 (issues #13-14)
  M1.1 → M3.2 (iCloud Sync) 🔄 Planned
  M1.1 + M3.2 → M3.3 (Widget) 🔄 Planned
  M3.2 → M3.4 (watchOS) 🔄 Planned
  M3.1 + M3.2 + M3.3 + M3.4 → M3.5 (Advanced Testing & Release) 🔄 Planned
```

---

## Final Status Summary

**What's Been Built:**
- ✅ Full MVP (Phase 1): Settings, notifications, overlay with countdown, haptics, snooze
- ✅ Polish (Phase 2): Onboarding (3 screens), smart pause (Focus/CarPlay/driving), accessibility (WCAG AA), data-driven config (Asset Catalog + String Catalog + defaults.json), screen-time triggers (continuous screen-on time with grace period), yin-yang logo animation (Restful Grove redesign — custom SwiftUI Path, spin→breathe, reduce-motion support)
- ✅ Test Coverage: 71+ unit tests, XCUITest scaffold (HomeScreen, Settings, Onboarding flows)
- ✅ Architecture: MVVM established, ScreenTimeTracker service, PauseConditionManager with three detectors, protocols for testability
- ✅ Team: 13 members (PM, Design, Architect, 2 iOS Devs, Tester, Code Reviewer, Legal, CI/CD, Data Analyst, Formatter, Scribe)

**Ready for:**
- 🔄 App Store submission (Phase 2 complete, docs ready, privacy policy published)
- 🔄 TestFlight beta distribution
- 🔄 Phase 3 (dependency injection refactoring + iCloud/widgets/watchOS post-launch)

**Next Decision:** Approve App Store submission or defer Phase 3 items to v1.0 release? (Recommend: v1.0 with Phase 1+2, Phase 3 as v1.1 post-launch)

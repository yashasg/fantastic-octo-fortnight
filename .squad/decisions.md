# Squad Decisions

## Active Decisions

Phase 1+ implementation decisions. Pre-Phase 1 roadmap decisions archived in decisions-archive.md.

## Governance

- All meaningful changes require team consensus
- Document architectural decisions here
- Keep history focused on work, decisions focused on direction

---

## Phase 1 Implementation Decisions

### Decision: Phase 1 Implementation — Services Layer (M1.1, M1.3, M1.4)
**Author:** Basher (iOS Dev — Services)  
**Date:** 2026-04-24  
**Status:** Implemented

**Decision 1: SettingsViewModel owns preset options (canonical source)**
- Moved `intervalOptions` and `breakDurationOptions` from `ReminderRowView` to `SettingsViewModel` as `static let` arrays
- Added `labelForInterval()` and `labelForBreakDuration()` static formatters
- Impact: Views team can refactor `ReminderRowView` to reference the ViewModel arrays

**Decision 2: OverlayView swipe-UP direction fix**
- Changed dismiss gesture condition from `value.translation.height > 0` (downward) to `value.translation.height < 0` (upward)
- Aligns with team decision that overlay dismisses by swiping UP (naturally reverses the upward slide entrance)
- Bug fix in Views file flagged for Linus team awareness

**Decision 3: Overlay Settings gear button navigates by dismissal**
- Settings gear button calls `onDismiss()` to reveal Settings view behind the overlay
- No deep-link or navigation coordinator needed in Phase 1 (app root IS SettingsView)
- Future Phase 2 may add `DeepLink` mechanism if app gains home/dashboard screen

**Decision 4: Haptic feedback on overlay auto-completion lives in OverlayView**
- `UIImpactFeedbackGenerator(style: .medium)` fired when countdown hits zero
- Lives in `OverlayView.startTimer()` before `onDismiss()` call
- Not in `OverlayManager` to avoid coupling — manager controls window lifecycle, not countdown state

---

### Decision: Phase 1 Implementation — UI Layer (M1.2, M1.5)
**Author:** Linus (iOS Dev — UI)  
**Date:** 2026-04-24  
**Status:** Implemented

**Decision 1: Settings gear on OverlayView calls onDismiss()**
- Overlay has no navigation context — calls `onDismiss()` to reveal Settings view underneath
- Future work on deep-linking requires new parameter in `OverlayManager.showOverlay()`

**Decision 2: accessibilityViewIsModal(true) replaces .accessibilityAddTraits(.isModal)**
- Use `.accessibilityViewIsModal(true)` SwiftUI modifier (iOS 14+)
- Correctly hides other UI elements from VoiceOver while overlay is visible

**Decision 3: isDismissing guard on OverlayView**
- Added `@State private var isDismissing = false` guard in `performDismiss()` and `performAutoDismiss()`
- Prevents duplicate dismissal callbacks if × button and timer complete concurrently
- Ensures `onDismiss()` called exactly once

**Decision 4: Notification permission warning in SettingsView**
- Added non-blocking warning row when `coordinator.notificationAuthStatus == .denied`
- Includes deep-link button to iOS Settings
- Purely informational — does not block other settings (users could be confused why reminders don't fire in background)

---

### Decision: Phase 1 Implementation — Test Suite (M1.7)
**Author:** Livingston (Tester)  
**Date:** 2026-04-24  
**Status:** Implemented

**Decision 1: testTarget Depends on executableTarget**
- Added `testTarget("EyePostureReminderTests", dependencies: ["EyePostureReminder"])` to Package.swift
- Swift 5.9 supports test targets depending on executable targets
- `@main` attribute in `EyePostureReminderApp.swift` does not conflict — test bundles have own entry point
- Caveat: `swift build --target EyePostureReminderTests` fails on macOS (UIKit iOS-only); must use `xcodebuild test` with iOS simulator runtime
- Alternative considered: Extract `EyePostureReminderCore` library target (deferred to avoid restructuring)

**Decision 2: Protocol Locations**
- Both `NotificationScheduling` and `SettingsPersisting` defined inline in implementation files (`ReminderScheduler.swift`, `SettingsStore.swift`)
- NOT extracted to `Protocols/` directory as shown in ARCHITECTURE.md
- Mocks use `@testable import` to access protocols (works regardless of file location)
- Recommendation: If team wants ARCHITECTURE.md structure, Rusty should move protocols; tests do not need changes

**Decision 3: @MainActor Test Pattern for SettingsViewModel**
- `SettingsViewModelTests` marked `@MainActor` at class level
- Async test methods use `try? await Task.sleep(nanoseconds: 200_000_000)` (200ms) after ViewModel action calls
- Allows internally spawned `Task {}` to complete before assertions
- 200ms is generous budget; in practice < 1ms sufficient; increase to 500ms if flaky under CI load
- Alternative: Refactor SettingsViewModel to return `@discardableResult Task<Void, Never>` (cleaner but requires production change)

**Decision 4: MockNotificationCenter Design**
- Maintains two arrays: `addedRequests` (append-only history), `pendingRequests` (live queue)
- Allows independent assertions: "how many add() calls made" vs "what is currently pending"
- For reschedule tests: verify cancel happened AND new request added without interference

**Coverage Achieved (Target: 80%+)**
- Models — ReminderType: ~95%
- Models — ReminderSettings: ~80%
- Models — SettingsStore: ~90%
- Services — ReminderScheduler: ~85%
- ViewModels — SettingsViewModel: ~80%

---

### User Directive: Test-Driven Development
**Author:** Yashasg (via Copilot)  
**Date:** 2026-04-24T09:10:00Z  
**Status:** Active

**Requirement:** Use test-driven development (TDD). Write and run unit tests alongside every feature as it's built — not just at the end. Livingston (Tester) should validate every feature along the way.

**Rationale:** User request to ensure quality at every step and catch bugs early. Phase 1 implementation confirms TDD workflow is operational.

---

### Decision: Phase 1 Implementation — M1.6 Services Integration (Wave 2)
**Author:** Basher (iOS Dev — Services)  
**Date:** 2026-04-24T09:30:00Z  
**Status:** Implemented

**Decision 1: AppCoordinator conforms to ReminderScheduling**
- `SettingsViewModel` had `scheduler: ReminderScheduling` pointing to `coordinator.scheduler` (the raw `ReminderScheduler`)
- Changed `AppCoordinator` to conform to `ReminderScheduling` and `SettingsView` passes `coordinator` directly
- All four protocol methods route through coordinator's auth-aware paths so notifications and fallback timers stay in sync
- Impact: `SettingsViewModelTests` uses `MockReminderScheduler` — no test modifications needed (init signature unchanged)

**Decision 2: Per-type reschedule debounce lives in AppCoordinator**
- Rapid slider changes in `SettingsView` fire `reminderSettingChanged(for:)` many times/second
- `AppCoordinator.reschedule(for:)` debounces per-type using Swift structured concurrency (`Task` cancellation, 300ms window)
- `MockReminderScheduler` has no debounce — existing `SettingsViewModelTests` continue to pass
- Integration-level debounce is production-only; unit tests verify SettingsViewModel dispatch behavior

**Decision 3: Overlay queue replaces silent drop**
- Concurrent `showOverlay` calls are appended to FIFO queue; next entry presented after dismiss
- `clearQueue()` exposed for `cancelAllReminders()` and snooze paths to flush pending overlays
- Prevents reminder loss when eye and posture reminders fire within seconds

**Decision 4: AudioInterruptionManager audio pause/resume logic**
- `pauseExternalAudio()` activates `AVAudioSession` with `.soloAmbient` (interrupts Spotify/Podcasts, respects silent switch)
- `resumeExternalAudio()` deactivates with `.notifyOthersOnDeactivation`
- Wired into `OverlayManager` on every show/dismiss path
- `.soloAmbient` avoids phantom Control Center entry and respects silent switch (vs. `.playback`)

**Decision 5: Background/foreground lifecycle in EyePostureReminderApp**
- `.background` → `coordinator.appWillResignActive()` stops fallback timers
- `.active` after true background (tracked by `wasInBackground @State`) → `coordinator.handleForegroundTransition()` refreshes auth and restarts timers
- Brief `.inactive` interruptions do NOT trigger full reschedule (avoids UNUserNotificationCenter traffic)

---

### Decision: Phase 1 Implementation — M1.6 UI Polish (Wave 2)
**Author:** Linus (iOS Dev — UI)  
**Date:** 2026-04-24T09:30:00Z  
**Status:** Implemented

**Decision 1: AppFont uses semantic text styles for Dynamic Type**
- Migrated `AppFont` from fixed `.system(size:)` to `Font.TextStyle` equivalents
- `headline` → `.system(.title).weight(.bold)`, `body` → `.system(.body)`, `bodyEmphasized` → `.system(.headline)`, `caption` → `.system(.footnote)`, `countdown` → fixed monospaced (decorative, has accessibility label)
- Team rule: New `AppFont` tokens must use text styles or `@ScaledMetric` — never hardcoded `size:` parameters
- Countdown font kept fixed; visually important and replaced by accessibility label for VoiceOver

**Decision 2: OverlayView respects `accessibilityReduceMotion`**
- Added `@Environment(\.accessibilityReduceMotion)` guard to all animation paths (appear, dismiss, auto-dismiss)
- When true: `.onAppear` sets `contentOpacity = 1` without animation; `performDismiss()`/`performAutoDismiss()` set opacity without animation + 50ms grace before callback
- Countdown ring `.animation` becomes `.none`, countdown `Text` `contentTransition` becomes `.identity`
- Team pattern: Check `reduceMotion` at each `withAnimation` site (not global wrapper)

**Decision 3: OverlayView countdown ZStack exposed as single accessibility element**
- Both `Circle()` views → `.accessibilityHidden(true)` (decorative)
- ZStack → `.accessibilityElement(children: .ignore)` + `.accessibilityLabel("\(secondsRemaining) seconds remaining")`
- Type icon `Image` → `.accessibilityHidden(true)` (headline already conveys type)
- Settings gear button → `.accessibilityHint("Dismisses this reminder and reveals Settings")`
- Team pattern: Hide decorative/visual elements; containers combining visual+semantic get explicit labels

**Decision 4: SettingsView requires `import UIKit`**
- Added `import UIKit` to `SettingsView.swift` for `UIApplication.openSettingsURLString` and `.open(url:)`
- SwiftUI does not implicitly re-export UIKit symbols on current Xcode/Swift toolchains
- Compile-correctness fix, not style change

**Decision 5: ReminderType.color migrated to AppColor design tokens**
- Changed `ReminderType.color` from `.blue`/`.green` (system colors) to `AppColor.reminderBlue`/`AppColor.reminderGreen`
- All views (OverlayView, ReminderRowView) now use design-system palette consistently
- `type.color` is single color accessor for reminder types — future changes in `AppColor` only

---

### Decision: Phase 1 Implementation — M1.6 Test Verification (Wave 2)
**Author:** Livingston (Tester)  
**Date:** 2026-04-24T09:30:00Z  
**Status:** Verified

**Finding 1: AppCoordinator scheduler protocol recommendation**
- `AppCoordinator` stores `scheduler: ReminderScheduler` (concrete) not `ReminderScheduling` (protocol)
- `scheduleReminders()`, `startFallbackTimers()`, `stopFallbackTimers()` can only be integration-tested, not unit-tested
- Recommendation: Address before Phase 2 (not a Phase 1 blocker)

**Finding 2: All mocks and tests verified**
- 27 new tests added, all existing mocks verified against implementations
- Zero API mismatches detected between mocks and actual implementations
- Package.swift alignment confirmed
- Test coverage: 65+ passing tests with thorough coverage of Models, Services, ViewModel

---

### Decision: Phase 1 Implementation — M1.8 Code Review (Wave 2)
**Author:** Saul (Code Reviewer)  
**Date:** 2026-04-24T09:30:00Z  
**Status:** Conditional Approval

**Verdict: CONDITIONAL APPROVAL** — Phase 1 ready for launch. Four P1 issues should be fixed before Phase 2 begins. Zero P0 ship-blockers.

**P1 Issues (Must Fix Before Phase 2):**
1. **P1-1: Snooze bypassed on app relaunch** — `scheduleReminders()` never checks `snoozedUntil`. Fix: Guard snooze in scheduler before rescheduling all reminders. (Basher)
2. **P1-2: AppCoordinator hardcodes `UNUserNotificationCenter.current()`** — Untestable auth flow. Fix: Inject `NotificationScheduling` protocol. (Basher)
3. **P1-3: `OverlayManager.shared` used directly** — Blocks `AppCoordinator` testability. Fix: Inject `OverlayPresenting` protocol. (Basher)
4. **P1-4: Fixed font sizes break Dynamic Type** — NOTE: FIXED in Wave 2 UI work by Linus. All `AppFont` now uses semantic text styles.

**P2 Issues (Nice to Have — 7 total):**
- P2-1: `ReminderType.color` design tokens — FIXED in Wave 2 UI work
- P2-2: `DesignSystem` dead code cleanup
- P2-3: `SettingsView @State` fragility documentation
- P2-4: OverlayView VoiceOver countdown live region
- P2-5: Protocol directory structure alignment (ARCHITECTURE.md vs. colocation)
- P2-6: OverlayView Settings button label clarity
- P2-7: UIImpactFeedbackGenerator haptic timing

**Architecture Conformance:**
- Views → ViewModels: ✅
- ViewModels → Models+Services: ✅
- Services → Models: ⚠️ (OverlayManager creates OverlayView; acceptable UIKit bridge)
- Models → No deps: ✅
- Protocol-based injection: ⚠️ (P1-2 & P1-3 bypass protocols)
- MVVM pattern: ✅

**Positive Observations:**
- Clean MVVM, strong protocol-driven testability
- 65+ tests, thorough coverage, no API mismatches
- No force unwraps, no hardcoded credentials, no retain cycles
- Correct thread safety (@MainActor)
- No security concerns
- Design system centralized

**Recommendation:** Phase 1 is production-quality for its scope. Track P1 issues in backlog; address before Phase 2 coding begins. Phase 1 launch is unblocked.

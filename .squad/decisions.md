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

---

### Decision: Phase 1 P1/P2 Fixes + Phase 2 M2.2–M2.3 Kickoff (Wave 3)
**Authors:** Basher (iOS Dev — Services), Linus (iOS Dev — UI)  
**Date:** 2026-04-24T09:50:00Z  
**Status:** Implemented

#### Basher — P1 Fixes + M2.3 Snooze Implementation

**Decision 1: NotificationScheduling protocol replaces hardcoded UNUserNotificationCenter**
- `AppCoordinator` now conforms to `NotificationScheduling` protocol with `getAuthorizationStatus() async -> UNAuthorizationStatus`
- Resolves P1-2 (hardcoded `UNUserNotificationCenter.current()` was untestable)
- Rationale: `UNNotificationSettings` has no public initializer; returning `UNAuthorizationStatus` directly is simpler and fully mockable
- Impact: All auth-dependent flows now protocol-injected; unit tests remain unchanged

**Decision 2: overlayManager default via nil-coalescing in init, not parameter default**
- `AppCoordinator.init` declares `overlayManager: OverlayPresenting? = nil`, resolves to `OverlayManager.shared` inside init body
- Rationale: Swift disallows `@MainActor`-isolated values as default parameter expressions; nil-coalescing in body avoids actor-isolation compiler errors
- Impact: Ergonomic call sites preserved; AppCoordinator testability unblocked

**Decision 3: Snooze wake mechanism — dual Task + silent notification**
- When snooze is detected in `scheduleReminders()`, two wake paths armed:
  1. In-process `Task` with `sleep(until:)` — fires while app in foreground/background
  2. Silent `UNNotificationRequest` with `snoozeWakeCategory` — fires even if app killed
- Rationale: Task alone insufficient if app killed; notification alone requires user tap. Dual ensures seamless auto-resume in all lifecycle states
- Implementation: In-process task cancels notification when it fires; notification routes to `scheduleReminders()` which cancels task
- Impact: Snooze survives app termination and relaunch

**Decision 4: Snooze count reset — three places for invariant consistency**
- `snoozeCount` reset to 0 in:
  1. `handleNotification(for:)` — real reminder overlay fired
  2. `cancelSnooze()` — user manually cancelled
  3. `scheduleReminders()` when snooze expiry detected — alongside `snoozedUntil = nil`
- Rationale: Count tracks "consecutive snoozes without real reminder". All three represent snooze cycle end
- Impact: Invariant clean and predictable; count limit (2 snoozes max) prevents user override abuse

**Decision 5: snooze(for:) preserved for backward compatibility**
- Existing `snooze(for minutes: Int)` method retained with same contract: `cancelAllReminders()` + no `scheduleReminders()`
- New `snooze(option: SnoozeOption)` is forward-looking API for M2.3+
- Rationale: Existing `SettingsViewModelTests` assert specific call counts; changing contract requires test rewrites
- Impact: No test modifications needed; gradual migration path

**Decision 6: SnoozeOption.restOfDay — DST-aware endDate computation**
- `restOfDay` computes as `Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))`
- Falls back to `Date() + 24h` if Calendar returns nil
- Rationale: Correctly maps to midnight of current day in user's local timezone, regardless of DST transitions
- Impact: Snooze boundaries always align with midnight in user's timezone (no off-by-one errors on DST change days)

#### Linus — P1/P2 Fixes + M2.2 Haptics

**Decision 7: Countdown VoiceOver — split static label + dynamic value**
- Countdown ZStack uses `.accessibilityLabel("Countdown timer")` (static) + `.accessibilityValue("\(n) seconds remaining")` (dynamic) + `.updatesFrequently` trait
- Replaces previous single-label approach
- Rationale: VoiceOver's value property is semantically designed for live-updating values (sliders, progress rings, timers). Static label + live value is correct iOS pattern
- Impact: VoiceOver users now hear label once, then live countdown; UI remains unchanged for sighted users

**Decision 8: hapticsEnabled parameter at call-site (not SettingsStore injection)**
- `OverlayPresenting.showOverlay()` accepts `hapticsEnabled: Bool` parameter
- AppCoordinator reads `settings.hapticsEnabled` and passes through at call-site
- Rationale: OverlayManager must remain testable without live SettingsStore. Passing bool at call-site keeps service layer clean and avoids coupling UIKit to ObservableObject
- Impact: OverlayManager stays pure; no test modifications for haptic parameter

**Decision 9: Haptic generator lifecycle — onAppear + prepare()**
- Both `UIImpactFeedbackGenerator` and `UINotificationFeedbackGenerator` created as `@State` optionals, initialized with `.prepare()` in `onAppear`
- Rationale: UIKit haptic generators should be prepared before use to ensure Taptic Engine is warm. Creating per-tap risked first haptic firing late. Creating in onAppear gives full overlay lifetime for preparation
- Impact: Haptic feedback instantaneous; no delay on first user interaction

**Decision 10: Dead Color extension removed — AppColor is sole color token**
- `Color` extension with named-asset lookups and non-functional `fallback()` helper permanently removed
- `AppColor` enum is single source of color tokens
- Rationale: Color extension was dead code (nothing referenced it); fallback() returned self unconditionally. AppColor provides reliable literal colors until asset catalog added
- Impact: Simplified codebase; no competing color systems; design tokens centralized
# Decision: SPM Executable Target Requires Post-Build .app Bundle Assembly

**Author:** Virgil (CI/CD Dev)  
**Date:** 2026-04-24  
**Status:** Implemented  

## Problem

`Package.swift` declares `executableTarget("EyePostureReminder", ...)`. When built with `xcodebuild`, this target produces a flat Mach-O binary at:

```
DerivedData/Build/Products/Debug-iphonesimulator/EyePostureReminder
```

`xcrun simctl install` requires a `.app` bundle (a directory with `Info.plist` + executable). Without the bundle, `run.sh` failed with:

```
✗ App bundle not found at: .../EyePostureReminder.app
✗ Run without --no-build to build first.
```

...even when the build had just succeeded.

## Decision

Add `assemble_app_bundle()` to `scripts/run.sh`. It runs immediately after `build_for_simulator()` and:

1. Skips if a `.app` directory already exists (future-proof if xcodebuild ever produces one)
2. Creates `DerivedData/Build/Products/Debug-iphonesimulator/EyePostureReminder.app/`
3. Copies the flat executable into the bundle
4. Processes `EyePostureReminder/Info.plist` via `sed` to substitute build variable placeholders:
   - `$(PRODUCT_BUNDLE_IDENTIFIER)` → derived bundle ID
   - `$(EXECUTABLE_NAME)` → scheme name
   - `$(PRODUCT_NAME)` → scheme name
5. Derives bundle ID as `{workspace-name}.{scheme}` (SPM auto-convention: `fantastic-octo-fortnight.EyePostureReminder`)

## Rationale

This project uses a Swift Package rather than an Xcode `.xcodeproj`. SPM `executableTarget` builds command-line tool binaries, not iOS app bundles. Creating a real Xcode project with an App target would be the long-term solution, but that is a larger structural change. The assembly step is minimal, self-documenting, and keeps the project Swift Package-only.

## Alternatives Considered

- **Create an Xcode .xcodeproj with App target** — correct long-term, but out of scope for this fix
- **Use `xcrun simctl spawn`** — runs a binary directly without install; not appropriate for a SwiftUI App

## Impact

- `scripts/run.sh` now works end-to-end: build → assemble bundle → install → launch
- `--no-build` flag continues to work on subsequent runs (assembled `.app` persists across runs)
- No changes to `build.sh`, CI workflows, or `Package.swift`

---

### Decision: ReminderScheduler — short-interval notification repeats

**Author:** Basher (iOS Dev — Services)  
**Date:** 2026-04-25  
**Status:** Implemented

#### Context

`UNTimeIntervalNotificationTrigger(timeInterval:repeats:)` enforces a minimum of 60 seconds when `repeats: true`. For any interval below that threshold, the OS rejects the request with an error and no notification fires.

#### Decision

`ReminderScheduler.rescheduleReminder` now derives the `repeats` flag dynamically:

```swift
repeats: reminderSettings.interval >= 60
```

- Intervals ≥ 60s: unchanged — the OS repeats the notification automatically.
- Intervals < 60s: schedules a one-shot notification. After it fires, no further notification is scheduled automatically; the foreground fallback timer (`AppCoordinator.startFallbackTimer`) handles repeating via a plain `Timer` with no OS minimum.

#### Impact

- **Normal production behaviour is identical** — production defaults are 1200s/1800s (≥ 60s), so `repeats` stays `true`.
- **Short-interval test mode** (e.g. 10s): notifications grant one delivery; the fallback timer provides continuous repeating coverage in the foreground.
- **Tests:** `ReminderSchedulerTests` that assert `trigger?.timeInterval` are unaffected. Tests that inspect `trigger?.repeats` with intervals < 60s should now expect `false`.

#### Revert Note

This change should be kept permanently — it is a correctness fix, not just a testing aid. Even after the 10s default is reverted, the guard prevents a latent crash path if a user somehow sets an interval < 60s via future UI changes.

---

### Decision: Dark Mode — Product Spec

**Author:** Danny (PM)  
**Date:** 2026-04-24  
**Status:** Ready for implementation  
**For:** Tess (UI/UX), Linus (iOS Dev — UI)

#### Requirement

The app must always follow the system appearance. No in-app toggle. No setting. If iOS is in dark mode, the app is dark. If iOS is in light mode, the app is light. Period.

#### Current State: What Already Works (No Code Change Needed)

The app is mostly dark-mode-capable already due to good SwiftUI hygiene:

| Component | Why it's already fine |
|---|---|
| `OverlayView` background | Uses `.ultraThinMaterial` — system material, adapts automatically |
| `OverlayView` dismiss/settings buttons | Use `.foregroundStyle(.secondary)` — semantic, adapts |
| `OverlayView` countdown ring track | Uses `Color.secondary.opacity(0.3)` — adapts |
| `SettingsView` (Form) | SwiftUI `Form` uses system grouped style — adapts |
| `HomeView` | Uses `.secondary` semantic color + system navigation — adapts |
| All onboarding materials | `.regularMaterial` backgrounds — adapt |
| Onboarding accent colors | `.indigo`, `.green` system colors — adapt |
| `AppColor.warningText` | Already uses `UIColor(dynamicProvider:)` for light/dark variants |
| `AppColor.overlayBackground` | Uses `Color(.systemBackground)` — semantic, adapts |
| Overlay UIWindow | No `overrideUserInterfaceStyle` is set — inherits system appearance correctly |
| App entry point | No `preferredColorScheme` locked anywhere — confirmed via codebase search |

#### What Needs to Change

##### 1. `AppColor.permissionBanner` — Hardcoded Yellow (DesignSystem.swift)

**Current:** `Color(red: 1.0, green: 0.800, blue: 0.0)` — static bright yellow  
**Problem:** Defined for future use (not yet rendered in any view). When it ships, yellow on a dark background looks washed out and has poor contrast with the near-black text companion.  
**Fix:** Convert to `UIColor(dynamicProvider:)` — brighter yellow in light mode, slightly muted amber in dark mode. Keep it accessible.

##### 2. `AppColor.permissionBannerText` — Hardcoded Near-Black (DesignSystem.swift)

**Current:** `Color(red: 0.149, green: 0.149, blue: 0.149)` — static near-black `#262626`  
**Problem:** Defined to pair with the yellow banner. Currently not rendered anywhere, but will be invisible in dark mode if it ever lands on a dark background instead of the yellow banner.  
**Fix:** This color is designed to always sit on the yellow `permissionBanner` background. If the banner always provides its own colored background (not relying on system background), near-black text on yellow is correct regardless of mode. Linus should verify: does the banner always render with an explicit yellow background behind it? If yes — no change needed. If the text could appear without that background — convert to `dynamicProvider`.

##### 3. Hardcoded RGB Accent Colors — Low Risk, Worth Confirming

`AppColor.reminderBlue`, `AppColor.reminderGreen`, `AppColor.warningOrange` are hardcoded RGB. They are used exclusively as **tints on icons and text labels**, never as backgrounds. Both light and dark mode render these colors visibly against system backgrounds. Contrast ratios are acceptable.  
**Action for Tess:** Do a visual QA pass in dark mode. If any accent looks off (too dim or insufficient contrast on dark background), flag it. Linus can wrap in `dynamicProvider` as needed.

#### Screen-by-Screen Audit

| Screen | Dark Mode Status | Notes |
|---|---|---|
| **HomeView** | ✅ Fully adaptive | System nav, semantic colors |
| **SettingsView** | ✅ Fully adaptive | Form + semantic colors throughout |
| **ReminderRowView** | ✅ Fully adaptive | Uses `type.color` (accent) + system Picker/Toggle |
| **OverlayView** | ✅ Fully adaptive | `.ultraThinMaterial` does the heavy lifting |
| **OnboardingWelcomeView** | ✅ Fully adaptive | System colors + `.regularMaterial` |
| **OnboardingPermissionView** | ✅ Fully adaptive | `NotificationPreviewCard` uses `.regularMaterial` |
| **OnboardingSetupView** | ✅ Fully adaptive | Cards use `.regularMaterial` |
| **Permission banner** (future) | ⚠️ Fix before shipping | `permissionBanner` + `permissionBannerText` are hardcoded |

#### Acceptance Criteria

1. **All screens render correctly in both light and dark mode** — no pure white or near-black surfaces where text becomes invisible.
2. **No `preferredColorScheme` or `overrideUserInterfaceStyle` lock is present** in any app file when this ships. (Currently confirmed clean — keep it that way.)
3. **The overlay window** appears in dark mode when the system is dark, light when the system is light. Visually verify by toggling Control Center appearance with the overlay on screen.
4. **`AppColor.permissionBanner` and `AppColor.permissionBannerText`** are converted to adaptive colors (or confirmed safe as-is — see §2 above) before any view renders them. These are not yet used, so this can happen as part of the banner feature's own ticket — but do not ship the banner without resolving this.
5. **Switching system appearance while the app is open** (Settings → Display & Brightness) causes all visible screens to update correctly, without restart.
6. **Visual QA** (Tess): Screenshot light + dark side-by-side for HomeView, SettingsView, OverlayView, and all three onboarding screens. No obvious contrast failures.

#### Edge Cases & Concerns

##### Overlay UIWindow (High Priority)
The `OverlayManager` creates a secondary `UIWindow` at `.alert + 1`. UIWindows created programmatically default to `overrideUserInterfaceStyle = .unspecified`, which correctly inherits from the scene. **This is already correct** — but it's fragile. If anyone ever adds `window.overrideUserInterfaceStyle = .light` for debugging, the overlay breaks in dark mode. Add a code comment in `OverlayManager` near window creation to document this intent explicitly.

##### Onboarding Color Literals (Low Risk)
`OnboardingWelcomeView` and `OnboardingSetupView` use `.indigo` and `.green` as `Color` literals (not via `AppColor`). These are SwiftUI system colors and adapt correctly. No change needed — but note this is a minor deviation from the DesignSystem pattern.

##### `permissionBanner` Colors (Not Yet Rendered)
Both banner colors are defined in `DesignSystem.swift` but grep confirms they are not referenced in any view yet. They are safe to leave as-is for this sprint, as long as the rule is: **do not ship any view that uses these tokens without making them adaptive first**.

#### Out of Scope

- No in-app dark mode toggle (this would contradict the requirement)
- No custom dark/light override per screen
- No changes to the onboarding flow, settings structure, or haptic behavior

#### Implementation Notes for Tess & Linus

**Linus:** The actual code work here is minimal — the app mostly already works. Your two concrete tasks:
1. Add a comment in `OverlayManager` near `UIWindow` creation: no `overrideUserInterfaceStyle` should be set (document the intent).
2. Convert `AppColor.permissionBanner` and `AppColor.permissionBannerText` in `DesignSystem.swift` to use `UIColor(dynamicProvider:)` — matching the existing pattern already used for `AppColor.warningText`.

**Tess:** Visual QA is the main deliverable. Run the app in Simulator with both light and dark appearances. Check all 6 screens listed above. Flag any contrast or color issues to Linus with a screenshot + context.

No new views. No new settings. No new user-facing copy. This is infrastructure hygiene.

---

### Decision: Dark Mode Colour Adaptation — DesignSystem.swift

**Author:** Tess (UI/UX Designer)  
**Date:** 2026-04-25  
**Status:** Implemented

#### Context

The app was asked to fully support OS dark mode. No in-app toggle — colour scheme is OS-controlled exclusively.

#### Decisions

##### 1. No `.preferredColorScheme` anywhere in the app
The app does not set `.preferredColorScheme` on any view. The OS controls appearance. This is permanent policy — if a future feature request asks for an in-app toggle, it should be rejected or escalated.

##### 2. `reminderBlue` is adaptive (UIColor dynamicProvider)
- Light: #4A90D9 (unchanged)
- Dark: #5BA8F0 (slightly brighter — better contrast on near-black backgrounds)
- Rationale: The original hardcoded value reached only ~2.9:1 on dark backgrounds for large icons. The dark variant improves visual pop without changing brand identity.

##### 3. `reminderGreen` uses `Color(.systemGreen)`
- Maps to #34C759 (light) and #30D158 (dark) — iOS system values.
- The original hardcoded #34C759 was identical to system green light mode value, so this change is zero-risk and ensures automatic future adaptation.

##### 4. `warningOrange` is adaptive (UIColor dynamicProvider)
- Light: #E07000 (~3.5:1 on white — passes WCAG 1.4.11 non-text contrast)
- Dark: #FF9500 (6.8:1 on near-black — unchanged from original)
- Rationale: The original static #FF9500 in light mode was only 2.7:1 on white — below the 3:1 WCAG threshold for non-text UI components. This was a real accessibility bug. Fixed as part of dark mode work.

##### 5. `permissionBanner` (yellow) remains static
- #FFCC00 in both modes — intentionally static warning yellow.
- Yellow reads as "caution" regardless of dark/light mode. Making it adaptive risks losing the semantic signal.

##### 6. `permissionBannerText` remains near-black static
- #262626 — exclusively for use on the yellow `permissionBanner` background.
- On yellow in both light and dark mode, near-black text achieves very high contrast (>10:1). No adaptation required.

##### 7. View files required no changes
No `.foregroundColor(.black)`, `.background(.white)`, or `Color.black/white` were found in any view file. All views use semantic/adaptive colors from AppColor or SwiftUI built-ins (`.primary`, `.secondary`, `.ultraThinMaterial`).

#### Impact

- `DesignSystem.swift` — colours section updated
- No view file changes required
- Build verified: ✓ succeeded

---

## Spec: Data-Driven Default Settings

**Author:** Danny (PM)  
**Date:** 2026-04-24  
**Status:** Draft — awaiting team review  
**Implements:** Basher (SettingsStore/ReminderSettings) · Linus (UI reset button)

---

### 1. Problem Statement

Default settings in `ReminderSettings.swift` are hardcoded as Swift `static let` values:

```swift
static let defaultEyes    = ReminderSettings(interval: 10, breakDuration: 20)
static let defaultPosture = ReminderSettings(interval: 10, breakDuration: 10)
```

This creates real friction:

- **Requires a recompile** to change any default value (e.g. swapping test intervals back to production values, tuning break durations).
- **Basher had to edit Swift code** just to set a 10-second test interval — and leave `// TEST OVERRIDE` comments as breadcrumbs to remember to restore them.
- **Blocked by code review** — a timing change goes through the full PR cycle even though no logic changed.
- **Future-hostile** — A/B testing, per-device defaults, or remote config are impossible with static values.

A bundled `defaults.json` file makes defaults a data concern, not a code concern.

---

### 2. Proposed Approach

Bundle a `defaults.json` file with the app. On first launch (or after "Reset to Defaults"), `SettingsStore.init()` reads this file and seeds `UserDefaults`. Subsequent launches read directly from `UserDefaults` — the JSON is never re-applied unless explicitly requested.

No new external dependencies. No network call. Pure bundle resource.

---

### 3. Data Pipeline

```
defaults.json (bundled in app target)
        │
        ▼  (read once: first launch, or on explicit reset)
SettingsStore.init()  ──────────────────────────────────────────────────────┐
        │                                                                    │
        │  seeds missing keys only (UserDefaults wins if key already exists) │
        ▼                                                                    │
UserDefaults (epr.* keys)  ◄── user changes saved here in real time        │
        │                                                                    │
        ▼                                                                    │
@Published properties on SettingsStore  ◄─── "Reset to Defaults" re-reads ─┘
        │
        ▼
SwiftUI Views (SettingsView, ReminderRowView)
```

Key rules:
- JSON is read from `Bundle.main` — no file system writes.
- `SettingsStore` keeps a private `DefaultsLoader` (or inline method) that decodes the JSON.
- `SettingsStore` must remain testable: `DefaultsLoader` accepts a `Bundle` parameter so tests can inject a fixture bundle.

---

### 4. JSON Schema

File: `EyePostureReminder/Resources/defaults.json`

```json
{
  "schemaVersion": 1,
  "masterEnabled": true,
  "eyes": {
    "enabled": true,
    "intervalSeconds": 1200,
    "breakDurationSeconds": 20
  },
  "posture": {
    "enabled": true,
    "intervalSeconds": 1800,
    "breakDurationSeconds": 10
  },
  "pauseMediaDuringBreaks": false,
  "hapticsEnabled": true
}
```

**Field notes:**

| Field | Type | Maps to `epr.*` key | Notes |
|---|---|---|---|
| `schemaVersion` | Int | — | For future migration; not persisted to UserDefaults |
| `masterEnabled` | Bool | `epr.masterEnabled` | |
| `eyes.enabled` | Bool | `epr.eyes.enabled` | |
| `eyes.intervalSeconds` | Double | `epr.eyes.interval` | Production: 1200 (20 min) |
| `eyes.breakDurationSeconds` | Double | `epr.eyes.breakDuration` | 20 seconds (20-20-20 rule) |
| `posture.enabled` | Bool | `epr.posture.enabled` | |
| `posture.intervalSeconds` | Double | `epr.posture.interval` | Production: 1800 (30 min) |
| `posture.breakDurationSeconds` | Double | `epr.posture.breakDuration` | 10 seconds |
| `pauseMediaDuringBreaks` | Bool | `epr.pauseMediaDuringBreaks` | Phase 2; default false |
| `hapticsEnabled` | Bool | `epr.hapticsEnabled` | Default true |

Snooze fields (`snoozedUntil`, `snoozeCount`) are **not** in the JSON — they are runtime state, not defaults.

---

### 5. Override Behavior (UserDefaults Wins)

**On first launch:** No `epr.*` keys exist in UserDefaults. `SettingsStore.init()` reads `defaults.json` and writes all values to UserDefaults. From this point on, user changes are persisted normally.

**On subsequent launches:** `epr.*` keys exist. `SettingsStore.init()` reads from UserDefaults as today — JSON is not consulted.

**Implementation pattern:**
```swift
// Only seed if key is absent — never overwrite a user's saved value
if store.object(forKey: Keys.eyesInterval) == nil {
    store.set(jsonDefaults.eyes.intervalSeconds, forKey: Keys.eyesInterval)
}
```

This is the same pattern `SettingsPersisting` already enforces with `guard object(forKey: key) != nil`.

---

### 6. Reset to Defaults

A **"Reset to Defaults"** button in `SettingsView` (destructive style, behind a confirmation alert):

1. Removes all `epr.*` keys from UserDefaults.
2. Re-runs the JSON seeding logic from `SettingsStore` (same code path as first launch).
3. Updates all `@Published` properties so the UI refreshes immediately.

**Linus owns the UI.** Basher exposes a `resetToDefaults()` method on `SettingsStore`.

```swift
// SettingsStore public API
func resetToDefaults() {
    Keys.allCases.forEach { store.removeObject(forKey: $0.rawValue) }
    seedFromJSON()
    // Re-read all @Published properties from store
}
```

Snooze state (`snoozedUntil`, `snoozeCount`) is also cleared on reset — a reset implies "start fresh."

---

### 7. Future Possibilities (Out of Scope for This Ticket)

- **Remote config:** Swap `Bundle.main` for a downloaded JSON — same decoder, different source. Zero `SettingsStore` logic changes required.
- **A/B testing:** Ship two JSON variants (`defaults-a.json`, `defaults-b.json`), select at launch based on install ID.
- **Per-device defaults:** Different JSON for iPad vs. iPhone (longer intervals on iPad desk use).
- **Build variants:** CI/CD injects a `defaults.json` at build time with test-friendly intervals, eliminating the `// TEST OVERRIDE` pattern entirely.

---

### 8. Acceptance Criteria

- [ ] `defaults.json` is bundled with the app target and contains all non-runtime settings fields.
- [ ] On a fresh install (no UserDefaults), settings are loaded from `defaults.json` — **not** from Swift hardcoded values.
- [ ] On subsequent launches, user changes persist correctly; `defaults.json` is not re-applied.
- [ ] Changing a value in `defaults.json` changes the first-launch experience **without** any Swift code change.
- [ ] `ReminderSettings.defaultEyes` and `ReminderSettings.defaultPosture` static properties are removed (no more `// TEST OVERRIDE` comments in production code).
- [ ] `SettingsStore.resetToDefaults()` clears all `epr.*` keys and re-seeds from JSON; UI updates immediately.
- [ ] "Reset to Defaults" button appears in `SettingsView` with a confirmation alert before executing.
- [ ] Existing unit tests for `SettingsStore` still pass (inject a test `Bundle` with a fixture `defaults.json`).
- [ ] `DefaultsLoader` (or equivalent) is covered by a unit test that decodes a known JSON and verifies all fields map correctly.

---

### 9. Ownership

| Work | Owner |
|---|---|
| `defaults.json` schema + file | Basher |
| `DefaultsLoader` (JSON decoder, `Bundle` injection) | Basher |
| `SettingsStore.init()` JSON seeding (first launch) | Basher |
| `SettingsStore.resetToDefaults()` method | Basher |
| Remove `ReminderSettings.defaultEyes/defaultPosture` statics | Basher |
| "Reset to Defaults" UI button + confirmation alert | Linus |

---

### Decision: SPM Localization Bundle Strategy

**Filed by:** Linus (iOS Dev UI)  
**Date:** 2026-04-26  
**Status:** Implemented

## Decision

For this SPM `executableTarget`, ALL localization calls in SwiftUI views **must** explicitly pass `bundle: .module`. The `Bundle.module` accessor (not `Bundle.main`) is the correct bundle for SPM resource access.

## Rationale

SPM builds an `executableTarget`'s resources into a separate bundle (`EyePostureReminder_EyePostureReminder.bundle`), accessible only via `Bundle.module`. SwiftUI defaults to `Bundle.main` which has no strings — causing raw keys to appear at runtime.

## Required Patterns

| Call site | Correct form |
|-----------|-------------|
| `Text("key")` | `Text("key", bundle: .module)` |
| `String(localized: "key")` | `String(localized: "key", bundle: .module)` |
| `.navigationTitle("key")` | `.navigationTitle(Text("key", bundle: .module))` |
| `.accessibilityLabel("key")` | `.accessibilityLabel(Text("key", bundle: .module))` |
| `.accessibilityHint("key")` | `.accessibilityHint(Text("key", bundle: .module))` |
| `Toggle("key", isOn:)` | `Toggle(isOn:) { Text("key", bundle: .module) }` |
| `Button("key") { }` | `Button(action: {}) { Text("key", bundle: .module) }` |
| `Section("key")` | `Section { } header: { Text("key", bundle: .module) }` |
| `Label("key", systemImage:)` | `Label(title: { Text("key", bundle: .module) }, icon: { Image(systemName:) })` |

## run.sh Requirement

`assemble_app_bundle` in `scripts/run.sh` must embed `EyePostureReminder_EyePostureReminder.bundle` inside the `.app` bundle. Without this step, `Bundle.module` cannot resolve the bundle at simulator runtime because `xcrun simctl install` only installs the `.app`.

## Scope

Applies to all current and future SwiftUI views in `EyePostureReminder/Views/`.
| Unit tests for `DefaultsLoader` and updated `SettingsStore` | Livingston (or Basher) |

---

*Filed by Danny · Questions → open an issue or ping in squad channel*

---

## Phase 2+ Implementation Decisions

### Decision: Bug 3 (run.sh stale binary) is untestable in XCTest
**Author:** Livingston (Tester)  
**Date:** 2026-04-25  
**Status:** Decided

**Decision**

Bug 3 (stale binary cache in `scripts/run.sh::assemble_app_bundle()`) cannot be
covered by an XCTest unit test. The regression comment is documented inline in
`RegressionTests.swift` with a manual verification procedure.

**Rationale**

The bug lives entirely in a Bash shell function that copies a compiled `.app`
binary into a bundle directory. There is no Swift API surface to mock or assert
against. An XCTest cannot:

- Invoke `assemble_app_bundle()` in isolation
- Observe the file system state of the `.app` bundle during a `run.sh` invocation
- Verify that the copy step refreshes the binary after a rebuild

**Manual Verification Procedure**

1. Build and launch via `./scripts/run.sh`
2. Make a visible source change (e.g., add a print or UI change)
3. Run `./scripts/run.sh` again without cleaning
4. Confirm the running app reflects the source change — if the old binary is still
   in the `.app` bundle the change won't appear (regression)

**Impact on Test Coverage**

This is an acknowledged gap. The shell-level fix (force-refreshing the binary in
`assemble_app_bundle()`) should be reviewed in code review, not via an automated
test. No action required from other agents.


---

**Author:** Rusty (iOS Architect)  
**Date:** 2026-04-26  
**Status:** Proposed — Pending Team Review  
**Requested by:** Yashasg

---

## Context

The product requires pausing eye/posture reminders when:
1. A Focus mode (including Game Mode) is active on the device.
2. The user is in a context where reminders are dangerous or disruptive (e.g., driving, CarPlay navigation).

This document defines what iOS allows, what it doesn't, and the exact architecture to implement it.

---

## Part 1 — Focus Mode Detection

### What iOS Gives Us

**`INFocusStatusCenter`** (Intents framework, iOS 15+):

```swift
import Intents

let center = INFocusStatusCenter.default
// One-time auth request:
center.requestAuthorization { status in ... }
// Current state:
let isFocused: Bool = center.focusStatus.isFocused ?? false
// Observer (push-based, zero battery cost):
center.observeChanges { updatedCenter in
    let isPaused = updatedCenter.focusStatus.isFocused ?? false
}
```

**What `isFocused` tells us:**
- `true` — some Focus mode is active (DND, Personal, Work, Gaming, Sleep, Driving, or any custom Focus).
- `false` — no Focus is active.
- `nil` — authorization not granted; we must treat this as unknown (do not assume paused).

**What it does NOT tell us:**
- Which specific Focus mode is active. "Game Mode" in the Shortcuts/Focus sense is just the "Gaming" Focus profile — there is no API to distinguish it from "Work" or "Personal". We only get a boolean.

**Authorization:**
- Requires `NSFocusStatusUsageDescription` in Info.plist.
- The system shows one-time prompt: "Allow [App] to check if Focus is enabled?"
- The user can grant or revoke in Settings → Privacy → Focus.
- If denied: `focusStatus.isFocused` returns `nil`. We must not pause in this case — failing safe means continuing to remind (the alternative of always-pausing when unknown is worse UX).

**iOS 16+ Focus Filters (App Intents Extension):**
- An app can declare an `AppFocusFilterIntent` in an App Extension (separate bundle target).
- When the user includes our app's filter in a Focus configuration, iOS calls our extension handler with the configured parameters.
- This lets a user say: "When Gaming Focus is active, pause EyePostureReminder reminders."
- **This is the only mechanism for Focus-mode-specific behavior** — and it requires explicit user setup.
- Verdict: Implement as a Phase 3 enhancement. For Phase 2, the `isFocused` boolean is the correct foundation.

---

## Part 2 — Critical App Detection (Maps, Games, etc.)

### Hard Truth: We Cannot Detect Another App's Foreground State

iOS sandboxes every app completely. There is **no public API** to:
- List running foreground apps.
- Check if Maps, a game, or any third-party app is active.
- Access process information for other apps.

Any approach using `LSApplicationWorkspace`, task enumeration, or SpringBoard queries is a **private API**. App Review will reject. Do not suggest these.

### What We CAN Detect (As Proxies)

#### Signal 1 — CarPlay Connected

`AVAudioSession.currentRoute` lists connected audio ports. When CarPlay is active, the route includes a port with type `.carPlay` (`AVAudioSessionPortCarPlay`). No special entitlement required to read the current route — just read it.

```swift
import AVFoundation

// Check current state:
let isCarPlayActive = AVAudioSession.sharedInstance().currentRoute.outputs
    .contains { $0.portType == .carPlay }

// Observe changes (push-based):
NotificationCenter.default.addObserver(
    forName: AVAudioSession.routeChangeNotification,
    object: nil, queue: .main
) { _ in
    // re-check isCarPlayActive
}
```

**Why this matters for Maps:** When Maps is being used for navigation, it almost always routes audio through CarPlay. The CarPlay connection is a strong proxy for "user is in a navigation session." Not perfect (CarPlay can be connected while the user is parked), but it's the best public signal available and it's opt-in via the Settings UI.

#### Signal 2 — Driving Activity Detected

`CMMotionActivityManager` uses the device's dedicated motion coprocessor (M-series chip). It detects `automotive` activity at essentially zero CPU/battery cost — the coprocessor runs independently of the main CPU.

```swift
import CoreMotion

let motionManager = CMMotionActivityManager()
motionManager.startActivityUpdates(to: .main) { activity in
    guard let activity else { return }
    let isDriving = activity.automotive && activity.confidence != .low
}
```

**Requires:** `NSMotionUsageDescription` in Info.plist.

**Why this is the right signal for Maps:** Maps-for-navigation almost always coincides with driving. This signal is cleaner than CarPlay detection because it works even without in-car audio.

**Important:** Combine CarPlay + driving. Either alone can have false positives. CarPlay without driving = parked. Driving without CarPlay = Maps on phone mount = we probably SHOULD pause (user is driving).

#### Signal 3 — What We're NOT Doing

- **`CBCentralManager`** — Bluetooth peripheral scan. Tells us nothing about foreground apps. Rejected.
- **Screen activity heuristics** — e.g., detecting Maps' blue location pulsing or specific color patterns. Impossible in sandboxed environment. Rejected.
- **Screen Time API (`FamilyControls`/`ManagedSettings`)** — App Store apps cannot use these to monitor other apps' usage in real-time. Rejected.
- **Usage of `LSApplicationWorkspace.runningApplications`** — private API. Rejected.

---

## Part 3 — Architecture Proposal

### New Component: `PauseConditionManager`

A standalone service that aggregates pause signals from all sources and emits a single `isPaused: Bool` to `AppCoordinator`.

#### Protocols (for testability)

```swift
// Each detector is protocol-backed so tests inject mocks.

protocol FocusStatusDetecting: AnyObject {
    var isFocused: Bool { get }
    var onFocusChanged: ((Bool) -> Void)? { get set }
    func startMonitoring()
    func stopMonitoring()
}

protocol CarPlayDetecting: AnyObject {
    var isCarPlayActive: Bool { get }
    var onCarPlayChanged: ((Bool) -> Void)? { get set }
    func startMonitoring()
    func stopMonitoring()
}

protocol DrivingActivityDetecting: AnyObject {
    var isDriving: Bool { get }
    var onDrivingChanged: ((Bool) -> Void)? { get set }
    func startMonitoring()
    func stopMonitoring()
}

protocol PauseConditionProviding: AnyObject {
    var isPaused: Bool { get }
    var onPauseStateChanged: ((Bool) -> Void)? { get set }
    func startMonitoring()
    func stopMonitoring()
}
```

#### `PauseConditionManager` (concrete)

```swift
final class PauseConditionManager: PauseConditionProviding {

    var onPauseStateChanged: ((Bool) -> Void)?

    private(set) var isPaused: Bool = false {
        didSet {
            guard isPaused != oldValue else { return }
            onPauseStateChanged?(isPaused)
        }
    }

    private let focusDetector: FocusStatusDetecting
    private let carPlayDetector: CarPlayDetecting
    private let drivingDetector: DrivingActivityDetecting

    // Each condition that is active is tracked as an entry in this set.
    // isPaused = !activeConditions.isEmpty
    private var activeConditions: Set<PauseConditionSource> = []

    init(
        focusDetector: FocusStatusDetecting = LiveFocusStatusDetector(),
        carPlayDetector: CarPlayDetecting = LiveCarPlayDetector(),
        drivingDetector: DrivingActivityDetecting = LiveDrivingActivityDetector()
    ) { ... }

    func startMonitoring() {
        focusDetector.onFocusChanged = { [weak self] focused in
            self?.update(.focusMode, isActive: focused)
        }
        carPlayDetector.onCarPlayChanged = { [weak self] active in
            self?.update(.carPlay, isActive: active)
        }
        drivingDetector.onDrivingChanged = { [weak self] driving in
            self?.update(.driving, isActive: driving)
        }
        focusDetector.startMonitoring()
        carPlayDetector.startMonitoring()
        drivingDetector.startMonitoring()
    }

    private func update(_ source: PauseConditionSource, isActive: Bool) {
        if isActive { activeConditions.insert(source) }
        else { activeConditions.remove(source) }
        isPaused = !activeConditions.isEmpty
    }
}

enum PauseConditionSource: Hashable {
    case focusMode
    case carPlay
    case driving
}
```

### Integration with `AppCoordinator`

`AppCoordinator` owns `PauseConditionManager` alongside `ScreenTimeTracker`. The coordinator subscribes once on init:

```swift
// In AppCoordinator.init():
pauseConditionManager.onPauseStateChanged = { [weak self] isPaused in
    guard let self else { return }
    if isPaused {
        self.screenTimeTracker.pauseAll()
        Logger.scheduling.info("PauseConditionManager: pausing reminders (active condition)")
    } else {
        // Only resume if no snooze is active.
        guard self.settings.snoozedUntil == nil || self.settings.snoozedUntil! <= Date() else { return }
        self.screenTimeTracker.resumeAll()
        Logger.scheduling.info("PauseConditionManager: resuming reminders (no active conditions)")
    }
}
pauseConditionManager.startMonitoring()
```

**Critical invariant:** `PauseConditionManager` and snooze are independent pause axes. `AppCoordinator` must check both before calling `resumeAll()`. The rule: **only resume tracking if BOTH snooze is clear AND no pause conditions are active.**

### Settings Integration

Two new keys in `SettingsStore`:

```swift
// epr.pauseDuringFocus     Bool  — default true (opt-in to Focus pause)
// epr.pauseWhileDriving    Bool  — default true (opt-in to driving pause)
```

`PauseConditionManager` reads these at callback time before calling `update()`. If the user has disabled a condition, ignore its signal even if it fires. This means users who drive with their phone mounted but don't want pausing can turn it off.

### Module Dependency Graph (updated)

```
AppCoordinator
├── ScreenTimeTracker     (owns: lifecycle + timer + thresholds)
├── PauseConditionManager (owns: Focus/CarPlay/Driving detectors)
│   ├── LiveFocusStatusDetector   (INFocusStatusCenter)
│   ├── LiveCarPlayDetector       (AVAudioSession route)
│   └── LiveDrivingActivityDetector (CMMotionActivityManager)
├── SettingsStore
├── ReminderScheduler
└── OverlayManager
```

---

## Part 4 — Battery Impact

| Component | Mechanism | Battery Cost |
|---|---|---|
| `LiveFocusStatusDetector` | `INFocusStatusCenter.observeChanges` | Essentially zero — push-based |
| `LiveCarPlayDetector` | `AVAudioSession.routeChangeNotification` | Essentially zero — push-based |
| `LiveDrivingActivityDetector` | `CMMotionActivityManager` activity updates | Negligible — dedicated M-chip coprocessor |

**No polling.** All three detectors are event-driven. The driving detector uses the motion coprocessor, which runs independently of the main application CPU. Battery impact of this entire feature: **immeasurable in real-world use**.

---

## Part 5 — Permissions Required

| Feature | Permission | Key in Info.plist |
|---|---|---|
| Focus detection | User prompt (one-time) | `NSFocusStatusUsageDescription` |
| Driving detection | User prompt (one-time) | `NSMotionUsageDescription` |
| CarPlay detection | None required | — |

**Recommended usage description strings:**
- Focus: `"EyePostureReminder checks if Focus mode is active to automatically pause reminders during Focus sessions."`
- Motion: `"EyePostureReminder uses motion data to detect when you're driving so reminders are paused automatically."`

---

## Part 6 — App Store Review Risk

- `INFocusStatusCenter`: Approved API. No review risk.
- `AVAudioSession.currentRoute`: Approved API. No review risk.
- `CMMotionActivityManager`: Approved API. Privacy string required. No review risk.
- No private APIs. No screen-scraping. No inter-app communication. **Review risk: zero.**

---

## Part 7 — What's Deferred

| Feature | Why Deferred |
|---|---|
| App Focus Filters (specific Game Mode config) | Phase 3 — requires App Extension target + user setup |
| Detecting specific "Maps" or game by name | Impossible with public APIs. Full stop. |

---

## Decision

**Adopt `PauseConditionManager` as described.** Phase 2 scope.

The three detectors (Focus, CarPlay, Driving) are the exhaustive set of what iOS legitimately exposes. Anything beyond this requires private APIs that will cause App Store rejection.

The architecture is fully protocol-backed, testable via mock injections, and adds no meaningful battery overhead. Integration with `AppCoordinator` requires ~20 lines of wiring code.
# Decision: Legal Documents Added to Repository

**Author:** Frank (Legal Advisor)  
**Date:** 2026-04-24  
**Status:** Complete  

## Decision

Three legal documents have been created under `docs/legal/`:

1. `docs/legal/TERMS.md` — Terms & Conditions
2. `docs/legal/PRIVACY.md` — Privacy Policy
3. `docs/legal/DISCLAIMER.md` — Disclaimer (in-app, App Store, one-liner variants)

## Rationale

The app requires legal protection before App Store submission. Health/wellness apps are under heightened scrutiny — Apple's App Store Review Guidelines (Section 5) and legal best practices require clear disclaimers that the app is not medical advice.

## Key Legal Positions Taken

- **"Not medical advice"** — explicit, prominent, non-negotiable
- **"Use at your own risk"** — covers both health outcomes and technical failures
- **"As is" warranty** — covers timer accuracy and notification reliability (iOS system-dependent)
- **Privacy by design** — Privacy Policy confirms compliance with GDPR/CCPA by architecture (no personal data collected at all)
- **COPPA** — addressed proactively even with no data collection
- **iCloud backup carve-out** — UserDefaults may be included in device backup; disclosed in Privacy Policy

## Placeholders to Fill

The following must be completed before App Store submission:
- `[Your Company Name]`
- `[Contact Email]`
- `[Jurisdiction]`
- `[Date]`

## Team Implications

- If analytics or telemetry are added in a future phase, the Privacy Policy **must** be updated before shipping
- If IAP or subscriptions are added, Terms must be expanded with billing/refund sections
- The in-app disclaimer text in `DISCLAIMER.md` should be surfaced to Linus (UI) for implementation on first launch or Settings screen

---

## Wave 2 Testing Decisions

### Decision: XCUITest Requires .xcodeproj
**Filed by:** Livingston (Tester)  
**Date:** 2026-04-25  
**Status:** Pending Implementation  
**Related issue:** #9 — Add XCUITest suite

**Problem**

XCUITest UI test bundles require a dedicated UITest target type. Swift Package Manager's `Package.swift` only supports `.testTarget` (unit tests via XCTest) — there is no `.uiTestTarget` equivalent in SPM.

The UI test files have been written and placed in `Tests/EyePostureReminderUITests/`. They are complete, follow XCUIApplication patterns, and include `launchArguments` for test state control. However, they **cannot be compiled or run** without an Xcode project.

**Options Considered**

1. **Add an `.xcodeproj`** — Generate or manually create an Xcode project alongside Package.swift. Add a UITest target that references `Tests/EyePostureReminderUITests/*.swift`. This is the standard path for shipping iOS apps anyway (App Store submission requires Xcode).

2. **Xcode Cloud / xcodebuild** — Same prerequisite: needs an `.xcodeproj` or `.xcworkspace`.

3. **Defer** — Keep the test files staged. When the team adds an Xcode project for distribution, wire the UITest target at that point.

**Recommendation**

Add an `.xcodeproj`. The project is already iOS-only and App Store-bound — an Xcode project is needed for signing, entitlements, and distribution. This is the right time to add it. **Assigned to:** Basher (iOS Dev).

**Work Required**

1. Generate/create `.xcodeproj` from SPM Package.swift manifest
2. Add UITest target in Xcode project settings
3. Reference `Tests/EyePostureReminderUITests/*.swift` in target
4. Add `launchArguments` handling in `EyePostureReminderApp.swift` (see `Tests/EyePostureReminderUITests/README.md`)
5. Add `accessibilityIdentifier` modifiers to source views (full list in README)
6. Run `xcodebuild test -scheme EyePostureReminder -destination 'platform=iOS Simulator,name=iPhone 15 Pro'`

**Blocking:** Yes — Phase 2 full test coverage depends on this.


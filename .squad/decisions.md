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

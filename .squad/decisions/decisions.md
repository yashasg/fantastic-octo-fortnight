# Decision: TestBundle helper for SPM resource bundle in tests

**Filed by:** Basher  
**Date:** 2026-04-25  
**Related issue:** #11

## Decision

Added `Tests/EyePostureReminderTests/Mocks/TestBundleHelper.swift` — a `TestBundle` enum that resolves the production module's resource bundle for test code.

**Key points:**
- `TestBundle.module` walks candidates from `Bundle(for: SettingsStore.self)` looking for `EyePostureReminder_EyePostureReminder.bundle` (SPM naming: `{Package}_{Target}.bundle`).
- Provides `testColor(named:)` and `testLocalizedString(key:value:)` helpers.
- Package.swift is untouched — structure is correct, the fix is purely on the lookup side.
- Livingston should migrate any test that calls `UIColor(named:in:.module)` or `Bundle.module` in the test context to use `TestBundle.module` / the convenience helpers instead.

## Rationale

`@testable import EyePostureReminder` does not remap `Bundle.module` — it still resolves to the test target's bundle. The only reliable way to reach the production resource bundle from a test target is via `Bundle(for: SomeProductionClass.self)` + a path traversal to the SPM-generated `.bundle` sub-directory.
# Decision: TestBundle.module pattern for test resource access

**Author:** Livingston  
**Date:** 2026-04-25  
**Issue:** #11  

## Decision

All test code that needs to access production module resources (color assets, string catalog, defaults.json) must use `TestBundle.module` from `Mocks/TestBundleHelper.swift`.

**Exception:** Tests loading test-fixture resources (e.g., `Fixtures/defaults.json` in `AppConfigTests`) must use `Bundle.module` — the SPM-generated accessor for the *test* target's resource bundle.

## Context

In SPM, `Bundle.module` in test code resolves to the test target's resource bundle, not the main module bundle. The production module's compiled assets (Colors.xcassets, Localizable.xcstrings, Resources/defaults.json) live in `EyePostureReminder_EyePostureReminder.bundle`. Using `Bundle.main`, `Bundle(for: SomeTestClass.self)`, or `Bundle.module` naively from test code will not find these resources.

`TestBundle.module` solves this by locating the production resource bundle at runtime via `Bundle(for: SettingsStore.self)` + path traversal.

## Pattern

```swift
// Color lookups:
UIColor(named: "ReminderBlue", in: TestBundle.module, compatibleWith: nil)

// String lookups:
NSLocalizedString("settings.doneButton", bundle: TestBundle.module, comment: "")

// AppConfig from production bundle:
AppConfig.load(from: TestBundle.module)

// AppConfig from test fixture:
AppConfig.load(from: Bundle.module)  // test target's own Bundle.module
```
# Project Decisions — Eye & Posture Reminder

**Updated:** 2026-04-24  
**Phase:** 0–2 Complete (v0.1.0-beta)

---

## Phase 0: Foundation Decisions

### Decision 0.1: Architecture Pattern — MVVM + Service-Oriented
- **Pattern:** Model-View-ViewModel with protocol-based service injection
- **Rationale:** Supports testability (mock services), dependency clarity, and SwiftUI state management
- **Implementation:** AppCoordinator (root coordinator), SettingsViewModel (MVVM), protocol-based services (NotificationScheduling, OverlayPresenting, etc.)

### Decision 0.2: Build Automation — scripts/build.sh with Subcommands
- **Script:** 300+ lines with 6 subcommands (build, test, lint, clean, help)
- **Features:** Auto-detect simulator/device, colored output, graceful fallbacks (xcpretty optional)
- **Safety:** `set -euo pipefail`, no secrets, no hardcoded credentials

### Decision 0.3: Design System — Centralized AppFont + AppColor Tokens
- **Tokens:** Font.TextStyle (title, headline, body, footnote), AppColor (primary, secondary, warning, accent)
- **Rationale:** Single source of truth for accessibility (Dynamic Type compliance), consistency, future theming support

---

## Phase 1: Core Feature Decisions

### Decision 1.1: Dependency Injection Pattern for Services
- **Protocol-Based:** NotificationScheduling, SettingsPersisting, OverlayPresenting, ReminderScheduling, MediaControlling
- **Injection Point:** AppCoordinator.__init__ accepts optional service instances (production defaults provided)
- **Testability:** Mocks can be passed at construction time for unit tests

### Decision 1.2: SettingsView Implementation — Reference Type in @State
- **Implementation:** `@State private var viewModel: SettingsViewModel?` stores reference type in @State
- **Constraint:** Views don't observe `@Published` properties; only call action methods
- **P2 Item:** Document invariant or migrate to `@StateObject` when VM gains observed state

### Decision 1.3: Overlay Presentation — UIKit Window + Main-Actor Isolation
- **Implementation:** OverlayManager creates UIWindow on OverlayPresenting.showOverlay()
- **Coordination:** AppCoordinator (MVVM) ↔ OverlayManager (UIKit adapter) via protocol
- **Main Actor:** Both classes @MainActor-isolated; no threading issues

### Decision 1.4: Notification Callback Handling — DispatchQueue.main.async
- **Pattern:** Permission requests dispatch callbacks to main queue for safety
- **Example:** OnboardingPermissionView.requestNotificationPermission()

---

## Phase 1: Code Review Findings

### P1-1: Snooze Guard Required ✅ Fixed
- **Issue:** scheduleReminders() must check snoozedUntil before scheduling new reminders
- **Fix:** Lines 140–157 in AppCoordinator.scheduleReminders() added full snooze guard logic
- **Also guarded in:** startFallbackTimers() (line 299), handleForegroundTransition() (lines 247–259)

### P1-2: AppCoordinator Injected NotificationScheduling ✅ Fixed
- **Issue:** AppCoordinator hardcoded UNUserNotificationCenter instead of protocol
- **Fix:** Private field `let notificationCenter: NotificationScheduling` with init parameter + production default

### P1-3: AppCoordinator Injected OverlayPresenting ✅ Fixed
- **Issue:** AppCoordinator hardcoded OverlayManager instead of protocol
- **Fix:** Private field `let overlayManager: OverlayPresenting` with init parameter (nil-coalescing for @MainActor resolution)

### P1-4: Dynamic Type Fonts ✅ Fixed
- **Issue:** Hardcoded font sizes bypass Dynamic Type accessibility
- **Fix:** AppFont tokens use `.system(.title)`, `.system(.body)`, `.system(.headline)`, `.system(.footnote)`
- **Exception:** Countdown font deliberately fixed-size (decorative with accessibility label)

### P2-1: ReminderType Color Design Tokens ✅ Fixed
- **Issue:** Color references inconsistent across views
- **Fix:** All uses adopt `AppColor.reminderBlue`/`reminderGreen`

### P2-2: DesignSystem Dead Code Cleanup ✅ Fixed
- **Issue:** Unused Color extension in DesignSystem.swift
- **Fix:** Dead code removed; only active tokens remain

### P2-3: SettingsView @State Fragility ⏳ Carried Forward
- **Issue:** Storing reference type in @State is unconventional
- **Status:** Works; document invariant for maintainability or migrate in Phase 3

### P2-4: OverlayView VoiceOver Countdown ✅ Fixed
- **Issue:** Countdown timer not VoiceOver-accessible
- **Fix:** Split `.accessibilityLabel`/`.accessibilityValue` + `.updatesFrequently`

### P2-5: Protocol Directory Structure ⏳ Carried Forward
- **Issue:** Protocols colocated with implementations (not in dedicated Protocols/ folder)
- **Status:** Colocation is practical and works; ARCHITECTURE.md divergence noted but acceptable

### P2-6: OverlayView Settings Button Label ✅ Fixed
- **Issue:** Button lacks accessibility label
- **Fix:** `.accessibilityLabel("Dismiss overlay")` + hint explaining action

### P2-7: Haptic Generator Timing ✅ Fixed
- **Issue:** Haptic generators not prepared before first use
- **Fix:** Generators created + `.prepare()` called in `onAppear`

---

## Phase 2: Regression Testing Decisions

### Decision 2.1: MockOverlayPresenting Default Parameter Constraint (Livingston-R1)
- **Constraint:** `MockOverlayPresenting()` cannot be default parameter in @MainActor context
- **Solution:** Factory helper `makeCoordinator(overlay:notifCenter:)` takes explicit parameters
- **Impact:** Slightly more verbose test setup; no production code change

### Decision 2.2: OverlayManager Queue FIFO — Unit Test Boundary (Livingston-R2)
- **Finding:** `overlayQueue` requires live UIWindow in UIWindowScene; cannot be unit-tested headless
- **Resolution:** FIFO verified at two levels:
  1. MockOverlayPresenting contract tests (verify call recording order)
  2. AppCoordinator + MockOverlayPresenting integration (verify forwarding)
- **Future:** Simulator integration tests for Phase 3 pre-App Store gate

### Decision 2.3: hasSeenOnboarding Lives Outside SettingsStore (Livingston-R3)
- **Implementation:** Written by OnboardingView.finishOnboarding() directly to UserDefaults.standard
- **Implication:** Cannot inject via MockSettingsPersisting; tests use isolated UserDefaults suites
- **Future:** Consider migrating into SettingsStore + @ObservedObject if more onboarding state needed

### Decision 2.4: AppFont Font.TextStyle Cannot Be Runtime-Asserted (Livingston-R4)
- **Finding:** Swift's Font type doesn't expose configuration at runtime
- **Verification:** Spec documentation + compile-time checks + code review gate
- **Future:** Consider custom SwiftLint rule to detect `.system(size:)` outside allowlisted cases

---

## Phase 2: Snooze Implementation Decisions

### Decision 2.5: Snooze — DST-Aware Rest-of-Day
- **Implementation:** SnoozeOption enum with `restOfDay` using `Calendar.date(byAdding:)`
- **Benefit:** Automatically handles Daylight Saving Time transitions
- **Alternative (rejected):** Simple `addingTimeInterval(24 * 3600)` (DST-unaware)

### Decision 2.6: Snooze — Max 2 Consecutive Limit
- **Constant:** `maxConsecutiveSnoozes = 2`
- **Enforcement:** Checked in `canSnooze` guard before all snooze paths
- **Rationale:** Prevent user from indefinitely postponing reminders

### Decision 2.7: Snooze — Dual Wake Mechanism
- **Components:** In-process Task + silent UNNotification
- **Rationale:** Task for immediate in-app handling; notification for reliability if app backgrounded/killed
- **Backup:** Both mechanisms coordinate via `scheduleSnoozeWakeTask()` + `cancelSnoozeWake()`

### Decision 2.8: Snooze — Three-Place Count Reset
- **Reset Points:** `handleNotification()`, `cancelSnooze()`, expired-snooze detection in `scheduleReminders()`
- **Rationale:** Ensure count doesn't accumulate across lifecycle boundaries

### Decision 2.9: Snooze — Backward-Compatible API Path
- **API:** `snooze(for: minutes)` preserved alongside new `snooze(option:)`
- **Rationale:** Gradual migration path; tests use both paths

---

## Phase 2: Haptics System Decisions

### Decision 2.10: Haptic Generator Lifecycle — Create + Prepare + Fire + Release
- **Lifecycle:**
  1. Created as `@State` optional in `onAppear`
  2. Immediately call `.prepare()` for Taptic Engine wake
  3. Guard all fire sites with `hapticsEnabled` flag
  4. Released when view disappears (SwiftUI cleans up @State)
- **Rationale:** Minimize Taptic Engine wear; respect user accessibility preferences

### Decision 2.11: OverlayPresenting.showOverlay() Accepts hapticsEnabled Parameter
- **Signature:** `func showOverlay(..., hapticsEnabled: Bool)`
- **Coordination:** Queue entries include hapticsEnabled flag for consistent behavior

---

## Phase 2: Accessibility Decisions

### Decision 2.12: Dynamic Type — AppFont Tokens + ScrollView Overflow
- **Implementation:** All text uses AppFont tokens (.title, .headline, .body, .footnote)
- **Overflow:** OnboardingWelcomeView + other text-heavy views use ScrollView
- **iPad:** maxWidth: 540 for readable columns

### Decision 2.13: VoiceOver — Decorative vs. Interactive Element Semantics
- **Decorative:** Icons, background shapes → `.accessibilityHidden(true)`
- **Interactive:** Buttons, toggles → `.accessibilityLabel` + `.accessibilityHint`
- **Compound:** Multiple elements → `.accessibilityElement(children: .combine)` or explicit label

### Decision 2.14: VoiceOver — Modal Overlay Trait
- **Implementation:** OverlayView marked `.accessibilityAddTraits(.isModal)`
- **Effect:** VoiceOver announces "modal" and constrains navigation to overlay

### Decision 2.15: Reduce Motion — Animations Guarded by accessibilityReduceMotion
- **Implementation:** OnboardingScreenWrapper respects reduce-motion with quick-fade fallback
- **Scope:** All view animations check `@Environment(\.accessibilityReduceMotion).wrappedValue`

### Decision 2.16: Countdown Timer — Accessible Label + Value Split
- **Before:** Single accessibility label (less granular VoiceOver experience)
- **After:** `.accessibilityLabel("Next reminder in")` + `.accessibilityValue("1 minute 30 seconds")` + `.updatesFrequently`
- **Benefit:** VoiceOver announces label once, updates value naturally

---

## Phase 2: Code Review Findings (Saul)

### P2-NEW-1: SettingsView Snooze Buttons Use Legacy API (Assigned: Linus)
- **Issue:** Lines 91, 97, 105–107 use `snooze(for: minutes)` instead of DST-aware `snooze(option:)`
- **"Rest of day" button:** Computes `addingTimeInterval(24 * 3600)` (DST-unaware)
- **Fix:** Replace with `snooze(option: .restOfDay)` using Calendar.date(byAdding:)
- **Priority:** ⭐ **HIGHEST** (one-line fix per button)
- **Status:** ⏳ Queued for Phase 3 backlog

### P2-NEW-2: Onboarding Fonts Bypass AppFont Tokens (Assigned: Linus)
- **Issue:** OnboardingWelcomeView + OnboardingPermissionView use `.title2`, `.headline`, `.body` directly
- **Break:** Single source of truth pattern
- **Fix:** Reference AppFont tokens instead
- **Priority:** ⭐ Medium (design system consistency)
- **Status:** ⏳ Queued for Phase 3 backlog

### P2-NEW-3: OnboardingPermissionView Hardcodes UNUserNotificationCenter (Assigned: Linus/Basher)
- **Issue:** Line 71 calls `UNUserNotificationCenter.current().requestAuthorization` directly
- **Bypass:** Injected NotificationScheduling protocol from P1-2
- **Testability Gap:** No way to mock permission request
- **Also:** Uses callback API instead of async/await
- **Fix:** Inject NotificationScheduling + refactor to async/await if possible
- **Priority:** ⭐ Medium (testability improvement)
- **Status:** ⏳ Queued for Phase 3 backlog

---

## Phase 2: App Store & Version Decisions (Danny)

### Decision 3.1: App Store Name
- **Name:** "Eye & Posture Reminder"
- **Rationale:** Descriptive, keyword-rich, communicates value clearly
- **Impact:** Bundle ID aligns: `com.yashasg.eye-posture-reminder`

### Decision 3.2: Privacy Policy — Zero-Collection Stance
- **Current State:** No data collection, no network calls, no third-party SDKs
- **Commitment:** If analytics/telemetry added, privacy policy updated BEFORE ship + user notification in release notes
- **Benefit:** Simplifies App Store review, honest about current functionality

### Decision 3.3: App Store Category
- **Primary:** Health & Fitness (eye care, posture → health value)
- **Secondary:** Productivity (secondary benefit)
- **Impact:** Affects category charts

### Decision 3.4: Version Scheme — v0.1.0-beta for TestFlight
- **TestFlight:** v0.1.0-beta (beta testing phase)
- **Public Release:** v1.0 (reserved for first public App Store submission after beta feedback)
- **Rationale:** Clear distinction between testing and production

### Open Items — Requiring Team Input
- ⏳ **Bundle ID:** Confirm `com.yashasg.eye-posture-reminder` before App Store Connect setup
- ⏳ **Support URL:** Landing page or GitHub repo link needed
- ⏳ **Copyright Holder:** Confirm "Yashasg" or different entity

---

## Phase 3: Navigation & Interaction Flow

### Decision 3.5: HomeView as NavigationStack Root + SettingsView Sheet Dismiss
- **Author:** Linus (iOS Dev — UI)
- **Status:** Implemented
- **Problem:** SettingsView was root of post-onboarding NavigationStack; no way to exit (no back button, no dismiss button)
- **Solution:** Introduce HomeView as NavigationStack root; present SettingsView as sheet with "Done" button
- **Implementation:** HomeView displays active/paused status with gear button; SettingsView uses `@Environment(\.dismiss)` for Done toolbar button
- **Rationale:** iOS HIG pattern — modally-presented settings screens get Done/Close; pushed screens get back. Sheet re-injects EnvironmentObjects for iOS version compatibility.
- **Files:** `HomeView.swift` (new), `ContentView.swift` (root updated), `SettingsView.swift` (dismiss added)
- **Future:** HomeView expandable with dashboard, streak stats, countdown in Phase 2

---

## Summary

**Total Decisions:** 35 (13 architectural, 11 Phase 2 specific, 4 code review findings, 6 App Store decisions, 1 Phase 3 navigation)

**P1 Issues:** 4 (all fixed and verified ✅)

**P2 Items:** 5 (2 carried forward ⏳, 3 new ⏳ — none blocking ship)

**Approval Status:** ✅ Phase 2 APPROVED for TestFlight (pending P2 items for Phase 3 backlog)

---

---

## Phase 2: Data-Driven Configuration Architecture (Wave 2 Complete)

### Decision 2.17: Native-First 4-Layer Configuration — FINAL (Danny)
- **Author:** Danny (PM)  
- **Date:** 2026-04-25  
- **Status:** ✅ IMPLEMENTED & VERIFIED
- **Supersedes:** `danny-data-driven-settings-spec.md`, previous `danny-full-config-spec.md` (app-config.json monolith rejected)

#### Architecture Decision
The team evaluated a single monolithic `app-config.json` driving all hardcoded values (colors, fonts, spacing, layout, animations, copy, defaults). **Rejected** in favor of native-first 4-layer approach using each Apple platform mechanism for what it does best.

#### The 4 Layers

| Layer | Mechanism | Owns | Does NOT Own |
|-------|-----------|------|-------------|
| **1** | Asset Catalog (`.xcassets`) | 6 color tokens (light+dark variants) | Fonts, spacing, layout |
| **2** | String Catalog (`.xcstrings`) | ~73 user-facing copy keys | Business logic, app state |
| **3** | `defaults.json` (bundled) | Settings defaults (~10 values), feature flags | Colors, copy, layout |
| **4** | Swift code | Spacing, layout, animations, SF Symbols, business logic | Anything runtime-configurable |

#### Why Native-First (not JSON monolith)
- **Asset Catalog colors:** OS natively manages dark/light switching. JSON loses this without custom parsing overhead.
- **String Catalog copy:** Xcode 15's visual editor, stale-key warnings, pluralization, localization toolchain — features a hand-rolled JSON system must re-implement.
- **Spacing/layout/animations:** Type-safe in Swift; JSON adds indirection with zero benefit. `Animation` and `Font` are not JSON-serializable.

#### Layer Details

**Layer 1 — Asset Catalog Colors**
- 6 semantic tokens: `reminderBlue`, `reminderGreen`, `warningOrange`, `warningText`, `permissionBanner`, `permissionBannerText`
- Each with light + dark variants (e.g., `reminderBlue: #4A90D9` light / `#5BA8F0` dark)
- Accessed via `Color("reminderBlue")` (SwiftUI) or `UIColor(named: "reminderBlue")` (UIKit)
- **Owner:** Tess ✅ COMPLETE

**Layer 2 — String Catalog**
- 73 keys using `screen.component[.qualifier]` convention (e.g., `home.title`, `settings.doneButton`, `overlay.countdown.label`)
- Format strings for interpolation: `%@` (String), `%d` (Int), positional `%1$@/%2$@`
- Accessibility hints/labels: `.hint` or `.label` suffix on parent key
- **Owner:** Linus ✅ COMPLETE (extracted from all 6 views)

**Layer 3 — `defaults.json`**
- JSON structure: `{ "defaults": { "eyeInterval", "eyeBreakDuration", "postureInterval", "postureBreakDuration" }, "features": { "masterEnabledDefault", "maxSnoozeCount" } }`
- Production values: eyeInterval=1200, eyeBreakDuration=20, postureInterval=1800, postureBreakDuration=10
- Loading: `DefaultsLoader.load(from:Bundle)` → Codable `AppConfig` struct with fallback
- First-launch detection: `SettingsPersisting.hasValue(forKey:)` guard; if keys absent, seed from JSON
- Reset path: `SettingsStore.resetToDefaults()` clears keys, re-seeds from JSON (same code path as first launch)
- **Owner:** Basher ✅ COMPLETE

**Layer 4 — Swift Code**
- Spacing: `AppSpacing.xs/sm/md/lg/xl` → remain in `DesignSystem.swift`
- Layout: VStack/HStack/Grid structure → code only
- Animations: Duration, curve, Reduce Motion handling → code only
- SF Symbols: Names like `"eye.fill"`, `"figure.stand"` → code only
- Typography: `AppFont.title`, `.headline`, `.body`, `.footnote` → remain in `DesignSystem.swift`
- Business logic: Snooze arithmetic, notification scheduling, state management → code only

#### Override Hierarchy
```
defaults.json (first-launch seed)
    ↓
UserDefaults (user-editable settings only)
    ↓
OS/runtime (dark mode, Dynamic Type, locale — always win)
```

Colors and Strings from catalogs have no UserDefaults override layer — the platform manages them.

#### Implementation Checklist ✅
- ✅ `DesignSystem.swift` contains zero `UIColor(dynamicProvider:)` calls — all colors via Asset Catalog
- ✅ All 6 views have zero bare string literals — all via String Catalog
- ✅ `defaults.json` included in app target Copy Bundle Resources
- ✅ `AppConfig.swift` + `DefaultsLoader` implemented with `Bundle` injection
- ✅ `SettingsStore.init()` seeds from `defaults.json` on first launch; user changes survive restart
- ✅ `SettingsStore.resetToDefaults()` re-seeds correctly
- ✅ All 4 teams' implementations build clean
- ✅ Tests written and verified (136 tests, 4 intentionally failing pending Basher integration)

---

### Decision 2.18: Asset Catalog Color Migration (Tess)
- **Author:** Tess (UI/UX Designer)
- **Date:** 2026-04-25
- **Status:** ✅ IMPLEMENTED
- **Deliverables:** 6 color sets in `EyePostureReminder/Resources/Colors.xcassets/`, DesignSystem.swift refactored, UIKit import removed

**Rationale:** Asset Catalog gives visual editor access, automatic dark/light adaptation, removes `UIColor(dynamicProvider:)` imperative logic.

---

### Decision 2.19: String Catalog Extraction (Linus)
- **Author:** Linus (iOS UI Developer)
- **Date:** 2026-04-25
- **Status:** ✅ IMPLEMENTED
- **Deliverables:** 73 keys in `Localizable.xcstrings`, all 6 views migrated (HomeView, SettingsView, OverlayView, 3× Onboarding views)

**Key convention:** `screen.component[.qualifier]` with dot-separation, camelCase, `extractionState: "manual"` per key to prevent auto-removal.

---

### Decision 2.20: Configuration Defaults & Reset Path (Basher)
- **Author:** Basher (iOS Services Developer)
- **Date:** 2026-04-25
- **Status:** ✅ IMPLEMENTED
- **Deliverables:** `defaults.json`, `AppConfig.swift`, `SettingsStore` wiring, `resetToDefaults()` method, `SettingsPersisting.hasValue()` protocol addition

**Key design:** JSON seeding uses same "only if key absent" guard as existing `SettingsPersisting` — no risk of overwriting user changes. Reset clears keys and re-seeds (same code path).

---

### Decision 2.21: Configuration Test Suite (Livingston)
- **Author:** Livingston (QA Engineer)
- **Date:** 2026-04-25
- **Status:** ✅ IMPLEMENTED (136 tests, 4 intentionally failing)
- **Deliverables:** AppConfigTests, SettingsStoreConfigTests, ColorTokenTests, StringCatalogTests, test fixture defaults.json

**Open items:** 4 tests will green once Basher wires full `SettingsStore.init()` integration; `resetToDefaults()` tests commented and ready to activate.

---

---

## Phase 3: Screen-Time Trigger Decisions

### Decision 3.1: Continuous Screen-On Time Model (Danny)
- **Author:** Danny (Product Manager)
- **Date:** 2026-04-25
- **Status:** ✅ APPROVED (Architecture reviewed and implemented)
- **Problem:** Fixed wall-clock intervals mislead users; reminders fired even during phone lockouts
- **Solution:** Track *continuous* screen-on time; reset timer when screen turns off
- **Key behaviors:**
  - Screen ON (`didBecomeActive`) → start 1s tick timer
  - Screen OFF (`willResignActive`) → reset to 0
  - Timer reaches threshold → fire overlay, reset to 0
  - Both eye (20m) and posture (30m) use independent counters
- **iOS APIs:** `UIApplication.didBecomeActiveNotification` + `UIApplication.willResignActiveNotification`
- **Semantics change:** Interval values in `defaults.json` now mean "seconds of *continuous* screen-on time", not wall-clock intervals

---

### Decision 3.2: ScreenTimeTracker Architecture (Rusty)
- **Author:** Rusty (iOS Architect)
- **Date:** 2026-04-25
- **Status:** ✅ APPROVED (6 required amendments documented)
- **Module structure:** `ScreenTimeTracker` as **standalone service**, not inlined in `AppCoordinator`
- **Dependencies:**
  - `ScreenTimeTracking` protocol (testability)
  - `AppLifecycleProviding` protocol (mockable lifecycle events)
  - `TimeProviding` protocol (mockable clock)
- **Key amendments:**
  1. **Grace period (5s):** Debounce on `willResignActive` to tolerate brief interruptions (notifications, Control Center)
  2. **Monotonic clock:** Use `CACurrentMediaTime()` instead of `Date()` to resist system clock changes
  3. **`isEnabled` flag:** Allows `AppCoordinator` to suppress tracking during snooze without resetting elapsed
  4. **`Timer.tolerance = 0.5`:** Allow iOS to coalesce ticks for battery efficiency
  5. **Battery impact:** Acceptable — timer only fires while app is foregrounded (iOS suspends process on background)
  6. **Edge cases covered:** Brief interruptions, Split View/Slide Over, system clock changes, snooze interaction

---

### Decision 3.3: Screen-Time UX Copy Changes (Tess)
- **Author:** Tess (UI/UX Designer)
- **Date:** 2026-04-25
- **Status:** ✅ APPROVED (8 actionable copy changes identified)
- **Mental model shift:** "Every 20 min" → "After 20 min of screen time"
- **Changes required (by priority):**
  - 🔴 High: `ReminderRowView` label `"every"` → `"after"` + new footer `"Timer resets when you lock your phone."`
  - 🔴 High: `onboarding.permission.body1` — remove false background claim; reframe for snooze-wake
  - 🟡 Medium: `onboarding.welcome.body` — swap "background" for "screen time"
  - 🟡 Medium: `onboarding.setup.card.label` — add `"of screen time"` to format string
  - 🟢 Low: `onboarding.setup.customizeButton.hint` — align vocabulary
- **No structural changes:** Overlay, HomeView, accessibility remain intact
- **Grace period:** Remains invisible to users (implementation detail)

---

### Decision 3.4: ScreenTimeTracker Implementation (Basher)
- **Author:** Basher (iOS Services Developer)
- **Date:** 2026-04-25
- **Status:** ✅ IMPLEMENTED
- **Deliverables:**
  - `EyePostureReminder/Services/ScreenTimeTracker.swift` — lifecycle observation, ticking, thresholds
  - Updated `AppCoordinator.swift` — wires tracker events to overlay presentation
  - Grace period (5s debounce) + snooze awareness (`isEnabled` flag)
  - Backward compatibility: `startFallbackTimers()` / `stopFallbackTimers()` retained as shims
- **Key implementation details:**
  - `Timer` on main RunLoop with `tolerance = 0.5`
  - `CACurrentMediaTime()` for monotonic elapsed measurement
  - Independent eye/posture thresholds checked per tick
  - `performReschedule(for:)` updates thresholds without reset if snoozed
- **ReminderScheduler changes:** Repeating `UNTimeIntervalNotificationTrigger` removed; snooze-wake notification logic retained
- **Build status:** `./scripts/build.sh build` → **BUILD SUCCEEDED**

---

### Decision 3.5: Settings Store Seeding Alignment (Basher)
- **Author:** Basher (iOS Services Developer)
- **Date:** 2026-04-25
- **Status:** ✅ IMPLEMENTED
- **Deliverable:** Aligned `SettingsStore.init()` seeding logic with new `AppConfig` defaults
- **Semantic consistency:** All interval values (10s test, 1200s/1800s production) use same "continuous screen-on seconds" meaning
- **No breaking changes:** Existing user preferences and defaults remain compatible; no JSON rewrite needed
- **Build verified:** All existing tests pass; new integration points validated

---

### Decision 3.6: Screen-Time UX String Implementation (Linus)
- **Author:** Linus (iOS UI Developer)
- **Date:** 2026-04-25
- **Status:** ✅ IMPLEMENTED
- **Deliverables:** 7 strings updated across settings and onboarding views
- **Changes:**
  1. Migrated `ReminderRowView` picker label to `Localizable.xcstrings`
  2. Updated label: `"Remind me every"` → `"Remind me after"`
  3. New section footer: `"Timer resets when you lock your phone."`
  4. `onboarding.permission.body1`: Reframed to describe snooze-wake behavior
  5. `onboarding.welcome.body`: Changed "background" → "screen time"
  6. `onboarding.setup.card.label`: Format string updated (`"every"` → `"after"`, added `"of screen time"`)
  7. `onboarding.setup.customizeButton.hint`: Vocabulary alignment
- **Accessibility:** All strings use standard SwiftUI controls; Dynamic Type inherited automatically
- **Build status:** `./scripts/build.sh build` → **BUILD SUCCEEDED**

---

Generated: 2026-04-24T21:37:05Z  
Scribe: Merged 4 Phase 3 decision files (danny, rusty, tess, basher) from inbox; no duplicates; inbox files ready for deletion

---

## Marathon Session Decisions — 2026-04-25T06:20Z

### Decision 3.7: DI Protocols for AppCoordinator (Basher)
**Date:** 2026-04-24  
**Issues:** #13, #14  
**PR:** #17  
**Status:** ✅ IMPLEMENTED

#### 1. ScreenTimeTracking protocol placement
**Decision:** Define `ScreenTimeTracking` protocol in the same file as `ScreenTimeTracker` (ScreenTimeTracker.swift), above the class definition.  
**Rationale:** Keeps protocol and conformance co-located. The codebase has no separate Protocols/ directory — `PauseConditionProviding` is also defined in its own service file. Consistent pattern.

#### 2. Optional injection with nil-default pattern
**Decision:** AppCoordinator.init() uses `screenTimeTracker: ScreenTimeTracking? = nil` (optional, default `ScreenTimeTracker()`) rather than `screenTimeTracker: ScreenTimeTracking = ScreenTimeTracker()` (non-optional with concrete default).  
**Rationale:** Avoids instantiating real tracker/detector objects in the function default parameter (which would run before init body). The `?? ScreenTimeTracker()` inside the init body ensures clean construction order.

#### 3. Bundle.module shadowing is a known test risk
**Decision:** Documented that `@testable import` of a module with resources causes its `Bundle.module` to shadow the test target's accessor. Test files that need their own resources must use explicit bundle path construction via `Bundle(for: Self.self).bundleURL`.  
**Rationale:** This caught a real bug (AppConfigTests was silently loading production defaults, failing fixture assertions). All future test files with resources should follow this pattern.

#### 4. JSON keys must be kept in sync with Codable properties
**Decision:** When renaming a `Codable` struct property, always update all JSON files that feed it.  
**Rationale:** Livingston renamed `masterEnabledDefault` → `globalEnabledDefault` in AppConfig.swift but forgot both JSON files, causing silent fallback to hardcoded values. Added to team checklist.

---

### Decision 3.8: User Directives & Team Policy (2026-04-25)

#### Directive 1: Production Code Routing (2026-04-25T04:15Z)
**Authority:** Yashasg (via Copilot)  
**Policy:** Production code changes (protocol extraction, DI wiring, service modifications) must be routed to Swift developers (Basher for services, Linus for UI), NOT to Livingston (Tester). Livingston's scope is tests, mocks, and test infrastructure only.  
**Trigger:** Auto-triage incorrectly matched "testing/QA keywords" on issues #13/#14 which are actually service-layer code changes.  
**Action:** Captured for team memory and routing correction.

#### Directive 2: Quality Pass Autonomy (2026-04-25T04:41Z)
**Authority:** Yashasg (via Copilot)  
**Policy:** When Ralph's GitHub board is clear (no open issues to work), run quality passes: tests, linter, code coverage, edge case analysis. Create new GitHub issues under the TestFlight milestone from any findings, so Ralph can pick them up and keep working autonomously.  
**Rationale:** Keeps the pipeline self-sustaining. Ralph generates its own work from quality analysis rather than idling.

#### Directive 3: Always Rebase Before PR Work (2026-04-25T05:04Z)
**Authority:** Yashasg (via Copilot)  
**Policy:** When working on PRs, always work off of the latest version in origin main. Run `git fetch origin main && git rebase origin/main` (or branch from `origin/main`) before starting any PR work.  
**Rationale:** Ensures PRs are always based on the latest code and avoids stale branch conflicts.

#### Directive 4: Commit Directly to Main (2026-04-25T06:24Z)
**Authority:** Yashasg (via Copilot)  
**Policy:** Don't create new branches. Commit directly to main and push. No PRs — just commit to main.  
**Rationale:** Simplifies workflow, avoids PR overhead for this project.

---

### Decision 3.9: Roadmap Status & v1.0 Scope Closure (Danny)
**Date:** 2026-04-25  
**Status:** READY FOR TEAM REVIEW  
**Author:** Danny (Product Manager)

#### Summary
ROADMAP.md has been audited and updated to reflect actual project state. **Phase 1 (MVP) is fully shipped. Phase 2 (Polish) is ~80% complete** with all major features delivered except final App Store submission sign-off. **Phase 3 (Advanced) is partially started** with dependency injection refactoring work in progress (issues #13-14).

**Recommendation:** Close v1.0 scope to Phase 1+2 (no Phase 3 changes). Defer iCloud sync, widgets, and watchOS to v1.1 post-launch. This allows focused App Store submission without scope creep.

#### Phases Delivered
- **Phase 0:** ✅ Foundation complete; scaffolding, SPM, CI/CD, MVVM, design system
- **Phase 1:** ✅ MVP complete; settings, notifications, overlay, countdown, haptics, snooze, 65+ tests
- **Phase 2:** 🔄 ~80% complete; onboarding, smart pause, screen-time triggers, accessibility, data-driven config, legal docs
- **Phase 3:** 🔄 Partially started; DI refactoring, XCUITest scaffold in progress

#### Deferred to v1.1
- iCloud sync
- Home Screen widget
- watchOS companion

---

### Decision 3.10: Test Resource Access Pattern (Livingston)
**Date:** 2026-04-25  
**Issues:** #11  
**Status:** ✅ IMPLEMENTED

#### AppConfigTests Fixture Mismatch Root Cause
Root cause: AppConfigTests was loading production bundle resources via `@testable import` shadowing, failing fixture assertions with stale/mismatched defaults. Implemented `TestBundle.module` pattern for reliable production resource access from test targets.

#### Coverage Report Findings
- **Total Coverage:** 85%+ (exceeds 80% target)
- **Gaps identified:**
  - AppCoordinator: 37% — scheduling tests missing (high-risk path)
  - OverlayManager: 14% — queue + presentation pipeline untested (core UX)
  - Live*Detectors: 0% — requires mocking of system frameworks
- **Recommendations:**
  1. Add AppCoordinator scheduling tests immediately (CI dependency)
  2. Add OverlayManager integration tests (UX trust)
  3. Extract Live*Detector dependencies behind protocols (enables full coverage)
  4. Consider ViewInspector for SwiftUI render testing (all 2,747 lines currently dark)

---

### Decision 3.11: Protocol Co-Location Convention (Rusty)
**Date:** 2026-04-25  
**Status:** Documenting existing convention

#### Decision
Protocols are co-located with their primary implementation file — there is no `Protocols/` folder. ARCHITECTURE.md has been updated to reflect this. The team should treat this as the canonical convention going forward.

#### Current Protocol Mapping
- `SettingsPersisting` → `SettingsStore.swift`
- `NotificationScheduling`, `ReminderScheduling` → `ReminderScheduler.swift`
- `ScreenTimeTracking` → `ScreenTimeTracker.swift`
- `OverlayPresenting` → `OverlayManager.swift`
- `MediaControlling` → `AudioInterruptionManager.swift`
- `PauseConditionProviding`, `FocusStatusDetecting`, `CarPlayDetecting`, `DrivingActivityDetecting` → `PauseConditionManager.swift`

#### Rationale
For a codebase at this size, co-location reduces file-hop friction when reading a service. The protocol immediately precedes (or follows) its concrete implementation — no need to jump to a separate file to understand the contract. A `Protocols/` folder makes more sense when protocols are shared across multiple modules or when the protocol is the public API of a framework.

#### Trigger Model Convention
`ReminderScheduler` is now narrowed to **snooze-wake notifications only**. The regular reminder cadence is owned entirely by `ScreenTimeTracker`. Any future work that touches reminder scheduling must account for this split — do not add repeating `UNNotificationTrigger` back to `ReminderScheduler`.

#### ARCHITECTURE.md as Living Document
ARCHITECTURE.md should be included in PR diffs for any service-layer change. It drifted significantly from the codebase because there was no norm requiring updates. Recommend adding a PR checklist item: "Does this change require an ARCHITECTURE.md update?"

---

### Decision 3.12: CI Build Robustness (Virgil)
**Date:** 2026-04-24  
**Branch:** squad/15-fix-appconfig-tests  
**Commit:** 72f1088  
**Status:** ✅ IMPLEMENTED

#### Decision
`scripts/build.sh detect_destination()` now checks the `$SIMULATOR` environment variable first. When set, it is used verbatim as the xcodebuild destination. Dynamic simulator detection is only used when `$SIMULATOR` is unset (local developer workflow).

#### Rationale
The CI workflow (`.github/workflows/ci.yml`) exports:
```
SIMULATOR: "platform=iOS Simulator,name=iPhone 16,OS=latest"
```

But `build.sh` was ignoring it — dynamically picking the first available iPhone from `xcrun simctl list devices available` and appending `,OS=latest`. On the CI runner (Xcode 16.2, macos-14), this produced `iPhone 15 Pro,OS=latest`, which didn't match any available device. Build exited with code 70.

#### Impact
- CI builds now use the configured simulator consistently
- Local builds still auto-detect (no developer workflow change)
- `,OS=latest` removed from dynamic fallback — fragile when paired with arbitrary device names

#### Rule Going Forward
Never add `,OS=latest` to a dynamically discovered device name. If you need a specific OS, set `$SIMULATOR` explicitly in the workflow env block.

---

Generated: 2026-04-25T06:20:00Z  
Scribe: Merged 11 decision files from inbox (basher DI, 4 copilot directives, danny roadmap, livingston tests, rusty architecture, virgil build); inbox ready for deletion

---

# Quality Sweep — 2026-04-26 — 8-Agent Audit Findings

## Rusty: Architecture Quality Review

**Status:** A grade (informational)

### Finding 1: OverlayManager singleton is dead code
`static let shared` (line 63) duplicates DI protocol injection. **Action:** Remove singleton, let coordinator be the only owner.

### Finding 2: SettingsView ViewModel box pattern needs refactoring
`@StateObject` wrapping optional `SettingsViewModel?` means `viewModel` is `nil` during first render. **Action:** Construct in init or pass as parameter.

### Finding 3: Protocol extraction per ARCHITECTURE.md
`SettingsPersisting`, `NotificationScheduling`, `MediaControlling` scattered across service files. **Recommendation:** Extract to `Protocols/` directory for discoverability (future work).

### Finding 4: Timer.publish more idiomatic than Timer + RunLoop
`OverlayView` uses `Timer(timeInterval: 1)` + `RunLoop.main`. **Suggestion:** Consider `Timer.publish(...).onReceive` pattern.

---

## Saul: Code Quality & Readability Review

**Status:** No criticals; 1 warning; 6 suggestions

### Decision 1: Long-method threshold (40 lines max)
- `AnalyticsLogger.log()` — 72 lines
- `AppCoordinator.scheduleReminders()` — 52 lines
- `SettingsView.body` — 347 lines (suppressed via linter)
**Rule:** Methods >40 lines require refactoring before merge.

### Decision 2: Consistent `[weak self]` in Task closures
AppCoordinator line 587 uses strong `self` (inconsistent). **Rule:** All Task closures on reference types must use `[weak self]` unless provably short-lived and documented.

### Decision 3: Linter suppressions require tracking
`SettingsView` line 13 suppresses `type_body_length`. **Rule:** Suppressions must have tracking issue.

### Decision 4: Test file split threshold
`StringCatalogTests.swift` (1046 lines) too large. **Rule:** Test files >300 lines should split into focused categories.

---

## Livingston: Test Quality & Coverage Audit

**Status:** 3 criticals, 7 warnings

### Critical 1: OnboardingTests uses wrong UserDefaults key
**File:** `Tests/EyePostureReminderTests/Models/OnboardingTests.swift` L19  
Tests use `"hasSeenOnboarding"` but production uses `"epr.hasSeenOnboarding"`. Entire test is false-positive green.  
**Action:** Fix key to match production `AppStorageKey.hasSeenOnboarding`.

### Critical 2: SettingsStore.resetToDefaults() untested
Destructive operation (clears + re-seeds all settings) has zero automated tests.  
**Action:** Implement pending tests before Phase 2 ships.

### Critical 3: UI tests cannot run (SPM limitation)
31 UITest files require `.xcodeproj` UITest target (SPM doesn't support). Onboarding flow, overlay dismiss, settings navigation have zero end-to-end coverage.  
**Action:** Team decision on `.xcodeproj` strategy or accept gap.

### Warning: Flakiness risks
- 200ms sleep in SettingsViewModelTests (recommend 500ms for CI)
- ScreenTimeTracker 8s timeout marginal for 2-tick sequence

---

## Linus: UI Code Quality Audit

**Status:** 0 criticals; 7 warnings; 6 suggestions

### W-1: SettingsView body too long
~350 lines; Snooze section alone is ~90 lines. **Fix:** Extract `SnoozeSectionView`, `SmartPauseSectionView`, `NotificationWarningSection`.

### W-2: OverlayView dismiss button font is one-off
`Font.system(.title).weight(.medium)` bypasses `AppFont`. **Fix:** Add `AppFont.overlayDismiss` token or reuse `AppFont.headline`.

### W-3: Magic `1000` fallback for screen height
`UIApplication.shared...screen.bounds.height ?? 1000` is arbitrary. **Fix:** Use `GeometryReader` or `UIScreen.main.nativeBounds.height`.

### W-4: Hardcoded `"moon.zzz.fill"` in 2 files
Appears in `HomeView.swift` L22 and `SettingsView.swift` L115. **Fix:** Add `AppSymbol.snoozed = "moon.zzz.fill"`.

### W-5: Hardcoded animation durations
- `ContentView` 0.4s easeInOut
- `OnboardingView` 0.4s easeOut + 0.1s delay
- `OverlayView` 0.05s grace delays
**Fix:** Add `AppAnimation.onboardingTransition`, `AppAnimation.reduceMotionGraceDuration`.

### W-6: ReminderRowView missing #Preview
Only view file without preview. Expand/collapse Picker logic needs one.

### W-7: OnboardingPermissionView uses raw `44` instead of `AppLayout.minTapTarget`

---

## Basher: Service Layer Quality Audit

**Status:** 0 criticals; 4 warnings; 5 suggestions

### Warning 1: OverlayManager.showOverlay() silently drops requests
When `isOverlayVisible == false` and no active UIWindowScene, request returns early without queueing or callback.  
**Fix:** Queue request and drain from `presentNextQueuedOverlay()`.

### Warning 2: ScreenTimeTracker.handleWillResignActive() doesn't cancel prior resetTask
Two Tasks can both survive and call `resetAll()` if notification fires twice.  
**Fix:** Add `resetTask?.cancel()` before assignment.

### Warning 3: AppCoordinator.cancelAllReminders() reads stale auth status
Snooze-wake notification gated on `notificationAuthStatus == .authorized`, which may be stale `.notDetermined` on first snooze.  
**Fix:** Refresh auth status or remove gate.

### Warning 4: PauseConditionManager.focusMode initial state not seeded
`LiveFocusStatusDetector` only fires on transitions, not initial state. Focus mode already active at launch won't pause until change.  
**Fix:** Seed initial state after `focusDetector.startMonitoring()`.

---

## Danny: Documentation Audit

**Status:** 2 criticals, 4 warnings

### Critical 1: Legal placeholders in TERMS.md and PRIVACY.md
`[Date]` and `[Your Company Name]` must be filled before App Store submission.  
**Owner:** Frank

### Critical 2: UX_FLOWS.md stale (pre-onboarding path)
Section 2.1 describes Settings + permission prompt path. Actual app has 3-screen onboarding.  
**Owner:** Reuben

### Warning: IMPLEMENTATION_PLAN.md stale
Section 9 Data Flow says `repeat: true` (pre-ScreenTimeTracker). Section 1 says "runs timers in background" (inaccurate).  
**Owner:** Rusty

### Warning: ARCHITECTURE.md stale
Section 3 says "swift build / swift test" (contradicts README: xcodebuild required). Status header "Foundation" outdated.  
**Owner:** Rusty

---

## Tess: Accessibility & Design System Audit Pass 3

**Status:** 9/10 health; 0 criticals; 1 warning; 3 suggestions (previously 5 criticals resolved)

### Resolved Issues
✅ Issue #32 — Onboarding design token violations  
✅ Issue #33 — ReminderRowView hardcoded a11y strings  
✅ Issue #35 — Sub-44pt tap targets  
✅ Issue #36 — 24h time format  
✅ P0 — `accessibilityViewIsModal` on overlay  
✅ P0 — ReminderType hardcoded English  

### Warning: OnboardingScreenWrapper deviates from Reduce Motion pattern
Currently uses `.linear(duration: 0.15)` fade. Team pattern elsewhere is `nil` (no animation).  
**Fix:** Use `nil` animation, align with OverlayView, SettingsView, ReminderRowView.  
**Owner:** Linus

### Suggestion 1: LegalDocumentView dismiss button missing `.accessibilityHint`
VoiceOver announces "Done, button" with no context. Add hint: "Closes this document and returns to Settings".

### Suggestion 2: OverlayView dismiss icon font not a token
Uses `Font.system(.title).weight(.medium)` instead of AppFont. Add token or comment explaining deviation.

---

## Virgil: CI/CD & Build Config Quality Audit

**Status:** 1 critical; 5 warnings; 4 suggestions

### Critical: Doubled path in scripts/set-build-info.sh L34
```bash
# Wrong:
PLIST_PATH="${SCRIPT_DIR}/../EyePostureReminder/EyePostureReminder/Info.plist"
# Right:
PLIST_PATH="${SCRIPT_DIR}/../EyePostureReminder/Info.plist"
```
Fallback fires when `INFOPLIST_FILE`/`SRCROOT`/`BUILT_PRODUCTS_DIR`/`PRODUCT_NAME` unset. Latent bug.  
**Action:** Fix line 34.

### Warning 1: Stale audit scripts committed
6 one-off scripts from review session:  
`audit_workflows.sh`, `detailed_audit.py`, `detailed_manual_audit.sh`, `edge_case_audit.sh`, `final_audit.sh`, `script_validation.sh`  
**Action:** `git rm` all six.

### Warning 2: No concurrency group in ci.yml
Rapid commits trigger parallel runs, wasting CI minutes on stale jobs.  
**Fix:** Add concurrency group with `cancel-in-progress: true`.

### Warning 3: Coverage threshold 50% vs stated target 80%
CI gate too lenient. **Fix:** Raise to 75% with stretch goal 80%.

### Warning 4: deploy-testflight job has no timeout-minutes
Can hang indefinitely during Apple delays. **Fix:** Add `timeout-minutes: 45`.

### Warning 5: Untracked build artifacts
`audit_check`, `build_check.log`, `build_output.log` not in `.gitignore`.  
**Fix:** Add to `.gitignore`.

---

## Cross-Cutting Themes

### Theme 1: SettingsView Decomposition (Saul + Linus + Rusty)
- Saul: Method length threshold exceeded
- Linus: W-1 recommends section extraction
- Rusty: ViewModel box pattern debt
**Consolidated Action:** Decompose SettingsView.body into extracted subviews.

### Theme 2: AppFont/AppAnimation Token Gaps (Linus + Tess)
- Linus: W-2, W-5 identify missing tokens
- Tess: S2 flags OverlayView font deviation
**Consolidated Action:** Extend AppFont, AppAnimation, AppSymbol for coverage.

### Theme 3: Reduce Motion Consistency (Tess + Linus)
- Tess: W1 flags OnboardingScreenWrapper 0.15s fade
- Linus: S-6 suggests async timer pattern
**Consolidated Action:** Align OnboardingScreenWrapper to `nil` pattern.

### Theme 4: Documentation Stale (Danny + Rusty)
- Danny: Legal, UX flows, IMPLEMENTATION_PLAN blockers
- Rusty: ARCHITECTURE.md build instructions
**Owners Assigned:** Frank (legal), Reuben (UX), Rusty (impl/arch).

### Theme 5: Test Coverage Critical Path (Livingston + Basher)
- Livingston: 3 criticals (key mismatch, untested method, dead code)
- Basher: Service layer edge cases identified
**Action:** Fix OnboardingTests, add resetToDefaults tests, evaluate UI test strategy.

---

## Merged from Inbox (2026-04-26)\n

### From: copilot-directive-2026-04-25T19-13-50.md

### 2026-04-25T19:13:50Z: User directive
**By:** Yashasg (via Copilot)
**What:** "Data IS leaving the device. We ARE collecting analytics." — This corrects the prior assumption that the app uses zero data collection. Frank's legal research assumed "Data Not Collected" for Privacy Nutrition Labels, which is now WRONG.
**Why:** User correction — critical for legal compliance. Affects Privacy Policy, Privacy Nutrition Labels, and potentially ATT requirements.

### From: frank-analytics-privacy-update.md

# Frank — Analytics Privacy Update

**Date:** 2026-04-26  
**Requested by:** Yashasg  
**Subject:** Re-evaluation after correction that the app collects analytics through `os.Logger` and MetricKit

## Executive Summary

The prior blanket recommendation of **"Data Not Collected" for everything is no longer the right product/legal posture** once the team acknowledges MetricKit/App Store Connect analytics as data leaving the device and analytics being collected.

The correct updated position is:

- **`os.Logger` local logs:** still **not collected** for App Store Privacy Nutrition Label purposes when logs remain on-device and private values are redacted.
- **MetricKit / App Store Connect diagnostics and metrics:** should be disclosed in the privacy policy for transparency. For App Store Privacy Nutrition Labels, the conservative recommendation is to disclose relevant **Diagnostics** categories, even if Apple's own system is the collection path and the developer only sees aggregated/non-user-level reporting.
- **ATT:** still **not required** because MetricKit does not track users across apps/websites, does not use IDFA, and is not a third-party tracking SDK.
- **No third-party SDK:** remains a major privacy advantage and should be stated clearly.

This is not a Firebase/Mixpanel-style analytics architecture. It is Apple-native diagnostics and performance analytics, with no user-level tracking and no custom backend.

---

## 1. Privacy Nutrition Labels

### Apple's working definition

Apple's App Privacy disclosures focus on data transmitted off-device and made available to the developer and/or third parties, including data collected for analytics, diagnostics, app functionality, advertising, or tracking. Data that stays entirely on-device generally is **not "collected"** for Privacy Nutrition Label purposes.

The hard part here is MetricKit/App Store Connect: the app is not sending analytics to a custom backend or third-party vendor, but Apple receives metrics/diagnostics and the developer can view aggregated reports in App Store Connect. Because the user has explicitly corrected the team that "data is leaving the device" and "we are collecting analytics," the safest and most transparent submission posture is not to rely on a blanket **Data Not Collected** answer.

### Correct answer by data type

| Data / system | Leaves device? | Developer receives user-level data? | Privacy label recommendation | Notes |
|---|---:|---:|---|---|
| App preferences in `UserDefaults` | No, except ordinary device backup controlled by iOS | No | **Not Collected** | Reminder intervals, toggles, local settings remain in the app sandbox. |
| Motion activity via `CMMotionActivityManager` | No, per current architecture | No | **Not Collected** | Still qualifies as transient/in-memory if not stored or transmitted. Keep purpose string accurate. |
| Focus status via `INFocusStatusCenter` | No, per current architecture | No | **Not Collected** | Still transient/in-memory pause logic. |
| `os.Logger` structured logs | No in normal release operation | No | **Not Collected** | Local logging is not collection. Continue using `.private` for values that could be sensitive. |
| `os.Logger` logs in developer/TestFlight diagnostics | Potentially, if user shares diagnostics/logs | Limited and diagnostic-only | Usually **not app analytics collection**, but disclose in privacy policy/TestFlight language | This is user/device diagnostic sharing through Apple, not a third-party analytics SDK. Keep redaction discipline. |
| MetricKit / App Store Connect metrics | Yes, through Apple | Aggregated, not user-level | **Conservatively disclose Diagnostics** | Recommended categories: **Diagnostics → Crash Data** if crash/hang data is available; **Diagnostics → Performance Data** for CPU, memory, launch, hang, energy, disk, etc. Mark **Not Linked to User** and **Not Used for Tracking**. |
| Third-party analytics SDKs | Not currently present | N/A | **Not applicable today** | If added later, labels change materially. See checklist below. |

### Recommended App Store Connect privacy answers

If the app continues with only Apple-native MetricKit/App Store Connect analytics and local `os.Logger`:

1. Do **not** state a universal **Data Not Collected** position if the team treats MetricKit/App Store Connect analytics as collected analytics.
2. Disclose, at minimum:
   - **Diagnostics → Crash Data** if crash reports/hang diagnostics are surfaced to the developer.
   - **Diagnostics → Performance Data** for MetricKit performance metrics.
3. For those categories, mark:
   - **Linked to the user:** No.
   - **Used for tracking:** No.
   - **Purpose:** Analytics and/or App Functionality, depending on Apple's available purpose selections in App Store Connect. If forced to choose one primary reason, use **Analytics** for aggregate product/performance insight and **App Functionality** for detecting reliability/performance issues.
4. Do **not** disclose `os.Logger` local logs as collected data when they stay on-device.
5. Do **not** disclose local `UserDefaults`, transient motion, or transient Focus status as collected data unless the implementation changes to transmit them.

### Why this changes the prior recommendation

The earlier analysis was valid only under an on-device-only/no-analytics assumption. The corrected facts add an Apple-native analytics/diagnostics pipeline. Even though it is privacy-preserving and not third-party tracking, it is no longer accurate in plain English to tell users that **nothing ever leaves the device** or that the app has **no analytics**.

---

## 2. Privacy Policy

### Does current `docs/legal/PRIVACY.md` need updates?

Yes. The current privacy policy needs updates because it contains statements that are now overbroad or inaccurate under the corrected facts, including:

- "almost nothing is collected, and what is stored never leaves your device"
- "No persistent usage analytics"
- "No crash reporting"
- "The App uses Apple's MetricKit framework ... no MetricKit data is transmitted to any external service"
- "No server communication" / "operates entirely offline" if stated in a way that implies no Apple diagnostics/analytics pipeline exists
- "We do not transmit any data over any network" if it ignores Apple/MetricKit/App Store Connect diagnostics

The policy should explicitly disclose MetricKit/App Store Connect analytics for user trust, even if a narrow App Store privacy-label interpretation might not require all Apple-collected aggregate metrics to be treated as developer collection.

### Recommended policy language direction

Update the privacy policy to say something like:

> The App uses Apple's built-in diagnostics and analytics tools, including MetricKit and App Store Connect analytics, to understand aggregate app performance, reliability, crashes, hangs, launch times, memory use, and similar technical metrics. These reports are processed through Apple's systems and are provided to the developer in aggregated or diagnostic form. They are not used to identify you, track you across apps or websites, build advertising profiles, or sell data.

Also update the local logging section:

> The App uses Apple's `os.Logger` framework for on-device diagnostic logging. These logs normally remain on your device. In release builds, values that could be sensitive are marked private/redacted. If you choose to share diagnostics with Apple or a TestFlight developer, some diagnostic logs may be included according to Apple's diagnostic-sharing settings.

The policy should preserve these important privacy assurances:

- No third-party analytics SDKs.
- No Firebase, Mixpanel, advertising SDK, data broker, or custom analytics backend.
- No IDFA collection.
- No user accounts.
- No sale of data.
- No cross-app or cross-website tracking.
- Local settings remain on-device.
- Motion and Focus status remain transient and are not stored/transmitted by the app.

---

## 3. ATT — App Tracking Transparency

MetricKit does **not** trigger ATT by itself.

ATT is required when the app tracks users across apps or websites owned by other companies, shares data with data brokers, uses the IDFA, or combines app data with third-party data for advertising/measurement/tracking purposes.

Current facts do not meet that threshold:

- MetricKit is Apple-native diagnostics/performance reporting.
- Developer visibility is aggregate/non-user-level.
- There is no IDFA access.
- There is no third-party analytics SDK.
- There is no ad network.
- There is no cross-app/cross-site profiling.
- `os.Logger` is local diagnostic logging, not tracking.

**Recommendation:** Do not add the ATT prompt for the current architecture. Adding ATT when not needed can confuse users and may create review questions because it implies tracking that the app does not perform.

---

## 4. What Changes From Prior Recommendations

### Changes

1. **Privacy posture changes from "no analytics" to "Apple-native aggregate diagnostics/analytics."**  
   The app should no longer claim that it has no analytics at all.

2. **Privacy Policy must be updated.**  
   It should disclose MetricKit/App Store Connect analytics and revise any blanket "nothing leaves the device" or "no crash reporting" language.

3. **Privacy Nutrition Label recommendation changes.**  
   The prior blanket **Data Not Collected** recommendation should be replaced with a more nuanced answer:
   - Local-only data and transient sensor/status access: **Not Collected**.
   - `os.Logger` local logs: **Not Collected** unless exported/shared through diagnostics.
   - MetricKit/App Store Connect diagnostics: conservatively disclose **Diagnostics → Crash Data** and **Diagnostics → Performance Data**, **Not Linked to User**, **Not Used for Tracking**.

4. **TestFlight/diagnostic sharing language becomes more important.**  
   The policy should explain that diagnostic logs or reports may be shared through Apple's diagnostic-sharing mechanisms if the user has enabled them.

### Stays the same

1. **ATT is still not required.**
2. **No third-party SDK disclosure is needed today.**
3. **No advertising/tracking/data broker language is needed beyond saying it does not happen.**
4. **Local settings, motion activity pause logic, and Focus status pause logic remain privacy-minimal.**
5. **Health/wellness disclaimer recommendations remain unchanged.**
6. **No account, server, billing, or custom backend terms are needed based on this correction alone.**
7. **The app can still truthfully market itself as privacy-preserving**, but not as "no analytics" or "nothing leaves the device" without qualification.

---

## 5. If a Third-Party Analytics SDK Is Added Later

Adding Firebase Analytics, Mixpanel, Amplitude, Segment, Sentry, Datadog, Bugsnag, or a similar SDK materially changes the analysis. The team should complete this checklist before shipping any third-party analytics SDK.

### Vendor and SDK due diligence

- Identify the SDK/vendor, exact product, and purpose.
- Review the vendor's privacy policy, data processing addendum, subprocessors, retention periods, and security documentation.
- Confirm whether the SDK collects device identifiers, installation IDs, IP address, coarse location, advertising identifiers, events, session data, crash logs, or user properties.
- Disable optional data collection features not needed for the app.
- Confirm whether the SDK runs in the app extension/background contexts, if any.
- Confirm whether the SDK has its own Apple Privacy Manifest and required reason APIs.

### App Store Privacy Nutrition Labels

Update labels for every collected category, likely including some combination of:

- **Identifiers** — user ID, device ID, installation ID, advertising ID, or vendor ID if used.
- **Usage Data** — product interaction, sessions, taps, screen views, feature usage.
- **Diagnostics** — crash data and performance data.
- **Location** — if IP-derived location or precise/coarse location is collected.
- **Contact Info** — if email/user account data is added.
- **Other Data** — if custom event payloads do not fit Apple's listed categories.

For each category, decide and document:

- Purpose: Analytics, App Functionality, Product Personalization, Developer Advertising/Marketing, Third-Party Advertising, etc.
- Linked to user: Yes/No.
- Used for tracking: Yes/No.
- Optional vs required disclosure exceptions.
- Retention period.

### ATT analysis

Reassess ATT before enabling the SDK.

ATT may be required if the SDK or vendor:

- Uses IDFA.
- Links app data with third-party app/web data for advertising or advertising measurement.
- Shares data with data brokers.
- Performs cross-app/cross-website profiling.
- Uses SDK-level identifiers to recognize users across unrelated apps.
- Enables ad attribution/retargeting integrations.

ATT may not be required if the SDK is configured strictly for first-party analytics, no IDFA, no cross-app tracking, no ad network sharing, and no data broker sharing — but this must be verified vendor-by-vendor and setting-by-setting.

### Privacy Policy updates

Before shipping, update the policy to include:

- SDK/vendor name.
- Types of data collected.
- Purpose of collection.
- Whether data is linked to the user.
- Whether data is used for tracking.
- Whether data is shared with service providers.
- Retention/deletion practices.
- Opt-out controls if available.
- International transfer language if applicable.
- Contact path for privacy requests.

### Product and engineering controls

- Add a tracking/analytics configuration inventory to the release checklist.
- Do not log sensitive health, motion, Focus, or settings values in analytics events.
- Avoid custom event names or properties that encode personal information.
- Gate any optional tracking behind consent where legally required.
- Keep analytics disabled in tests/previews unless explicitly needed.
- Document how to disable/delete analytics data if a user requests it.

---

## Bottom Line

The corrected facts do not make this a tracking app, and they do not require ATT. They do require clearer disclosures. The team should update the privacy policy and avoid a blanket **Data Not Collected / no analytics / nothing leaves device** posture. The accurate position is: **local app data stays on-device; Apple-native MetricKit/App Store Connect diagnostics and aggregate analytics may leave the device through Apple; no third-party analytics or user-level tracking is used.**

### From: frank-copyright-analysis.md

# Frank — Copyright & IP Analysis: Eye & Posture Reminder vs LookAway

**Requested by:** Yashasg  
**Date:** 2026-04-26  
**Scope:** Copyright, trademark, App Store naming, UI/design, and high-level patent risk for Eye & Posture Reminder, with specific comparison to LookAway.

> **Important:** This is product/IP risk analysis for planning, not a formal legal opinion, trademark clearance report, or patent freedom-to-operate opinion. Formal clearance should be done by trademark/patent counsel before App Store launch if the product name or feature set becomes commercially important.

---

## Executive summary

**Overall risk: low to moderate, manageable.** Eye & Posture Reminder sits in a crowded, ordinary product category: screen-break, eye-rest, posture, and digital wellness reminders. The core idea — reminding users to take eye breaks, follow the 20-20-20 rule, blink, stretch, or check posture — is not copyrightable. The main avoidable risks are **trademark confusion**, **copying competitor copy/screens/artwork**, and **claiming medical benefits too aggressively**.

The current app name, **“Eye & Posture Reminder,”** is descriptive and meaningfully different from **“LookAway.”** It is unlikely to create direct trademark confusion with LookAway. However, because descriptive names can be weak as brands and because App Store search results contain many similar “Eye,” “20-20-20,” “Eye Care,” and “Eye Break” names, the team should perform an App Store search and at least a knockout trademark search before final submission.

---

## 1. LookAway app analysis

### What LookAway does

LookAway is a macOS Health & Fitness / digital wellness app by **Mystical Bits, LLC**. Its App Store listing describes it as a lightweight menu-bar companion that helps reduce eye strain and improve screen habits. Reported features include:

- micro and long break scheduling, including 20-20-20-style routines;
- skip/snooze behavior;
- non-interruption logic for microphone use, screen recording, specific apps, and calendar events;
- subtle nudges such as cursor wiggles, menu-bar timers, chimes, and full-screen visuals;
- posture, blink, and screen-overtime reminders;
- statistics, break history, session lengths, app usage, and “Screen Score”;
- macOS-native integrations such as Shortcuts/AppleScript;
- local/private processing claims.

Sources reviewed:

- LookAway App Store listing: https://apps.apple.com/us/app/lookaway-digital-wellness/id6747192301?mt=12
- LookAway website: https://lookaway.com/
- LookAway documentation: https://lookaway.com/docs/

### Comparison to Eye & Posture Reminder

| Area | LookAway | Eye & Posture Reminder | IP significance |
|---|---|---|---|
| Platform | Mac-first/menu-bar product | iOS app | Platform and UX context differ materially. |
| Core concept | Break reminders, 20-20-20, blink, posture, screen habits | Eye-break and posture reminders | Functional overlap is expected in this category. |
| Break UI | Full-screen visuals, sounds, menu bar, cursor wiggles | iOS notifications / overlay reminders | Similar reminder concepts are not enough for copyright infringement. Avoid copying exact visuals/copy. |
| Analytics/stats | Screen Score, stats, app/website usage | Simpler MVP, local reminders, possible Apple-native diagnostics | Avoid using “Screen Score” or LookAway-specific naming/metric concepts. |
| Branding | “LookAway” | “Eye & Posture Reminder” | Low direct name-confusion risk. |

### Are there trademarks on “LookAway”?

I found strong marketplace use of **LookAway** by Mystical Bits, LLC, but did **not** find reliable public evidence in this research pass of a registered or pending USPTO trademark specifically for “LookAway” covering software/app services. That does **not** mean no rights exist:

- trademark rights can arise from use, even without federal registration;
- there may be non-US registrations;
- registry search results can change;
- similar marks in adjacent classes can matter.

**Practical conclusion:** do not use “LookAway,” “Look Away,” or close variants in the app name, subtitle, icon, tagline, or marketing in a way that suggests affiliation. It is fine to internally analyze LookAway as a competitor.

### Could “Eye & Posture Reminder” conflict with existing trademarks?

“Eye & Posture Reminder” is highly descriptive: it directly states the app’s function. Descriptive marks are usually weaker and harder to enforce, but they can still conflict if another party has a similar registered or common-law mark and users could be confused.

I found many nearby app names in the market, including examples such as **iCare - Eye Break Reminders**, **Eye Care 20 20 20**, **Eye Yoga - 20 20 20 Rule Timer**, **EyeRest**, **20.20.20: Eye Care & Tracker**, and **Eye Break: A 20/20/20 Timer**. This suggests a crowded field, which lowers the chance one party owns broad rights in generic words like “Eye,” “Break,” “Reminder,” or “20-20-20,” but increases the chance of App Store discoverability/name collision issues.

**Current name risk:** low to moderate. It is unlikely to conflict with LookAway specifically, but should be checked against App Store and trademark databases before submission.

---

## 2. 20-20-20 rule — copyrightability and ownership

### Is the 20-20-20 rule copyrightable?

No, not as a concept. The U.S. Copyright Office states that copyright protects original expression but **does not protect facts, ideas, systems, methods of operation, concepts, or short phrases/names**. The 20-20-20 rule is a short health/wellness guideline: every 20 minutes, look at something 20 feet away for 20 seconds. That underlying concept, method, and short phrase are not copyrightable as such.

Authoritative source:

- U.S. Copyright Office FAQ, “What Does Copyright Protect?”: https://www.copyright.gov/help/faq/faq-protect.html

Specific written explanations, diagrams, images, videos, articles, or app copy describing the rule can be copyrighted. We should write our own explanation and not copy competitor text or medical-site copy verbatim.

### Can anyone claim IP ownership over the concept?

A person or organization might claim authorship of a particular article, graphic, video, or branded implementation. They should not be able to monopolize the basic 20-20-20 recommendation through copyright.

Patent law is theoretically different: a specific technical implementation could be patented if novel/non-obvious and still in force. But the general advice “take eye breaks on a 20-minute interval” is a public-facing wellness rule used broadly in optometry and consumer software.

### Are there apps that use or trademark “20-20-20”?

There are many apps using “20-20-20” descriptively in names or subtitles, including App Store examples such as **20.20.20: Eye Care & Tracker**, **Eye Care 20 20 20**, and **Eye Break: A 20/20/20 Timer**. This is consistent with “20-20-20” being treated as a descriptive rule rather than a single-source brand.

**Recommendation:** use “20-20-20 rule” descriptively, not as the product’s primary brand. Example: “Supports the widely used 20-20-20 eye break guideline.” Avoid stylizing it as if we own it.

---

## 3. Feature overlap — is it a problem?

### Is implementing the same functionality a copyright issue?

Generally, no. Copyright protects expression, not functionality. Multiple apps can implement:

- timed reminders;
- full-screen or modal break prompts;
- countdown timers;
- local notifications;
- posture checks;
- skip/snooze;
- work-hour schedules;
- 20-20-20 intervals;
- break history or streaks.

These are product ideas, systems, methods, and standard UX patterns for the category. The risk appears when we copy protectable elements such as:

- competitor source code;
- exact screen layouts where creative choices are substantially similar;
- icons, illustrations, animations, sounds, or background art;
- exact marketing copy, onboarding text, reminder text, or screenshots;
- unique names such as “LookAway,” “Screen Score,” or distinctive proprietary feature names;
- a patented technical method.

### Idea vs implementation/design

| Safe / lower-risk | Higher-risk |
|---|---|
| “Remind users every 20 minutes to rest eyes.” | Copying LookAway’s exact reminder copy, artwork, break backgrounds, or sounds. |
| “Show a countdown for a break.” | Recreating a distinctive LookAway screen with the same composition, colors, animations, icons, and wording. |
| “Allow snooze/skip.” | Copying LookAway’s exact settings structure or labels if unusually distinctive. |
| “Track completed breaks.” | Naming a daily scoring metric “Screen Score” with similar presentation. |

### Patents to know about

There are patents in adjacent spaces: eye-strain reduction, visual break indications, posture monitoring, screen-time alerts, sensor-assisted ergonomics, and gaze/camera-based interventions. This pass did not perform a formal patent search or claim chart.

**Current MVP risk appears lower** if the app remains a conventional timer/notification/reminder app using iOS APIs and does not add advanced patented-sounding systems such as camera-based gaze detection, automated medical diagnosis, or specialized sensor algorithms.

**Recommendation:** if the app later adds camera/gaze tracking, sensor-based posture scoring, proprietary “health score” algorithms, enterprise monitoring, or enforced lockouts, commission a patent freedom-to-operate search.

---

## 4. App Store name conflicts

### Could “Eye & Posture Reminder” be too similar to existing app names?

It is descriptive and close to many category terms, but I did not identify a direct LookAway conflict. The bigger practical issue is App Store metadata review and user confusion among similarly named eye-break apps.

“Eye & Posture Reminder” is 23 characters, so it fits Apple’s 30-character app name limit. Apple describes the app name field as required and limited to 30 characters.

Sources:

- Apple App Store Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- Apple App Store Connect naming support: https://developer.apple.com/support/app-store-connect/name-your-app/

### Should we check App Store name conflicts before submission?

Yes. Before creating/finalizing the App Store Connect record:

1. Search the App Store for exact and close variants:
   - “Eye & Posture Reminder”
   - “Eye Posture Reminder”
   - “Eye Break Reminder”
   - “Posture Reminder”
   - “20 20 20 Reminder”
2. Check whether the name is accepted in App Store Connect.
3. Search Google/Google Play/Mac App Store for confusingly similar names.
4. Run a USPTO knockout search for exact and close marks.
5. If the app will be monetized or marketed seriously, have counsel run a formal clearance search.

### Apple's rules on app name uniqueness

Apple requires truthful, accurate, non-misleading metadata and rejects copying another developer’s work or using another party’s marks improperly. The app name field is limited to 30 characters. App Store Connect also enforces name availability operationally during app setup, but passing App Store Connect does **not** mean trademark clearance.

---

## 5. Design/UI copyright

### Are overlay reminders/countdowns a problem?

Not by themselves. Overlay reminders, full-screen break screens, timers, progress rings, snooze buttons, and calming break messages are standard patterns for reminder/timer/wellness apps. They are functional and expected.

### Where the line is

Lower-risk standard UI patterns:

- a countdown timer;
- a notification banner;
- a full-screen break overlay;
- generic “Take a break” messaging;
- standard iOS typography/components;
- simple settings for interval, duration, sound, snooze, work hours.

Higher-risk copying:

- substantially similar custom illustrations or animated backgrounds;
- same color palette + layout + text hierarchy + animations as LookAway;
- copied sounds/chimes;
- copied onboarding flow and exact copy;
- copied proprietary metric names such as “Screen Score”;
- using LookAway screenshots as design references too closely.

**Recommendation:** keep the app visually iOS-native and independently designed. Use original copy, original iconography, original colors, and original reminder text. Document design sources if heavily inspired by public design systems like Apple Human Interface Guidelines.

---

## 6. Recommendations

### Product/name recommendations

1. **Keep “Eye & Posture Reminder” for now** unless a trademark/App Store search finds a close conflict.
2. Consider a more distinctive brand later if the app becomes commercial. The current name is descriptive, legally safer against broad conflicts, but weak as a protectable brand.
3. Avoid competitor-specific terms:
   - Do not use “LookAway” or “Look Away.”
   - Do not use “Screen Score.”
   - Do not copy LookAway’s tagline, App Store copy, screenshots, icons, sounds, or break visuals.
4. Use “20-20-20 rule” descriptively only.
5. Avoid medical claims such as “prevents eye disease,” “cures headaches,” or “treats posture disorders.” Use wellness language: “may help,” “reminds you,” “supports healthy screen habits.”

### Search recommendations before App Store submission

Minimum pre-launch checks:

- App Store search for exact/similar names.
- USPTO search for exact/similar marks in software/mobile apps/health & fitness.
- Google web search for exact phrase “Eye & Posture Reminder.”
- Check Google Play and Mac App Store for close names.

Formal search recommended if:

- the name will be used in paid marketing;
- the app will monetize subscriptions/IAP;
- the team plans to register the mark;
- the app expands beyond a small indie MVP.

### Disclaimer recommendations

The existing legal direction is good: present the app as a reminder/wellness tool, not medical advice. Add or keep short language in onboarding, Settings/About, and App Store description along these lines:

> Eye & Posture Reminder is a wellness reminder tool and is not medical advice. It does not diagnose, treat, or prevent any medical condition. Consult a qualified health professional for eye strain, pain, posture concerns, or other medical symptoms.

### Patent recommendations

No immediate patent action is required for a simple timer/reminder MVP. Revisit with patent counsel before adding:

- camera/gaze detection;
- automated posture scoring;
- sensor-fusion posture correction;
- health-risk scoring;
- enforced device lockouts based on biometric/sensor conditions;
- enterprise monitoring/reporting.

---

## Bottom line

Eye & Posture Reminder can safely coexist with LookAway if it stays independently branded, uses original UI/copy/assets, and treats 20-20-20 as a public wellness guideline rather than a proprietary feature. The strongest next step is a **pre-submission name clearance pass**: App Store exact/similar search, USPTO knockout search, and final review of marketing copy for competitor-specific wording or unsupported medical claims.

### From: rusty-ui-test-architecture.md

# Architecture Proposal: Making UI Tests Runnable

**Author:** Rusty (iOS Architect)  
**Date:** 2026-04-26  
**Status:** Proposed  
**Issue:** GitHub #110 — "All 31 UI tests are dead code — no xcodeproj UITest target"

---

## Problem Statement

31 XCUITest methods exist across 4 files in `Tests/EyePostureReminderUITests/` — all dead code. SPM's `.testTarget` produces XCTest unit test bundles, not XCUITest UI test bundles. XCUITest requires a UITest bundle target, which can only be defined in an `.xcodeproj` or `.xcworkspace`. The tests compile against `XCTest` but call `XCUIApplication()`, which is XCUITest-only API — they will crash or fail to link in a unit test bundle.

**Existing test inventory (31 methods):**

| File | Tests | Pattern |
|---|---|---|
| `HomeScreenTests.swift` | 7 | `XCUIApplication` launch, element queries by accessibility ID |
| `OnboardingFlowTests.swift` | 7 | Multi-step flow navigation, launch arguments |
| `SettingsFlowTests.swift` | 13 | Sheet presentation, toggle interaction, navigation |
| `OverlayTests.swift` | 4 | Negative tests (overlay not present), accessibility label checks |

All 31 tests use `XCUIApplication`, `app.launch()`, `app.launchArguments`, element queries — genuine XCUITest patterns. They are **not convertible** to ViewInspector or unit tests without a full rewrite.

---

## Options Evaluated

### Option 1: Minimal .xcodeproj for UITest Target Only (⭐ RECOMMENDED)

Add a `.xcodeproj` that contains **only** the UITest bundle target. The app target and unit test target remain in `Package.swift`.

**How it works:**
- Xcode can open `Package.swift` directly and generates an implicit scheme for the executable and test targets.
- A small `.xcodeproj` is added containing:
  1. A reference to the app product from `Package.swift` (via scheme dependency)
  2. A UITest bundle target (`EyePostureReminderUITests`) pointing at `Tests/EyePostureReminderUITests/`
- `xcodebuild test` invokes the UITest scheme, which builds the app from the SPM package and runs UI tests against the simulator.

**Minimal xcodeproj contents:**
```
EyePostureReminder.xcodeproj/
├── project.pbxproj          # UITest target only
├── xcshareddata/
│   └── xcschemes/
│       └── EyePostureReminderUITests.xcscheme
```

**Pros:**
- All 31 existing tests work as-is (zero modifications to test code)
- Unit tests stay in SPM — no regression to existing workflow
- Full XCUITest capability: real app launch, accessibility auditing, interaction testing
- `Package.swift` remains the source of truth for app code and unit tests
- `.xcodeproj` is small and unlikely to drift (it only references the UITest files)

**Cons:**
- Two build system artifacts to maintain (though the xcodeproj is minimal)
- Team must understand which tests run where
- Xcode project file is notoriously merge-unfriendly (mitigated by small size)

### Option 2: Full .xcodeproj (Dual Build System)

Create a complete `.xcodeproj` with app target, unit test target, and UITest target. Keep `Package.swift` for CLI/CI unit tests.

**Pros:** Full Xcode feature set, App Store distribution from project  
**Cons:** Significant drift risk between Package.swift and xcodeproj. Two places to add files, update settings, manage dependencies. Maintenance burden far exceeds the benefit for UITests alone. **Not recommended.**

### Option 3: ViewInspector (Third-Party Library)

Add [ViewInspector](https://github.com/nicklkokot/ViewInspector) as an SPM dependency for testing SwiftUI views as unit tests.

**Pros:** Stays entirely in SPM, fast execution, no simulator  
**Cons:**
- Tests view **structure**, not rendering or interaction — fundamentally different from XCUITest
- All 31 tests would require a **complete rewrite** — they use `XCUIApplication`, launch arguments, element queries, navigation flows
- Cannot test: app launch behavior, overlay window presentation (UIWindow), notification permission prompts, accessibility in rendered context
- Cannot test cross-view navigation flows (onboarding → home → settings)
- Limited to inspecting individual views in isolation — our tests verify **flows**

**Verdict:** Wrong tool for these tests. ViewInspector is valuable for view-level unit tests (e.g., "does ReminderRowView show the correct icon?") but cannot replace flow-based UI tests. Could be added separately as a complement — not a replacement.

### Option 4: Xcode-Generated Project from Package.swift

`xcodebuild -create-xcodeproj` (deprecated) or opening Package.swift in Xcode to get the auto-generated scheme.

**Findings:**
- `swift package generate-xcodeproj` is deprecated since Swift 5.6 and removed in later toolchains
- Xcode's "Open Package" generates a **transient** workspace — no `.xcodeproj` on disk to add a UITest target to
- You cannot add a UITest target to the implicit workspace Xcode creates from Package.swift
- Dead end.

### Option 5: Swift Testing (@Test macros)

Swift Testing (`import Testing`, `@Test`, `@Suite`) is a modern test framework but operates at the **unit test level**. It does not provide:
- Application launch (`XCUIApplication`)
- Element queries (`app.buttons["id"]`)
- Simulated user interaction (taps, swipes, typing)
- Accessibility auditing

**Verdict:** Irrelevant to this problem. Swift Testing could replace XCTest for unit tests but has zero XCUITest equivalent.

---

## Recommendation: Option 1 — Minimal .xcodeproj for UITest Target

### Implementation Plan

#### Step 1: Create the Xcode project (xcodeproj)

Use `xcodebuild` or Xcode IDE to create a minimal project containing:
- **No app target** — the app builds from Package.swift via scheme reference
- **One UITest bundle target:** `EyePostureReminderUITests`
  - Source files: `Tests/EyePostureReminderUITests/*.swift`
  - Test host: `EyePostureReminder.app` (the SPM executable product)
  - `TEST_HOST = $(BUILT_PRODUCTS_DIR)/EyePostureReminder.app/EyePostureReminder`
  - `BUNDLE_LOADER = $(TEST_HOST)`... actually for UI tests these aren't needed — UI tests launch the app as a separate process.

For a UITest target specifically:
```
TEST_TARGET_NAME = EyePostureReminderUITests
PRODUCT_BUNDLE_IDENTIFIER = com.yashasg.EyePostureReminder.UITests
TEST_TARGET_NAME = EyePostureReminder  (target application)
USES_XCTRUNNER = YES
```

**Practical approach:** The simplest path is:
1. Open `Package.swift` in Xcode
2. File → New → Target → UI Testing Bundle
3. Set the target application to `EyePostureReminder`
4. Point the source files to `Tests/EyePostureReminderUITests/`
5. Save the generated `.xcodeproj`
6. Remove auto-generated boilerplate files (Xcode creates a default test file)

#### Step 2: Create a UITest Scheme

Add `EyePostureReminderUITests.xcscheme` in `xcshareddata/xcschemes/` so it's version-controlled:
- Build action: build `EyePostureReminder` (from Package.swift) and `EyePostureReminderUITests` (from xcodeproj)
- Test action: run `EyePostureReminderUITests` on iOS Simulator

#### Step 3: Update `scripts/build.sh`

Add a new subcommand:

```bash
cmd_uitest() {
  header "UI TEST"
  require_xcodebuild
  local dest
  dest=$(detect_destination)
  info "Destination: $dest"
  info "UI Test target: EyePostureReminderUITests"

  run_xcodebuild test \
    -project "EyePostureReminder.xcodeproj" \
    -scheme "EyePostureReminderUITests" \
    -destination "$dest" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -resultBundlePath "${PACKAGE_PATH}/UITestResults.xcresult"

  pass "UI tests passed"
}
```

#### Step 4: Update CI (`.github/workflows/ci.yml`)

Add a separate job or step for UI tests:

```yaml
  ui-test:
    name: UI Tests
    runs-on: macos-15
    timeout-minutes: 30
    needs: build-and-test  # Run after unit tests pass
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Select Xcode
        run: sudo xcode-select -switch /Applications/Xcode_${{ env.XCODE_VERSION }}.app/Contents/Developer

      - name: UI Tests (simulator)
        run: ./scripts/build.sh uitest

      - name: Upload UI test results
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: ui-test-results-build${{ github.run_number }}
          path: UITestResults.xcresult
          retention-days: 30
```

**Why a separate job:**
- UI tests are slow (simulator launch + app launch per test) — 2-5 minutes for 31 tests
- Unit tests should not be blocked by UI test failures
- UI tests are inherently flakier — separate job allows re-run without re-running unit tests
- Cleaner artifact separation (TestResults.xcresult vs UITestResults.xcresult)

#### Step 5: Test File Changes

**None.** All 31 existing test files use standard XCUITest patterns and will work as-is once the UITest bundle target exists. The accessibility identifiers are already in the production code (documented in the UITests README). The launch argument handling (`--skip-onboarding`, `--reset-onboarding`) is already wired in `AppDelegate.swift`.

#### Step 6: .gitignore Updates

Add to `.gitignore`:
```
# Xcode project user data (xcodeproj is committed, but user state is not)
*.xcodeproj/xcuserdata/
*.xcodeproj/project.xcworkspace/xcuserdata/
UITestResults.xcresult/
```

---

## Trade-Off Summary

| Criterion | Option 1 (Minimal xcodeproj) | Option 2 (Full xcodeproj) | Option 3 (ViewInspector) |
|---|---|---|---|
| Existing tests work as-is | ✅ Yes | ✅ Yes | ❌ Full rewrite |
| SPM unit tests unchanged | ✅ Yes | ⚠️ Risk of drift | ✅ Yes |
| Real device testing | ✅ Yes | ✅ Yes | ❌ No |
| Accessibility auditing | ✅ Yes | ✅ Yes | ❌ No |
| Maintenance burden | Low | High | Low |
| CI complexity | Medium (2 jobs) | High | Low |
| Flow testing | ✅ Full | ✅ Full | ❌ View-only |

---

## Risk Mitigation

**Risk: xcodeproj drift from Package.swift**
- Mitigation: The xcodeproj has NO app target — it only references the SPM-built app product. Drift can only occur if UITest source files are added/removed, which is infrequent.
- Add a CI check: verify UITest target source files match `Tests/EyePostureReminderUITests/*.swift` glob.

**Risk: UI test flakiness in CI**
- Mitigation: Separate CI job with retry capability. Use `xcodebuild test -retry-tests-on-failure -test-iterations 2` (Xcode 15+).

**Risk: Xcode version compatibility**
- Mitigation: Pin Xcode version in CI (already done: `XCODE_VERSION: "16.2"`). UITest bundle format is stable across Xcode versions.

---

## Future Considerations

1. **ViewInspector as complement (not replacement):** Add ViewInspector for view-level unit tests that don't need a running app. These live in the SPM test target alongside existing unit tests. Good for testing: custom view modifiers, conditional rendering, design system components.

2. **Xcode Cloud:** If the team moves to Xcode Cloud for distribution, the `.xcodeproj` becomes the primary build system and the "minimal xcodeproj" naturally evolves into a full project. This is a forward-compatible choice.

3. **Accessibility Audit Tests:** With a UITest target available, add `XCUIApplication().performAccessibilityAudit()` (Xcode 15+) tests to catch accessibility regressions automatically.

---

## Action Items

| # | Task | Owner | Effort |
|---|---|---|---|
| 1 | Create minimal `.xcodeproj` with UITest bundle target | Rusty | 1-2h |
| 2 | Verify all 31 tests pass on simulator | Livingston | 1h |
| 3 | Add `uitest` subcommand to `scripts/build.sh` | Basher | 30min |
| 4 | Add `ui-test` job to `.github/workflows/ci.yml` | Basher | 30min |
| 5 | Update `.gitignore` for xcodeproj user data | Any | 5min |
| 6 | Update UITests README to remove "not yet runnable" caveat | Livingston | 5min |

**Total effort: ~3-4 hours**

### From: tess-wellness-design-plan.md

# Tess Decision Inbox: Wellness-Themed Visual Redesign Plan

**Author:** Tess — UI/UX Designer  
**Requested by:** Yashasg  
**Status:** Proposed — design review requested before implementation  
**Scope:** Design system, color palette, typography, iconography, motion, and screen-level visual direction  
**Do not implement yet:** This is a planning artifact for review.

## 1. Current design snapshot

Current UI is structurally accessible but visually plain:

- `DesignSystem.swift` is tokenized, but the palette is utility-first: blue for eyes, green for posture, orange/yellow for warnings.
- Typography uses system Dynamic Type tokens, which is accessible and performant, but not distinctive or wellness-oriented.
- Spacing follows a clean 4pt grid (`xs=4`, `sm=8`, `md=16`, `lg=24`, `xl=32`).
- Main patterns are standard SwiftUI `Form`, `.regularMaterial` cards, bordered prominent buttons, and SF Symbols.
- `HomeView` is visually minimal and may be dead/phase-2 code per prior Tess audit; post-onboarding root currently centers on Settings.
- `OverlayView` has strong accessibility and reduce-motion behavior, but visually reads as a generic modal timer rather than a restorative eye-rest moment.
- Onboarding now uses design tokens consistently, but its hero visuals are still icon-only and low-emotion.

## 2. Research summary

### Wellness / eye-rest visual themes

Recommended direction: **Restful Grove** — soft sage, deep teal, warm sand, gentle sky blue, and muted clay/coral.

Research themes to apply:

- Avoid pure white as the dominant background; use warm off-white or soft sand to reduce glare.
- Use low-saturation greens and blue-greens for calm, health, rest, nature, and eye comfort.
- Keep high-contrast dark text for accessibility rather than using pale green text on light backgrounds.
- Use color + icon + label, never color alone, for reminder type and status.
- Use dark mode colors that are darker, less saturated, and not pure black to avoid harsh contrast bloom.

### Accessibility constraints

WCAG AA minimums to preserve:

- Normal text: **4.5:1** contrast.
- Large text: **3:1** contrast.
- Meaningful icons, controls, focus indicators, and graphical UI affordances: **3:1** contrast.

The proposed palette below was selected around those thresholds. Soft colors should primarily be used as backgrounds/fills; text and icon foregrounds need stronger companion tones.

## 3. Proposed palette

### Light mode

| Role | Hex | Usage | Contrast notes |
|---|---:|---|---|
| App background / warm canvas | `#F8F4EC` | Root screens, grouped-form backdrop | Softer than white; reduces glare |
| Surface | `#FFFDF8` | Cards, settings rows, onboarding cards | Warm paper surface |
| Surface tint | `#EEF6F1` | Quiet status blocks, selected states | Sage wash, not text |
| Primary / Restful Sage | `#2F6F5E` | Primary CTA, active status, eye-rest icon foreground | 5.81:1 on surface; white text on it 5.91:1 |
| Secondary / Gentle Blue | `#286C8E` | Posture or secondary info, links where needed | 5.70:1 on surface; white text 5.79:1 |
| Accent / Soft Clay | `#9E4F39` | Warm highlights, destructive-adjacent but non-alarm emphasis | 5.69:1 on surface; white text 5.78:1 |
| Text primary | `#22352D` | Body/headline text | 11.85:1 on background |
| Text secondary | `#5F6F67` | Captions, helper text | 4.84:1 on background |
| Border / Divider | `#D8E4DC` | Card borders, subtle separators | Use sparingly |
| Warning text | keep current `#994F00` or tune to `#8A4A00` | Permission/snooze warning text | Must remain AA on warm background |

### Dark mode

| Role | Hex | Usage | Contrast notes |
|---|---:|---|---|
| App background | `#101714` | Root screens | Softer green-black, not pure black |
| Surface | `#18221E` | Cards, forms | Layer 1 |
| Surface elevated / tint | `#203128` | Raised cards, active panels | Layer 2 |
| Primary / Restful Sage | `#8ED2B1` | Primary foreground, button fill with dark text | 10.4:1 on background; dark text on it 10.4:1 |
| Secondary / Gentle Blue | `#8DBFE4` | Secondary foreground / posture tone | 9.27:1 on background |
| Accent / Soft Clay | `#F0B79B` | Warm highlights | 10.35:1 on background |
| Text primary | `#EEF7F1` | Body/headline text | 16.64:1 on background |
| Text secondary | `#B9C8BF` | Captions/helper text | 10.46:1 on background |
| Border / Divider | `#314039` | Separators | Visible without harshness |
| Warning text | keep current dark `#FF9500` or soften only if contrast remains AA | Permission/snooze warning | Current value is accessible |

### Token changes to consider

Add semantic tokens beyond the current reminder-only palette:

- `AppColor.background`
- `AppColor.surface`
- `AppColor.surfaceTint`
- `AppColor.primaryRest`
- `AppColor.secondaryCalm`
- `AppColor.accentWarm`
- `AppColor.textPrimary`
- `AppColor.textSecondary`
- `AppColor.separatorSoft`

Keep `ReminderType.color` semantic, but remap it into the new palette:

- Eyes: primary restful sage / teal, not saturated blue.
- Posture: gentle blue or muted leaf green, depending on final visual hierarchy.

## 4. Font recommendations

All recommendations are free for commercial use and available under the SIL Open Font License through Google Fonts.

### Option A — **Nunito** / **Nunito Sans**

**Best wellness fit.** Rounded, friendly, approachable, calm.

Pros:
- Soft rounded shapes make the app feel less clinical.
- Good for onboarding and reminder overlays.
- Pairs naturally with nature/wellness palette.

Cons:
- Can feel slightly informal if overused in dense Settings rows.
- Needs careful weight selection; avoid overly bubbly bold weights.

Recommended use:
- Headlines: Nunito SemiBold/Bold.
- Body: Nunito Regular/SemiBold or system fallback if custom-body readability is a concern.

### Option B — **DM Sans**

**Best balanced UI option.** Clean, modern, calm, highly readable.

Pros:
- Excellent for settings-heavy UI.
- More polished and less playful than Nunito.
- Works well at small sizes.

Cons:
- Less emotionally distinctive; may need illustrations/colors to carry the wellness feel.

Recommended use:
- Whole-app font if we want one family.
- Preferred if implementation wants the least risk.

### Option C — **Plus Jakarta Sans**

**Best premium/product feel.** Warm geometric sans with strong UI readability.

Pros:
- Feels modern and high-quality.
- Good middle ground between friendly and professional.

Cons:
- Slightly more geometric/tech-forward than wellness-forward.
- May feel less “soft” than Nunito.

### Tess recommendation

Use **DM Sans as the safest full-app font**, or **Nunito for headings + DM Sans/system for body** if the team accepts a two-font approach. If custom font bundling is considered too much for this release, keep San Francisco and instead improve personality through palette, illustration, cards, and motion.

Implementation constraint: preserve Dynamic Type by wrapping custom fonts with scalable text-style tokens (e.g. `UIFontMetrics`) rather than fixed sizes.

## 5. Spacing, radius, and elevation system

Keep the existing 4pt grid and add a little more expressiveness:

| Token | Value | Use |
|---|---:|---|
| `xs` | 4 | Micro gaps |
| `sm` | 8 | Icon-label gaps |
| `md` | 16 | Standard card padding |
| `lg` | 24 | Section spacing |
| `xl` | 32 | Screen hero spacing |
| `xxl` | 40 | Onboarding/overlay hero breathing room |

Corner radii:

| Token | Value | Use |
|---|---:|---|
| `radiusSmall` | 12 | Small chips / compact cards |
| `radiusCard` | 20 | Settings cards, preview cards |
| `radiusLarge` | 28 | Hero cards / overlay panels |
| `radiusPill` | 999 | Primary buttons, status pills |

Elevation:

- Prefer subtle borders and tinted fills over heavy shadows.
- Light mode card shadow: very soft green/gray at ~8–12% opacity.
- Dark mode: no bright shadows; use border and surface layering.

## 6. Iconography / illustration direction

Use SF Symbols for implementation consistency, but make them feel intentional:

- Prefer **hierarchical rendering** for large symbols in hero states.
- Use **outline or medium-weight symbols** for settings rows; reserve filled symbols for active status and CTAs.
- Use circular/rounded tinted symbol containers (`surfaceTint`) for settings and setup cards.
- Avoid mixing raw symbol strings; continue `AppSymbol` token pattern.
- Potential wellness symbols to evaluate for iOS 16 availability: eye, leaf, wind, sun/horizon, figure stand, moon/zzz, timer, bell, sparkles. Validate before implementation.
- Illustration style: abstract “soft scene” compositions made from SF Symbols and shapes — no dependency on paid illustration assets.

## 7. Motion and micro-interactions

Calming, not gamified:

- Overlay entrance: soft fade + 2–4% scale/slide, slower ease-out than current utilitarian slide.
- Countdown ring: gentle progress stroke with rounded caps; no urgent ticking animation.
- Primary buttons: subtle pressed scale (`0.98`) and optional gentle haptic.
- Onboarding: fade/slide between content blocks; keep current reduce-motion guard pattern.
- Status changes: crossfade icon + text; avoid progress bars that create timer anxiety.
- Respect `accessibilityReduceMotion` everywhere: use direct state changes or opacity only.

## 8. Screen-level redesign plan

### Home / landing state

Current: centered icon + title + status. Clean but sparse and not informative.

After:
- Warm sand background.
- Large “restful status” hero card with soft sage gradient/tint.
- Calm status pill: “Reminders active” / “Paused”.
- Optional simple reassurance copy: “We’ll nudge you gently when it’s time to rest your eyes.”
- Settings remains a top-right gear, but visually softer.
- Avoid detailed elapsed-time progress bars to preserve passive-nudge positioning.

Note: If `HomeView` remains dead code, use this as a Phase 2 dashboard proposal rather than immediate implementation.

### Settings

Current: plain SwiftUI `Form` with tokenized rows.

After:
- Warm background using `AppColor.background`; hide default harsh form background where feasible.
- Group rows into soft cards with `surface` background, `radiusCard`, and subtle border.
- Add tinted icon containers for Eye Breaks, Posture, Snooze, Smart Pause, Notifications, Legal/About.
- Use primary sage for primary toggles; secondary blue for posture-related symbols.
- Keep native controls for accessibility, but improve hierarchy through section headers, helper text, and card surfaces.
- Permission warning becomes warm clay/amber card rather than default warning row.

### Overlay

Current: full-screen blur/material, icon, headline, countdown ring, settings button.

After:
- Treat as a “rest moment,” not an alert.
- Background: soft material + restful gradient/tint (`background` → `surfaceTint`) adapting to dark mode.
- Large symbol inside a soft circular aura; eye reminder could show eye + subtle leaf/sun motif.
- Countdown ring uses primary sage/blue with muted track, with calm headline copy.
- Add a small supportive line under headline (if product approves): “Look away and soften your focus.” / “Roll your shoulders and reset.”
- Dismiss remains available and 44pt+; settings link remains low prominence.
- Preserve VoiceOver countdown label and UIKit modal accessibility behavior.

### Onboarding

Current: accessible, clear, icon/card based, but generic.

After:
- Three screens feel like a guided wellness setup:
  1. Welcome: abstract paired eye/posture illustration in a soft rounded hero card.
  2. Permission: notification preview card on warm surface with reassuring color treatment.
  3. Setup: two soft reminder cards with icon containers and friendly copy.
- Use consistent page background, cards, and primary CTA style.
- Progress dots can remain native but should be checked against new palette.
- CTA buttons become pill-shaped with sage primary fill.

## 9. Before / after summary

| Screen | Before | After |
|---|---|---|
| Home | Plain centered icon/title/status | Warm wellness dashboard card with calm status and breathable hierarchy |
| Settings | Default form, mostly system chrome | Soft grouped cards, tinted icons, warmer background, clearer hierarchy |
| Overlay | Functional timer modal | Restful full-screen pause moment with calming palette, aura/ring, supportive tone |
| Onboarding | Clear but generic tokenized setup | Joyful guided setup with soft illustrations, warm cards, and wellness personality |

## 10. Implementation phases

### Phase 1 — Design token expansion

- Add asset-catalog colors for background/surface/text/accent in light + dark mode.
- Add radius and optional elevation tokens to `DesignSystem.swift`.
- Decide font path: DM Sans, Nunito, Plus Jakarta Sans, or stay with SF.
- Verify all color pairs with WCAG AA before use.

### Phase 2 — Component styling

- Introduce reusable card/status-pill/button styles if Linus agrees.
- Apply soft backgrounds and icon containers to onboarding/setup cards.
- Style Settings sections with warm surfaces while preserving native accessibility.

### Phase 3 — Overlay emotional redesign

- Redesign overlay visual composition and countdown ring treatment.
- Add calming micro-interactions behind reduce-motion guards.
- Validate VoiceOver and Dynamic Type with large accessibility sizes.

### Phase 4 — QA and polish

- Test light/dark mode, high contrast/increase contrast, reduce motion, VoiceOver, Dynamic Type.
- Snapshot key screens if possible.
- Confirm no raw colors/fonts/symbol strings bypass design tokens.

## 11. Acceptance criteria

- App has a coherent wellness visual identity across onboarding, settings, overlay, and any home/dashboard screen.
- All new colors are semantic `AppColor` tokens backed by asset catalog variants.
- All normal text meets WCAG AA 4.5:1; large text/icons/components meet at least 3:1.
- Dynamic Type remains intact for all text styles.
- Reduce Motion is respected for all new animation/micro-interaction work.
- No paid/commercially restricted fonts or assets are introduced.
- SF Symbols remain tokenized via `AppSymbol`.
- Dark mode feels designed, not auto-inverted.

## 12. Open questions for team review

1. Should we adopt a custom font now, or keep San Francisco for v1 and revisit after visual tokens land?
2. Should eye and posture reminders remain two distinct colors, or should both live under a unified sage/teal wellness palette with icon differences?
3. Is a Phase 2 Home/dashboard screen in scope, given prior audit notes that `HomeView` may be dead code?
4. Can Danny approve adding one short supportive overlay line, or should the redesign stay purely visual for now?

---

# Decision: Yin-Yang Shape Drawn with SwiftUI Path (not SF Symbols)

**Author:** Tess (UI/UX)  
**Date:** 2025-07-22  
**Status:** Implemented

## Context

The original `YinYangEyeView` used SF Symbol eye icons orbiting around a circle. The approved HTML prototype specified a proper yin-yang symbol drawn as vector paths.

## Decision

- The yin-yang is now drawn entirely with SwiftUI `Path` arcs — no SF Symbols, no images.
- `YinYangHalfShape` is a reusable private `Shape` conformance producing each half.
- Colors use existing design tokens only (`AppColor.primaryRest`, `AppColor.surfaceTint`, `AppColor.separatorSoft`).
- Animation is two-phase: spin then breathe. Reduce-motion disables both.
- `WelcomeHeroCard` in onboarding was replaced by the same `YinYangEyeView()` component — single source of truth for the logo.

## Impact

- **HomeView** — no changes needed, already uses `YinYangEyeView()`.
- **OnboardingWelcomeView** — now uses `YinYangEyeView()` instead of `WelcomeHeroCard`.
- **Tests** — `home.statusIcon` accessibility identifier preserved. Dead `HeroIcon`/`WelcomeHeroCard` structs removed.

---

# Decision: Home Yin-Yang Eye Animation

**Author:** Tess  
**Date:** 2026-04-26  
**Status:** Implemented  
**Branch:** feature/restful-grove

## Context

Yashasg requested a Home screen animation based on a yin-yang concept: one open eye and one closed eye come together, rotate around each other briefly, then stop. The animation may later become the app logo, but the immediate scope is HomeView.

## Decision

Implement a self-contained `YinYangEyeView` and place it in HomeView's hero/status area above the title and status copy.

Design choices:
- Use SF Symbols `eye.fill` and `eye.slash.fill` for stronger visual weight at hero size.
- Use `AppColor.primaryRest` for the open eye and `AppColor.secondaryCalm` for the closed eye.
- Use a soft `AppColor.surfaceTint` circular field with two subtle tinted inner circles so the resting pose reads as a simplified yin-yang mark.
- Animate once on appear for 1.35 seconds with `.easeInOut`, with no bounce or looping.
- Start the symbols apart, pull them inward while rotating around the center, and settle vertically as a quiet logo-like composition.
- Respect Reduce Motion by rendering the final settled state immediately.

## Consequences

- HomeView now has a calmer branded hero moment while keeping the existing title and active/paused status copy.
- The old status icon no longer changes between active and paused; the status text remains the state indicator.
- The animation is isolated in `YinYangEyeView`, making future extraction into an app-logo component straightforward.
- Existing UI test identifiers remain available, including `home.statusIcon`.

## Validation

- Build passed with `xcodebuild build -scheme EyePostureReminder -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`.
- Tests passed with `xcodebuild test -scheme EyePostureReminder -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`.

---

# Decision: Yin-Yang Logo Animation — Roadmap Placement & Documentation

**Date:** 2026-04-26  
**Author:** Danny (Product Manager)  
**Status:** Approved  
**Related Issues:** #158–#169 (Restful Grove redesign)

## Decision

The yin-yang logo animation is classified as a **Phase 2 (Polish) milestone (M2.10)**, not Phase 3, because it is part of the Restful Grove visual redesign — a branding/polish effort, not an advanced feature.

## Key Design Choices Documented

1. **Custom SwiftUI `Path`** over SF Symbols — unique brand identity, precise color control
2. **Colors:** Sage (`#2F6F5E` / `AppColor.primaryRest`) + Mint (`#EEF6F1` / `AppColor.surfaceTint`) — Restful Grove palette
3. **Animation:** Spin once (360°, 2s deceleration) → Breathing pulse (4s in, 4s out, infinite)
4. **Reduce Motion:** Static logo, no animation — WCAG AA compliance
5. **Placement:** `HomeView` and `OnboardingView`

## Artifacts Updated

- `ROADMAP.md` — M2.10 milestone, timeline, dependency map, key decisions, final status
- `UX_FLOWS.md` — §5.4 animation flow description

## Team Impact

- Tess owns implementation (SwiftUI Path + animation)
- Linus may assist with integration into existing views
- No architecture changes required — purely additive UI work

---

# Decision: YinYangEyeView Architecture — Custom Path + Phase-Based Animation

**Author:** Rusty (iOS Architect)  
**Date:** 2026-04-27  
**Status:** Documented

## Decision

`YinYangEyeView` uses custom SwiftUI `Shape` / `Path` drawing (not SF Symbols or image assets) with a two-phase animation state machine (Spin → Breathe). This is now the established pattern for custom branded visual components in the app.

## Rationale

1. **Custom Path over assets:** Resolution-independent, direct design-token integration (`AppColor.primaryRest`, `AppColor.surfaceTint`), and per-layer animation control.
2. **Two-phase state machine:** SwiftUI lacks native animation chaining. The `@State` + `DispatchQueue.main.asyncAfter` pattern sequences spin → breathe cleanly.
3. **Reduce-motion compliance:** All animated views must check `@Environment(\.accessibilityReduceMotion)` and skip to static state — consistent with the CalmingEntrance pattern.

## Impact

- ARCHITECTURE.md §4.8 now documents this pattern.
- Any future custom animated branding components should follow the same Shape + phase-based approach.
- No new design tokens were introduced; fully composed from existing Restful Grove tokens.

---

# Decision: App Name Candidates

**Author:** Roman (Market Researcher)  
**Date:** 2026-04-27  
**Status:** Proposed — awaiting team review

## Summary

Researched 13 name candidates for the app (currently "Eye & Posture Reminder"). Top 3 recommendation:

1. **Restwell** — strongest all-around. Warm, memorable, brandable, aligns with Restful Grove aesthetic.
2. **Softsight** — most premium feel. Distinctive, elegant, uncontested.
3. **Respite** — most sophisticated. Real English word meaning exactly what the app delivers.

## Action Needed

- Danny: visual/aesthetic fit check with Restful Grove design
- Yashas: final name preference
- Frank: formal trademark search on chosen name before App Store submission

## Full Research

See `docs/app-naming-research.md` for all 13 candidates, scoring matrix, and ASO strategy.

---

# Decision: English Name Candidates Research

**Author:** Roman (Market Researcher)  
**Date:** 2026-04-27  
**Status:** Research phase

## Context

Initial naming exploration across 13 English-language concepts to replace "Eye & Posture Reminder" with a memorable, brandable single word.

## Findings

- **Restwell** — strongest candidate: warm, memorable, perfectly aligned with Restful Grove aesthetic
- **Softsight** — distinctive, premium feel, unique positioning
- **Respite** — sophisticated, dictionary-backed meaning, but competes with existing app

## Full Analysis

See `docs/app-naming-research.md` for complete research.

---

# Decision: Respite Name Availability Assessment

**Author:** Roman (Market Researcher)  
**Date:** 2026-04-27  
**Status:** Research phase

## Key Finding

"Respite: Reduce Screen Time" is a live iOS app in the wellness category. Creates brand confusion but not a dealbreaker.

## Conflicts Identified

- respiteapp.com domain taken (caregiver service)
- Narrow trademark protection (dictionary word)
- Existing competing app with poor maintenance signal

## Alternatives

- Restwell: zero conflicts across all channels
- Alternative domains (getrespite.com) available

## Full Report

See `docs/respite-name-availability.md`.

---

# Decision: Classical Name Candidates for App

**Author:** Roman (Market Researcher)  
**Date:** 2026-04-27  
**Status:** Research phase

## Context

After Respite conflicts emerged, explored Greek, Latin, and Roman vocabulary for classical-language alternatives.

## Top 5 Candidates (All App Store Clean)

1. **Lenis** (Latin: "gentle") — short, brandable, intuitive
2. **Requies** (Latin: "rest") — direct Respite replacement, no conflicts
3. **Galene** (Greek: goddess of calm seas) — poetic, strong visual alignment
4. **Placida** (Latin: "peaceful") — warm, place-like quality
5. **Levamen** (Latin: "relief") — most descriptive, clear meaning

## Key Insights

- Latin outperforms Greek for brandability (shorter, English cognates)
- All verified zero App Store conflicts
- "Otium" (leisure) philosophically perfect but has direct competitor app (disqualified)

## Full Analysis

See `docs/app-naming-classical.md`.

---

# Decision: Synonym Translation Naming Round

**Author:** Roman (Market Researcher)  
**Date:** 2026-04-27  
**Status:** Research phase

## Context

Fourth research pass — translated 14 English wellness concepts across Greek, Latin, and Sanskrit for comprehensive naming landscape.

## New Strong Candidates

- **Anesis** (Greek: "relief/relaxation") — elegant, completely clean, delivers the core value
- **Nimesha** (Sanskrit: "blink/moment") — poetic, strong yin-yang resonance
- **Mollis** (Latin: "soft/tender") — sounds like its meaning, short, clean

## Key Insight

"Gentle/soft" semantic space is the richest naming vein across all three languages. Watch/guard words are heavily contested on App Store — avoided this space.

## Full Analysis

See `docs/app-naming-synonyms.md`.

---

# Decision: Sanskrit Name Candidates for App

**Author:** Roman (Market Researcher)  
**Date:** 2026-04-27  
**Status:** Research phase

## Context

Explored 18 Sanskrit candidates emphasizing yin-yang visual alignment and Eastern philosophy cohesion.

## Top 5 Candidates

1. **Samata** (balance/equanimity) — strongest yin-yang alignment, easy pronunciation, clean App Store
2. **Netra** (eye/guide) — directly relevant, short, easy pronunciation, low risk
3. **Taraka** (pupil/star/crossing) — beautiful triple meaning, easy pronunciation, clean App Store
4. **Achala** (stillness/immovable) — strong posture association, easy pronunciation, clean
5. **Drishti** (sight/gaze) — yoga-recognized, but trademark issues emerged

## Key Insight

Sanskrit names create stronger brand coherence with yin-yang logo and Eastern philosophy aesthetic. Popular wellness words (Shanti, Prana, etc.) are heavily contested — avoided.

## Full Analysis

See `docs/app-naming-sanskrit.md`.

---

# Decision: Final Name Availability Check — Kshana Selected

**Author:** Roman (Market Researcher)  
**Date:** 2026-04-27  
**Status:** FINAL DECISION

## Context

Exhaustive availability audit on two Sanskrit finalists: Drishti and Kshana.

## Evaluation

### Drishti — NO-GO

- **Trademark blocker:** Drishti Technologies Inc. (Palo Alto) holds live USPTO registration (Class 9/42)
- drishti.com and drishtiapp.com both taken by active businesses
- Drishti Learning App has 1M+ downloads — would dominate App Store search
- Cultural sensitivity: "evil eye" connotation in South Asian cultures

### Kshana — APPROVED ✅

- No App Store conflicts on any platform
- No USPTO trademark registration
- Social handles available (@kshanaapp, @getkshana)
- No cultural sensitivity issues
- Cleanest availability landscape of all names evaluated across four research rounds

## Recommendation

**Kshana (क्षण — "a moment, an instant") is the final selected app name.**

**App Store listing:** `Kshana — Eye & Posture Breaks`

**Branding:** All lowercase (kshana) where the team controls presentation. App Store may auto-capitalize.

## Next Steps

1. ✅ Completed by Linus: App name and UI strings updated to kshana
2. ✅ Completed by Danny: Documentation and README updated for kshana branding
3. Register domains: kshanaapp.com, getkshana.com
4. Claim social handles: @kshanaapp on Twitter/X, Instagram, TikTok
5. File USPTO trademark in Class 9
6. Attorney consult for due diligence vs. Kshana AI (fintech, different sector)

## Full Report

See `docs/app-naming-final-check.md` for complete head-to-head analysis.

---

# Decision: App Name Finalized — Kshana

**Author:** Yashas (User)  
**Date:** 2026-04-27  
**Status:** FINAL

## User Directive

App name is officially **kshana** (all lowercase). Sanskrit for "a moment, an instant."

Branding should use lowercase everywhere the team controls (logo, website, in-app strings, marketing). The App Store may auto-capitalize per its policies.

## Rationale

User decision made after 4 rounds of comprehensive naming research:
- Round 1: 13 English candidates (Restwell, Softsight, Respite)
- Round 2: Respite availability assessment + alternatives
- Round 3: 18 classical language candidates (Greek, Latin, Roman)
- Round 4: 14 synonym translations + Sanskrit deep dive
- Round 5: Final availability check (Drishti vs. Kshana)

**Key decisive factor:** Kshana had the cleanest App Store landscape of all finalists — zero conflicts, no trademark issues, open social handles, no cultural sensitivities.

## Impact

- Linus to update app bundle name, UI strings, onboarding to reflect kshana
- Danny to update all documentation and website references
- All marketing and branding materials should use lowercase "kshana"
- Post-launch: register domains and social handles, file trademark

---

# Decision: App Rename — "Eye & Posture Reminder" → "kshana"

**Author:** Linus (iOS Dev — UI)
**Date:** 2026-05-16
**Status:** Implemented

## Context

Yashas requested a codebase-wide rename from "Eye & Posture Reminder" to **kshana** (all lowercase in branding).

## Decision

- **Brand name:** "kshana" (all lowercase) in all user-facing strings.
- **Code identifiers:** `EyePostureReminder` SPM target/module name is intentionally preserved — renaming it would break all imports and should be a separate PR.
- **CFBundleName:** Hardcoded to `"kshana"` in Info.plist, decoupling display name from module name.
- **Subtitle for App Store:** "kshana — Eye & Posture Wellness" (to be used in metadata, not yet wired into the app itself).

## Files Changed

- `EyePostureReminder/Resources/Localizable.xcstrings` — 6 string values updated
- `EyePostureReminder/Info.plist` — CFBundleName + 3 usage descriptions
- `Tests/EyePostureReminderTests/Views/StringCatalogTests.swift` — test assertion updated
- `.swiftlint.yml` — header comment
- 8 Swift source files — file header comments

## Risks

- `CFBundleName` is now hardcoded. If a future PR renames the SPM target to `Kshana`, `CFBundleName` can revert to `$(PRODUCT_NAME)`.
- Legal text references "kshana" — ensure legal review if the name changes again.

---

# Decision: Apple Developer — Certificates, Identifiers & Profiles Setup

**Author:** Rusty  
**Date:** 2026-04-26  
**Status:** Guidance provided  
**Session:** 2026-04-28T22:46:23Z (Rusty + Virgil parallel sprint)

## Context

Yashasg has Apple Developer account working and is setting up Certificates, Identifiers & Profiles for TestFlight/App Store submission. Critical step before archive and distribution workflows.

## Decisions

1. **Bundle ID:** `com.yashasg.eyeposturereminder` — matches APP_STORE_LISTING.md and codebase references.
   - **Note:** Case mismatch detected in UITests/project.yml (`com.yashasg.EyePostureReminder`). Must align before archive.

2. **Capabilities to register:** Push Notifications + Focus Status Reading. No Background Modes, App Groups, or HealthKit needed.

3. **Certificate type:** Apple Distribution (covers both TestFlight and App Store). No separate Ad Hoc needed if using TestFlight only.

4. **Provisioning:** Use Xcode Automatic Signing for development. For distribution, create an App Store provisioning profile tied to the distribution certificate.

5. **Xcode project:** Since the app is SPM-only (no .xcodeproj), Yashasg will need to open Package.swift in Xcode, which creates an implicit project, or create an .xcodeproj for archive/upload workflows.

## GitHub Secrets (per Virgil)

Standard CI/CD secret names for App Store Connect:
- `ASC_API_KEY_ID` — API Key ID from App Store Connect
- `ASC_API_KEY_ISSUER_ID` — Issuer ID from App Store Connect  
- `ASC_API_KEY_P8` — Private key file (.p8) contents

## Who needs to know

- **Danny:** Bundle ID and app name are locked — no changes without re-registering. Case mismatch in UITests must be resolved.
- **All:** Distribution certificate is team-scoped; if CI is added later, it needs the same cert/profile.
- **Virgil:** Ensure CI/CD workflows reference final unified Bundle ID once UITests is corrected.

---

# Decision: LogoYangMint — logo-scoped color token for the yin-yang yang half

**Author:** Linus  
**Date:** 2026-04-28

## Decision
Added `AppColor.logoYangMint` (`LogoYangMint` color asset) as a **logo-only** token.  
- Light: `#50C4A4` — saturated mint, visible against sage and cream background  
- Dark: `#2A6A52` — mid-green, 3.7:1 contrast vs `primaryRest` dark `#8ED2B1`

## Rationale
`AppColor.surfaceTint` is used as a surface/panel background in SettingsView, OnboardingView, and other screens. Globally changing it to a more saturated colour would have broken those surfaces. A logo-scoped token avoids this regression entirely.

## Scope
`YinYangEyeView` only. The comment in DesignSystem.swift explicitly marks it as logo-only.

## App Icon
Light and dark icon PNGs regenerated using the same palette. Dark variants registered via `appearances` entries in `AppIcon.appiconset/Contents.json` — iOS 18+ automatic theming, no extra icon set name required.

---

# Design Direction: Adaptive Yin-Yang Logo Contrast + App Icon Variants

**Author:** Tess (UI/UX Designer)  
**Date:** 2026-04-28  
**Status:** Implemented

---

## Problem

The yin-yang logo (`YinYangEyeView`) uses `AppColor.surfaceTint` for the "yang" (mint) half. `surfaceTint` was designed as a *surface wash* for card backgrounds — not a filled logo element. The result:

- **Light mode:** `#EEF6F1` (near-white pale green) on `#F8F4EC` (warm off-white background) → contrast ratio ~1.01:1 — effectively invisible.
- **Dark mode:** `#203128` (near-black dark sage) on `#101714` (deep forest background) → contrast ratio ~1.37:1 — barely distinguishable.

The `primaryRest` yin half is fine in both modes and should not change.

---

## Root Cause

`AppColor.surfaceTint` is the right token for card tint backgrounds (pale wash). It is the wrong token for a logo fill. Changing `surfaceTint` broadly would break card surfaces — this is a logo-specific fix.

---

## Recommended Fix: New `logoMint` Color Token

Introduce **`AppColor.logoMint`** (or a private logo-local color in `YinYangEyeView`) with these values:

| Appearance | Hex | Role | Contrast on background |
|---|---|---|---|
| Light | `#3CA882` | Bright mint-teal, yang half | ~3.6:1 on `#F8F4EC` ✅ WCAG 1.4.11 |
| Dark | `#446E58` | Mid sage-green, yang half | ~3.8:1 on `#101714` ✅ WCAG 1.4.11 |

Visual rationale:
- **Light mode `#3CA882`:** A proper mid-tone mint. Clearly reads as mint, visually contrasts with the dark yin half (`#2F6F5E` forest green). Remains on-brand Restful Grove palette.
- **Dark mode `#446E58`:** A mid-depth sage. Contrasts the bright yin half (`#8ED2B1` light mint). Remains visibly brand-green without washing into the background.

**Do NOT change `AppColor.surfaceTint`** — it is correctly `#EEF6F1`/`#203128` for card surface washes.

### Implementation path for Linus

**Option A (preferred — clean token):**
1. Add `RGLogoMint.colorset` to `Colors.xcassets` with light `#3CA882`, dark `#446E58`
2. Add `static let logoMint = Color("RGLogoMint", bundle: .module)` to `AppColor` in `DesignSystem.swift`
3. In `YinYangEyeView.swift`, replace all uses of `AppColor.surfaceTint` with `AppColor.logoMint`

**Option B (local, no new token):**
Add a private adaptive color directly in `YinYangEyeView.swift` using `UIColor(dynamicProvider:)` — acceptable if the team prefers not to add a token used in only one view.

---

## App Icon: Light/Dark Appearance Variants

**Current state:** `AppIcon.appiconset/Contents.json` has a single set of PNG images — no dark variant. The icon always shows the light-background version regardless of system appearance.

**iOS 18 / Xcode 16 support:** Automatic dark/tinted icon variants are supported by adding a dark-appearance image entry in `Contents.json`. The system automatically shows the appropriate variant based on the user's appearance setting (Settings → Display & Brightness → App Icons on iOS 18).

**Direction for Linus / Virgil:**
1. Design a **dark-background icon variant**: swap the icon background from warm forest green to near-black (`#101714`), use the logo with boosted mint and sage contrast (values above apply). The yin half should use `#8ED2B1` (or brighter), the yang half `#3CA882`.
2. In `AppIcon.appiconset/Contents.json`, add dark appearance entries:
```json
{
  "filename": "AppIcon-Dark-1024.png",
  "idiom": "ios-marketing",
  "scale": "1x",
  "size": "1024x1024",
  "appearances": [
    { "appearance": "luminosity", "value": "dark" }
  ]
}
```
3. Repeat for all required sizes.
4. This requires iOS 18+ — below iOS 18 the system ignores the dark entry and falls back to the universal icon. No degradation.

---

# Decision: Detect Missing Provisioning Profiles Before Archive

**Date:** 2026-04  
**Author:** Virgil (CI/CD Dev)  
**Status:** Implemented

## Problem

Running `./scripts/build_signed.sh export` failed at the archive step with:

```
No Accounts: Add a new account in Accounts settings.
No profiles for 'com.yashasg.eyeposturereminder' were found:
  Xcode couldn't find any iOS App Development provisioning profiles
  matching 'com.yashasg.eyeposturereminder'.
```

This occurred even after the developer logged into Xcode. Root cause: **0 provisioning profiles existed in `~/Library/MobileDevice/Provisioning Profiles/`**. The Apple Distribution certificate was present in the Keychain, but `xcodebuild` requires profiles to be physically downloaded before it can use automatic signing — even with `-allowProvisioningUpdates`.

Logging into Xcode is necessary but not sufficient. "Download Manual Profiles" must also be triggered.

## Decision

Add early detection in `cmd_doctor` and `cmd_archive` in `scripts/build_signed.sh`:

1. Check `~/Library/MobileDevice/Provisioning Profiles/` for any `.mobileprovision` files matching the bundle ID via `grep -rl`.
2. If none found, emit a `warn` with the exact remediation steps (Xcode → Settings → Accounts → team → "Download Manual Profiles").
3. In `cmd_archive`, emit the same warning pre-flight so developers see it before xcodebuild starts and produces a cryptic error.

## Remediation Steps for Developers

When you see "No Accounts" or "No profiles found" from `xcodebuild`:

1. Open Xcode
2. `⌘,` → Accounts
3. Select your Apple ID → select your team
4. Click **"Download Manual Profiles"** and wait for it to finish
5. Confirm `com.yashasg.eyeposturereminder` is registered at [developer.apple.com → Identifiers](https://developer.apple.com/account/resources/identifiers/list)
6. Re-run `./scripts/build_signed.sh doctor` — should show profiles found
7. Re-run `./scripts/build_signed.sh export`

## Why Not Automate Profile Download?

`xcodebuild` with `-allowProvisioningUpdates` *would* download profiles — but only if the Apple ID session is already established. When there are zero profiles and xcodebuild has no active session (even after GUI login), it errors immediately before even attempting the download. This is an Xcode session bootstrap issue that must be resolved through the GUI once.

---

# Decision: Automatic Signing Must Not Override CODE_SIGN_IDENTITY

**Date:** 2026-04-28  
**Author:** Virgil (CI/CD)  
**Status:** Implemented

## Problem

`scripts/build_signed.sh` was passing both `CODE_SIGN_STYLE=Automatic` and
`CODE_SIGN_IDENTITY=Apple Distribution` to xcodebuild during `archive`. Xcode
exit-65 error: _"EyePostureReminder is automatically signed for development, but
a conflicting code signing identity Apple Distribution has been manually
specified."_ The same conflict appeared on SPM sub-targets.

## Decision

**Do not inject `CODE_SIGN_IDENTITY` into xcodebuild build settings when using
automatic signing.** Only inject it in manual signing mode (`SIGNING_STYLE=manual`).

Rationale:
- With `CODE_SIGN_STYLE=Automatic`, Xcode owns certificate selection for each
  build action. For `archive`, it automatically chooses an Apple Distribution
  identity if one is present in the Keychain. No override is needed or allowed.
- Specifying `CODE_SIGN_IDENTITY` alongside automatic signing instructs Xcode to
  use a specific cert while also telling it to manage certs automatically. These
  two instructions are mutually exclusive; Xcode treats it as a conflict and fails.
- The distribution identity (`Apple Distribution`) for export/upload belongs in
  `ExportOptions.plist` (`signingCertificate` key), not in the archive build
  settings command line. The two phases — archive and export — are separate and
  have different signing concerns.

## Pattern

```bash
build_signing_build_settings() {
  local style_value
  if [[ "$SIGNING_STYLE" == "manual" ]]; then style_value="Manual"; else style_value="Automatic"; fi

  SIGNING_BUILD_SETTINGS=(
    "DEVELOPMENT_TEAM=${APPLE_TEAM_ID}"
    "CODE_SIGN_STYLE=${style_value}"
    "CODE_SIGNING_ALLOWED=YES"
    "CODE_SIGNING_REQUIRED=YES"
    # ... other flags
  )

  # Only override CODE_SIGN_IDENTITY for manual signing.
  # Automatic signing selects the identity; overriding causes exit 65.
  if [[ "$SIGNING_STYLE" == "manual" ]]; then
    SIGNING_BUILD_SETTINGS+=("CODE_SIGN_IDENTITY=${SIGNING_CERTIFICATE}")
  fi
}
```

`ExportOptions.plist` (written by `create_export_options`) continues to include
`signingCertificate: Apple Distribution` — that is the correct place to declare
the distribution identity for the export/upload step.

## Applies To

- `scripts/build_signed.sh`
- Any future CI workflow that calls `xcodebuild archive` with automatic signing

---

# Decision: build_signed.sh — Fix empty-array nounset crash (macOS Bash 3.2)

**Date:** 2026-04-28  
**Author:** Virgil  
**Status:** Implemented

## Context

`scripts/build_signed.sh` uses `set -euo pipefail`. On macOS, `/usr/bin/env bash` resolves to Bash **3.2.57** (the Apple-shipped version). Under `nounset` (`-u`), expanding an empty indexed array with `"${array[@]}"` throws:

```
scripts/build_signed.sh: line 400: AUTH_FLAGS[@]: unbound variable
```

This was triggered on the `archive` command when no App Store Connect API key vars were set (`AUTH_FLAGS` remained an empty array) and `ALLOW_PROVISIONING_UPDATES` was `YES` (so `PROVISIONING_FLAGS` had one element — but the same pattern would crash on an empty `PROVISIONING_FLAGS` too).

## Decision

Replace all three array expansions (`PROVISIONING_FLAGS`, `AUTH_FLAGS`, `SIGNING_BUILD_SETTINGS`) across all `xcodebuild` calls with the `${var+word}` guard pattern:

```bash
# Before
"${AUTH_FLAGS[@]}"

# After
"${AUTH_FLAGS[@]+"${AUTH_FLAGS[@]}"}"
```

**Why this pattern:** `${var+word}` substitutes `word` only when `var` is set. For an empty array, the outer substitution short-circuits and produces nothing, so the inner `${AUTH_FLAGS[@]}` is never evaluated and nounset cannot trigger. When the array is non-empty, both substitutions expand normally and all elements are passed correctly to xcodebuild.

## Alternatives Considered

| Option | Reason rejected |
|---|---|
| `set +u` around xcodebuild calls | Turns off nounset for those lines — unsafe, masks other bugs |
| `[[ ${#AUTH_FLAGS[@]} -gt 0 ]] && args+=...` | Verbose; requires duplicating the xcodebuild call |
| Upgrade to Bash 5 via Homebrew | Adds an implicit dependency; system Bash 3.2 is the common denominator |
| `${AUTH_FLAGS[@]:-}` | Does NOT fix the problem on Bash 3.2 arrays |

## Post-fix Status

- `bash -n scripts/build_signed.sh` ✅ syntax OK  
- `./scripts/build_signed.sh doctor` ✅ passes  
- `bash scripts/build_signed.sh archive` ✅ passes the array expansion; then fails on a **pre-existing, unrelated** Xcode signing conflict:  
  `conflicting provisioning settings — automatically signed for development but Apple Distribution identity specified`  
  This is a separate issue not caused by this fix.

## No Secrets Policy

Diff contains no Team IDs, profile UUIDs, API key values, certificate hashes, or email addresses. All signing values continue to flow exclusively through environment variables.

---

# Decision: Provisioning Failure Guidance Pattern

**Author:** Virgil  
**Date:** 2026-04-27  
**Status:** Implemented

## Context

`bash scripts/build_signed.sh export` reaches `xcodebuild archive` and fails with one of two errors:
- *"No Accounts: Add a new account in Accounts settings"* — automatic signing, no Xcode account or ASC API key present
- *"No profiles for canonical app bundle ID were found"* — manual signing (default), no matching App Store Connect Distribution profile installed locally

Both errors cause the script to exit via `set -e` with no actionable guidance printed to the user.

## Decision

1. **Redact sensitive values from xcodebuild output** via the existing `redact_stream` Perl filter, which already handles Team ID, profile specifier, and ASC key values. Merge stderr into stdout (`2>&1`) before the pipe so both streams are filtered.

2. **Wrap the archive `run_xcodebuild` call** with `if ! run_xcodebuild ...; then print_archive_failure_hint; exit 1; fi`. The `if !` construct prevents `set -e` from firing before guidance can print.

3. **`print_archive_failure_hint` explains both failure modes inline:**
   - Automatic signing → add Xcode account or supply `ASC_AUTH_KEY_PATH` / `ASC_AUTH_KEY_ID` / `ASC_AUTH_ISSUER_ID`
   - Manual signing → create/install App Store Connect Distribution profile or set `PROVISIONING_PROFILE_SPECIFIER`
   - Reminder that Transporter / `upload` require a successful `export` first

4. **README Troubleshooting table** maps common xcodebuild error messages to fixes — reducing support burden for developers new to the signing workflow.

## Rationale

- The `ensure_manual_distribution_profile` guard catches the manual-signing case before xcodebuild runs, but only when no profile is installed at all. If a profile name is set/guessed but xcodebuild cannot resolve it, xcodebuild fails with no prior warning.
- For automatic signing failures ("No Accounts"), there is no pre-flight check — the error can only surface from xcodebuild.
- In-band guidance (printed by the script at the point of failure) is far more discoverable than README-only documentation.

## Consequences

- No secrets policy change: all guidance is generic, never printing actual Team ID, profile UUID, or key values.
- `set -e` remains active globally; only the specific `run_xcodebuild` call is wrapped in a conditional.
- `redact_stream` already merges stderr, so no structural change to the redaction mechanism.

---

# Decision: Keychain Auto-Detection for APPLE_TEAM_ID in build_signed.sh

**Author:** Virgil  
**Date:** 2026-04-28  
**Status:** Implemented  

## Context

`scripts/build_signed.sh` required `APPLE_TEAM_ID` to be set explicitly for every archive/export/upload invocation. On a local macOS machine with a single Apple Distribution certificate installed, this was friction — the Team ID is already implicit in the Keychain cert.

## Decision

Implement automatic Team ID detection from the local macOS Keychain as a convenience fallback, with the following rules:

1. **Explicit env var always wins.** `APPLE_TEAM_ID` (or `DEVELOPMENT_TEAM`) set in the environment is never overridden.
2. **Single-cert auto-detection.** If `security find-identity -p codesigning -v` returns Apple Distribution identities containing exactly one unique Team ID (10-char alphanumeric), that value is used silently. Doctor prints "detected from Keychain" — not the value itself.
3. **Ambiguous Keychain fails loudly.** If multiple Team IDs are found, archive/export/upload fail with a message instructing the user to set `APPLE_TEAM_ID` explicitly.
4. **Empty Keychain fails with guidance.** No change from prior behavior; failure message now mentions Keychain cert installation as an alternative to explicit env var.
5. **No ASC API key extraction from Keychain.** App Store Connect auth keys are not looked up from Keychain — only certificate-based Team ID detection is added.
6. **Provisioning profiles stay out of scope.** Profiles are handled by Xcode automatic signing (default) or `PROVISIONING_PROFILE_SPECIFIER` env var — not Keychain lookup.

## Rationale

- Reduces friction for solo/local workflows where only one distribution cert is present.
- Does not compromise CI/CD: CI always sets `APPLE_TEAM_ID` explicitly; auto-detection is never reachable.
- No sensitive value is ever printed or logged — "detected from Keychain" is the only output.
- Consistent with Apple toolchain conventions: `security find-identity` is the canonical way to enumerate code-signing identities.

## Implementation

- `infer_team_id_from_keychain()` added to `scripts/build_signed.sh` helpers section.
- Called once at startup when `APPLE_TEAM_ID` is empty.
- `require_team_id()` updated to distinguish ambiguous vs. not-found cases.
- `cmd_doctor()` updated to display detection source without revealing the value.
- `README.md` "Signed TestFlight builds" section updated with auto-detection note and provisioning profile clarification.

---

# Decision: Signed Build Parity — build_signed.sh vs build.sh

**Filed by:** Virgil  
**Date:** 2026-04-28  
**Status:** Implemented

## Context

`build_signed.sh` and `build.sh` share the same core build step pattern
(SPM package → app-wrapper → xcodebuild) but the signed script had three
concrete divergences that were not signing-related.

## Decisions Made

### 1. Build number injection belongs in build_signed.sh, patching the archive

- **Decision:** `inject_build_number()` patches `<archive>.xcarchive/Products/Applications/<App>.app/Info.plist` *after* a successful `xcodebuild archive`.
- **Rationale:** Avoids mutating source `Info.plist` (no dirty working tree; safe for local ad-hoc builds). CI passes `BUILD_NUMBER=${{ github.run_number }}`; local builds fall back to a timestamp.
- **NOT chosen:** Patching source `Info.plist` before archive (used by the old `testflight.yml`). That approach leaves a modified file in the working tree and risks accidental commits.

### 2. testflight.yml must call build_signed.sh, not raw xcodebuild

- **Decision:** Replace the raw `xcodebuild archive` + `xcodebuild -exportArchive` steps in `testflight.yml` with `./scripts/build_signed.sh upload`.
- **Rationale:** SPM `.executable` targets cannot be archived for iOS distribution without a `.xcodeproj` app-wrapper. `build_signed.sh` generates that wrapper via XcodeGen. Calling raw xcodebuild without `-project` on a pure SPM repo would always fail.
- **Required additions:** `brew install xcodegen` step in the workflow; `ASC_AUTH_KEY_PATH`, `ASC_AUTH_KEY_ID`, `ASC_AUTH_ISSUER_ID` env vars passed to match `build_signed.sh` interface.

### 3. Canonical bundle ID is all-lowercase

- **Decision:** `com.yashasg.eyeposturereminder` is the canonical bundle ID across all project files and scripts.
- **Rationale:** Confirmed by Rusty (Wave 13). Bundle IDs are case-sensitive in Apple systems. `UITests/project.yml` was the only outlier; corrected.

## Interface Contract for build_signed.sh

| Env var | Required? | Notes |
|---|---|---|
| `APPLE_TEAM_ID` | Auto-detected from Keychain if unset | |
| `BUILD_NUMBER` | Optional | Defaults to `YYYYMMDDHHmm` timestamp |
| `ASC_AUTH_KEY_PATH` | Required for upload | Must be an absolute path outside the repo |
| `ASC_AUTH_KEY_ID` | Required for upload | |
| `ASC_AUTH_ISSUER_ID` | Required for upload | |
| `APP_BUNDLE_ID` | Optional | Defaults to `com.yashasg.eyeposturereminder` |

---

# User Directive: TestFlight iPhone-only App

**By:** yashasg  
**Date:** 2026-04-28  
**Status:** Guidance  

## Directive

kshana does not support iPad at the moment; signed TestFlight builds should remain iPhone-only.

## Context

User request — captured for team memory.


---

# User Directive: Screen-relevant copy (2026-04-28)

**By:** yashasg (via Copilot CLI)  
**Date:** 2026-04-28T20:00:03Z  
**Status:** Guidance

## Directive

Screen copy should be relevant to the screen itself; avoid introducing unrelated feature details such as snooze copy on non-snooze screens.

## Context

User request — captured for team memory.

---

# Decision: Remove snooze references from notification copy on non-snooze screens

**Author:** Danny (Product Manager)  
**Date:** 2026-04-28  
**Status:** Implemented (commit: dd6a2fd)

## Decision

Three copy strings in `EyePostureReminder/Resources/Localizable.xcstrings` have been updated to remove snooze/resume language and use schedule-focused replacements:

| Key | Previous | Updated |
|-----|----------|---------|
| `onboarding.permission.body1` | "Notifications let your breaks resume on time after a snooze." | "Notifications keep your break reminders on schedule." |
| `settings.notifications.disabledBody` | "Turn on notifications in Settings so breaks resume after a snooze." | "Turn on notifications in Settings so break reminders stay on schedule." |
| `settings.notifications.disabledLabel` | "Notifications are off. Turn them on in Settings so breaks resume after a snooze." | "Notifications are off. Turn them on in Settings so break reminders stay on schedule." |

## Rationale

The onboarding permission screen appears early in the UX flow before snooze has been introduced. Mentioning snooze at this stage is contextually inappropriate. The permission screen should explain *why* notifications matter (they power break reminders), not describe a specific feature the user hasn't encountered yet.

The same principle applies to the settings notification-disabled banners — they should explain the impact on break reminders, not reference snooze-specific behavior.

## Not Changed

- All `settings.snooze.*` and `settings.section.snooze` keys — snooze language is correct and expected on snooze-specific screens
- `settings.reset.body` mentioning "clears your snooze history" — correct in context

## Implementation

Applied by Linus. JSON validation passed. Build validated.

---

# Decision: manageAppVersionAndBuildNumber during export

**Date:** 2026-04-28  
**Author:** Virgil  
**Status:** Observed — recommend explicit opt-out for CI predictability

## Observation

`xcodebuild -exportArchive` for the `app-store-connect` method defaults to
`manageAppVersionAndBuildNumber=true`. During a local `export` run this wave,
Xcode:
1. Connected to App Store Connect  
2. Found build `1` already submitted for version `0.2.0`  
3. Auto-assigned `CFBundleVersion = 2` in the exported IPA  

This silently overrides `inject_build_number()` (which had set `202604282122`
in the archive). The IPA's final `CFBundleVersion = 2` is correct and valid.

## Recommendation

For **local exports** (non-CI): current behavior is fine. Xcode manages the
number automatically when an Apple ID with App Store Connect access is present.

For **CI uploads** (no interactive Apple ID): `manageAppVersionAndBuildNumber`
should be explicitly set to `false` in `ExportOptions.plist`, and
`inject_build_number()` / `BUILD_NUMBER` env var should own the number. This
avoids CI needing App Store Connect query credentials just for the export step.

## Suggested change (optional, non-blocking)

Add to `create_export_options()` in `build_signed.sh`:

```bash
/usr/libexec/PlistBuddy -c "Add :manageVersionAndBuildNumber bool NO" "$EXPORT_OPTIONS_PLIST"
```

This makes build number injection deterministic regardless of Xcode account
state on the runner, and aligns the archive and IPA `CFBundleVersion` values.

---

# Decision Inbox: Background Reminder Capability Gap

**Author:** Basher (iOS Dev — Services)  
**Date:** 2026-04-28  
**Status:** NEEDS TEAM DECISION  
**Priority:** P0 — Core product promise broken

---

## Context

The app's stated purpose is reminders **while using other apps** (eye breaks, posture checks). An architectural change in a prior sprint moved the reminder trigger from `UNTimeIntervalNotificationTrigger` periodic scheduling to `ScreenTimeTracker` — an in-process 1-second tick timer that only runs while the app is `UIApplication.applicationState == .active`.

`AppCoordinator.scheduleReminders()` now explicitly calls `scheduler.cancelAllReminders()` at every entry point, removing all periodic `UNNotification` requests from the system queue. `ReminderScheduler.rescheduleReminder(for:using:)` is marked "Superseded — never called in production."

## The Problem

**The ScreenTimeTracker cannot run in the background.** iOS suspends the app process and the `Timer` tick stops. When the app goes to the background:
1. `willResignActiveNotification` fires → tick timer stops → 5-second grace period starts → all counters reset to zero.
2. No periodic `UNNotification` is scheduled to take over.
3. No `BGTaskScheduler` background task is registered.
4. **Result: zero reminders fire while the user is using another app.**

## What Does Work Today

- **In-app only:** ScreenTimeTracker fires the overlay correctly while the user stays inside the app.
- **Snooze-wake:** One-time silent `UNTimeIntervalNotificationTrigger` is correctly scheduled as a background wake mechanism for the snooze-expiry path.
- **Notification delivery plumbing:** `AppDelegate.willPresent` and `didReceive` handlers exist and correctly route to `coordinator.handleNotification(for:)` → `OverlayManager.showOverlay()`. This wiring is complete and correct — it will work immediately if notifications are re-enabled.
- **Overlay tap-from-background:** `pendingOverlay` stash + `presentPendingOverlayIfNeeded()` handles the scene-activation race correctly.

## iOS Platform Reality

- `UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: true)` fires while the app is backgrounded or killed — this is the standard approach for reminder apps. Requires `interval >= 60`; OS silently rejects shorter intervals (already handled: `repeats: interval >= 60` in `ReminderScheduler`).
- iOS limit: 64 pending `UNNotificationRequest`s per app. With 2 types (eyes, posture), 1 request each with `repeats: true`, this cap is irrelevant.
- There is no iOS API for "count seconds of screen-on time while backgrounded." ScreenTimeTracker cannot be extended to cover background operation.
- Background execution modes (`BGTaskScheduler`, background audio, location) are all inappropriate for a wellness reminder app.

## Required Decisions

### Decision 1 (BLOCKING): Re-enable periodic UNNotification scheduling
The `ReminderScheduler` already has the correct implementation. `AppCoordinator.scheduleReminders()` must call `scheduler.scheduleReminders(using: settings)` (or `rescheduleReminder(for:using:)` per type) instead of `scheduler.cancelAllReminders()`.

**Coordination needed:** When `ScreenTimeTracker` fires the overlay in-app, cancel and immediately reschedule the notification for that type to avoid a duplicate system banner arriving while the overlay is visible. `AppDelegate.willPresent` already suppresses the banner (`completionHandler([])`), but the trigger fires and creates the next delivery point — resetting it on overlay fire keeps timing accurate.

### Decision 2: Hybrid trigger model
Run both `ScreenTimeTracker` (foreground, for instant overlay without requiring the user to tap a banner) and `UNNotification` periodic scheduling (background, for delivery while user is in another app) simultaneously. On notification delivery while in-foreground, `AppDelegate.willPresent` suppresses the banner and fires the overlay — this already works.

### Decision 3: Onboarding — denied permission recovery path
`OnboardingPermissionView` calls `onNext()` after the system prompt regardless of outcome. A denied user sees no recovery path in onboarding. `SettingsView` does have a "Open Settings" button (behind a warning row), and the overlay gear icon sets `openSettingsOnLaunch=true` which routes there. **This is functional but indirect.** Consider adding a conditional "Go to Settings" button in `OnboardingPermissionView` if permission was denied.

Note: since ScreenTimeTracker works regardless of notification auth status, denied-permission users still get in-app reminders. The gap is background delivery only, making Decision 1 + 2 the priority.

## Affected Files

- `EyePostureReminder/Services/AppCoordinator.swift` — remove `cancelAllReminders()` safety net, add `scheduler.scheduleReminders(using:)` call
- `EyePostureReminder/Services/ReminderScheduler.swift` — un-supersede `rescheduleReminder(for:using:)`, call from production
- `EyePostureReminder/Views/Onboarding/OnboardingPermissionView.swift` — optional: denied-permission recovery path

# Decision: Restore Hybrid Trigger Model for Background Reminders

**Author:** Basher (iOS Dev — Services)  
**Date:** 2026-04-28  
**Status:** Implemented (commit aa7be3e)  
**Resolves:** P0 — zero reminders delivered while user is in another app

---

## Problem

`AppCoordinator.scheduleReminders()` called `scheduler.cancelAllReminders()` and configured only `ScreenTimeTracker`. `ScreenTimeTracker` is a 1-second foreground `Timer` that pauses on `willResignActiveNotification`; it cannot run in the background. Result: no reminders ever fired in other apps.

## Decision

**Restore the hybrid trigger model:** periodic `UNNotificationRequest` (background) + `ScreenTimeTracker` (foreground precision). Neither replaces the other.

### Rule 1 — Background notifications gate on auth status
- `scheduleReminders()` calls `scheduler.scheduleReminders(using: settings)` when `notificationAuthStatus == .authorized`.
- When denied, it calls `cancelAllReminders()` to clean up stale entries.
- ScreenTimeTracker remains active regardless of auth — users without notification permission still get foreground overlays.

### Rule 2 — Foreground threshold resets the background notification
When `ScreenTimeTracker.onThresholdReached` fires for a type, after showing the overlay, `AppCoordinator` spawns a Task to call `scheduler.rescheduleReminder(for: type, using: settings)`. This resets the background notification's interval from the moment of the foreground trigger, keeping the two paths synchronized and preventing a near-simultaneous double-banner when the user immediately switches to another app.

### Rule 3 — Notification delivery resets the foreground counter
`handleNotification(for:)` (called from both `willPresent` and `didReceive`) calls `screenTimeTracker.reset(for: type)` after showing/queuing the overlay. This prevents the foreground timer from re-firing immediately after a notification-triggered overlay.

### Rule 4 — Per-type reschedule maintains both paths
`performReschedule(for:)` now calls `scheduler.rescheduleReminder(for:using:)` for enabled types (when authorized) and `scheduler.cancelReminder(for:)` for disabled types. Both paths also update `ScreenTimeTracker` as before.

### Rule 5 — Snooze guard is unchanged
The existing early-return in `scheduleReminders()` for active snooze prevents scheduling in both the ScreenTimeTracker and notification paths. Snooze-wake notification and in-process Task remain intact.

## iOS Constraints
- `UNTimeIntervalNotificationTrigger(repeats: true)` requires `timeInterval >= 60`. The dynamic `repeats: interval >= 60` guard in `ReminderScheduler` satisfies this; the newly added 1-minute test interval is valid.
- No background modes, `BGTaskScheduler`, or `UIBackgroundTaskIdentifier` are needed for this pattern.

## Impact
- Users with notification permission now receive reminders cross-app (banner → tap → overlay or no-tap → overlay on next app open).
- Users without permission receive foreground-only reminders as before (no regression).
- All 33 `AppCoordinatorTests` pass. Full unit suite clean.

# Decision: Reminder Permission Screen Copy — "Alert" not "Overlay"

**Date:** 2026-04-28  
**Author:** Linus (iOS Dev UI)  
**Status:** Adopted

## Context

A platform audit confirmed: iOS has no permission for drawing over other apps (TikTok, Safari, etc.). kshana's cross-app interruption mechanism is exclusively via local notifications (alert banners). Tapping the banner opens kshana and presents the full-screen break overlay.

The previous onboarding permission screen copy ("Reminders keep your breaks on schedule." / "No spam — just your breaks, right on schedule.") did not explain this mechanic, leaving users potentially confused about what they were consenting to.

## Decision

**Use "reminder alerts" language in onboarding.** Never imply a cross-app overlay or system-level interruption beyond standard iOS notification alerts.

### Adopted copy pattern for `OnboardingPermissionView`:

| Key | Value |
|-----|-------|
| `onboarding.permission.body1` | "Your reminders arrive as alerts — even while you're in another app." |
| `onboarding.permission.body2` | "Tap any alert to open your full-screen break in kshana." |
| `onboarding.permission.enableButton` | "Allow Reminder Alerts" |
| `onboarding.permission.enableButton.hint` | "Allows kshana to send reminder alerts while you use other apps" |

## Rules Going Forward

1. **Never use "overlay" when describing cross-app behavior** — that's only valid for the in-app full-screen break view.
2. **Use "reminder alerts" or "reminders"** in all user-facing copy; reserve "notification" for describing the iOS system prompt itself (where the platform term is unavoidable).
3. **Denied-permission route** is handled by `SettingsView` (`settings.notifications.disabledTitle` banner with `openSettings` deep-link). Do not build a parallel flow in onboarding.
4. **Accessibility identifier `"onboarding.enableNotifications"`** is kept stable for UI test stability; do not rename it.

## Files Changed

- `EyePostureReminder/Resources/Localizable.xcstrings`
- `Tests/EyePostureReminderUITests/OnboardingFlowTests.swift`

# Decision: Background Reminder Scheduling — Regression Test Contract

**Author:** Livingston (Tester)
**Date:** 2026-04-28
**Status:** Active

## Context

P0: background reminders were disabled because `AppCoordinator.scheduleReminders()` used
ScreenTimeTracker exclusively (foreground-only). Basher restored a hybrid trigger model:
periodic `UNNotificationRequest` scheduling (background) + ScreenTimeTracker (foreground
precision supplement). Linus updated permission-screen and settings copy to use "Reminders"
language.

## Decision

Lock in the restored scheduling path with dedicated regression tests rather than relying
on code review alone.

## Test Contracts Established

### 1. AppCoordinator background scheduling path
`AppCoordinatorTests` — `MARK: Background Scheduling Regression (P0)`

- `scheduleReminders()` with `notificationAuthStatus == .authorized` and enabled types
  MUST add periodic `UNNotificationRequest` objects to the notification center.
- Disabling a type (eyes/posture/global) MUST result in zero periodic requests for that type.
- All periodic requests MUST use `UNTimeIntervalNotificationTrigger` with `repeats == true`.

These tests fail if anyone removes `scheduler.scheduleReminders(using:settings)` from the
authorized branch of `AppCoordinator.scheduleReminders()`.

### 2. ReminderScheduler 60-second boundary
`ReminderSchedulerTests` — `MARK: Background Scheduling Regression (P0)`

- A 60-second interval MUST produce `repeats: true` (system minimum for repeating triggers).
- Scheduled requests MUST use `UNTimeIntervalNotificationTrigger`.
- Disabling a type after scheduling MUST remove it from the pending queue.
- Every scheduled request MUST have a non-empty identifier.

### 3. Copy regression — reminder language
`StringCatalogTests` — `MARK: Permission Copy Regression (P0 + Linus copy pass)`

- Permission screen "enable" button MUST contain "Reminder", MUST NOT contain "Notification".
- `body1` MUST reference "Reminder"; `body2` MUST NOT reference "overlay".
- Notification content keys (title + body, both types) MUST resolve to non-empty strings.
- Settings disabled-banner MUST use "Reminder" language.

## Rationale

The P0 was silent — no test caught the removal of periodic scheduling. These tests create
an explicit, named contract so the failure mode is immediately visible if the scheduling
path is touched again.

## Related Commits
- `dc42ad3` — `test: add background reminder scheduling regression coverage (P0)`

# Decision: iOS Overlay Feasibility — Reminder Delivery Must Use Local Notifications

**Author:** Rusty (iOS Architect)  
**Date:** 2026-04-28  
**Status:** Requires immediate product + engineering resolution  
**Priority:** CRITICAL — current code does not fulfil the app's core purpose

---

## The Problem

The user's core expectation is: **"reminders appear while I'm in TikTok, Safari, Instagram — not while I'm staring at kshana."**

The current code cannot deliver that. This is not a bug to fix — it is an iOS platform wall.

---

## 1. Can a normal App Store iOS app display a full-screen overlay over other apps?

**No. Hard no. Full stop.**

iOS has a strict process isolation model. Every app runs in its own sandbox. There is no API, no permission dialog, no Settings toggle, and no entitlement available to regular App Store developers that lets you draw custom UI over another app.

The only exceptions are:
- **Accessibility services** (requires Apple approval + Special Entitlement — not granted via App Store, requires MFi/enterprise process)
- **Screen Time / Parental Controls** (OS-level, Apple-internal only)
- **MDM/DEP** — enterprise device management, not App Store
- **Picture-in-Picture** — only for video content, not arbitrary SwiftUI

There is no "permission settings page" for this. It does not exist in iOS. An app claiming to show overlays over other apps in the App Store will be rejected under Guideline 2.5.1 (undocumented/private APIs) or simply cannot achieve it with any public API.

---

## 2. What CAN kshana do while the user is in another app?

| Mechanism | Works in background? | Can interrupt user in TikTok? | Notes |
|---|---|---|---|
| **Local Notifications** (`UNUserNotificationCenter`) | ✅ Yes | ✅ Yes — banner + sound | User must tap to return to app |
| **Time-Sensitive Notifications** (iOS 15+) | ✅ Yes | ✅ Breaks through Focus Mode | Requires `com.apple.developer.usernotifications.time-sensitive` entitlement + App Review justification |
| **Critical Alerts** | ✅ Yes | ✅ Breaks through silent mode | Requires special Apple approval — NOT appropriate here |
| **Live Activities** | ✅ Yes (Dynamic Island/lock screen) | Passive only | No interaction, just ambient info |
| **Widgets** | ✅ Yes | Passive only | Lock screen / home screen ambient |
| **Background App Refresh** | ✅ Limited | ❌ No UI allowed | Can pre-compute but can't alert |
| **Custom UIWindow overlay** (current code) | ❌ Only foreground | ❌ No | This is what kshana currently does |

**The answer for kshana's use case: Local Notifications.** That's the only App Store-legal mechanism to interrupt a user who is actively using another app.

---

## 3. What does the current code actually implement?

### `ScreenTimeTracker.swift`
- Runs a 1-second `Timer` that ticks **only while kshana is the foreground-active app** (`UIApplication.didBecomeActiveNotification` → start; `willResignActiveNotification` → stop + grace period)
- When the user is in TikTok, this timer is **stopped**. No time accumulates. No callback ever fires.
- **Verdict:** Correctly measures time *while kshana is open*. Useless for cross-app reminders.

### `OverlayManager.swift`
- Creates a `UIWindow` at `windowLevel = .alert + 1` and presents `OverlayView` via `UIHostingController`
- This window is **inside kshana's process**. It covers kshana's own UI. It cannot reach over another app.
- The `windowScene` lookup requires `.foregroundActive` — it explicitly requires kshana to be the active scene
- **Verdict:** A perfectly fine in-app full-screen overlay. Completely useless when user is in TikTok.

### `ReminderScheduler.swift`
- Has `scheduleReminders(using:)` / `rescheduleReminder(for:using:)` which DO schedule `UNNotificationRequest` objects — the right mechanism for cross-app delivery
- **Critical problem:** These methods are explicitly commented as **"never called in production"** and **"superseded"** by `ScreenTimeTracker`
- `AppCoordinator.scheduleReminders()` calls `scheduler.cancelAllReminders()` then configures `ScreenTimeTracker` — notifications are actively cancelled, never rescheduled
- **Verdict:** The one correct cross-app mechanism was intentionally disabled.

### `AppCoordinator.swift`
- Trigger model comment: *"Reminders fire after CONTINUOUS screen-on time... ScreenTimeTracker increments per-type counters while the app is active"*
- `handleNotification(for:)` exists for background notification taps → shows overlay when app is opened. This is the correct *tap-to-open* path. But no notification is ever scheduled to trigger it.
- **Verdict:** The notification-tap path (`handleNotification`) is wired correctly. The notification scheduling that would feed it is dead.

### `OnboardingPermissionView.swift`
- Shows a notification permission card that looks exactly like an iOS system notification banner
- The visual mock + copy correctly implies "you'll get a notification banner"
- But since no notifications are ever scheduled (only ScreenTimeTracker), the permission request is for a feature that is currently broken
- **Verdict:** The onboarding correctly sets user expectation (notification banner → tap → app opens). The backend does not honour it.

### Copy audit — problematic strings:
| Key | Current value | Problem? |
|---|---|---|
| `onboarding.welcome.body` | "Runs quietly — you'll barely notice it." | Implies background operation — NOT delivered by current code |
| `onboarding.permission.body1` | "Reminders keep your breaks on schedule." | Fine if notifications work |
| `settings.reminder.section.footer` | "The timer resets when you lock your phone." | Correct — but users expect reminders while in other apps, not just after locking |

---

## 4. What product/architecture path should we take?

### The correct iOS model for this app:

**Notification-first with foreground precision refinement.**

**Step 1 (Unblocks the product):** Re-enable `UNNotificationRequest` scheduling as the primary cross-app delivery mechanism.
- `AppCoordinator.scheduleReminders()` should call `scheduler.scheduleReminders(using:)` instead of `cancelAllReminders()`
- Remove the "superseded" comments and dead-code guard on `ReminderScheduler`
- This makes the app work: user is in TikTok, notification fires, user taps, kshana opens, overlay shows

**Step 2 (The honest screen-time story):** `UNTimeIntervalNotificationTrigger` fires on wall-clock intervals (every 20 min regardless of whether the user was actually looking at their phone). `ScreenTimeTracker` gives you actual eyes-on-screen time, but only while kshana is in the foreground.

Hybrid approach options:
- **Simple (recommend first):** Wall-clock interval notifications. Honest in copy: "every 20 minutes while your phone is in use." Works everywhere. Ship it.
- **Screen-time aware (Phase 2):** When kshana backgrounds, cancel the existing notification and schedule a new one for `(interval - elapsed)` seconds from now. When kshana foregrounds, cancel the notification and restart ScreenTimeTracker. This preserves the screen-time accuracy. More complex but achievable.

**Step 3 (Copy alignment):** Update `onboarding.welcome.body` if needed to set expectation as "you'll get a notification tap" not "invisible overlay appears over TikTok."

---

## 5. Exact files that need changes

| File | Problem | Required change |
|---|---|---|
| `Services/AppCoordinator.swift` | Calls `scheduler.cancelAllReminders()` instead of scheduling; ScreenTimeTracker is the only trigger | Reinstate `scheduler.scheduleReminders(using:)` call; decide on hybrid vs wall-clock model |
| `Services/ReminderScheduler.swift` | `scheduleReminders()` / `rescheduleReminder()` marked "never called in production" | Remove dead-code comments; wire these methods back into production path |
| `Services/ScreenTimeTracker.swift` | Stops when app backgrounds — never fires cross-app | Keep for foreground precision, but it cannot be the sole trigger |
| `Resources/Localizable.xcstrings` | `onboarding.welcome.body` implies silent background running | Audit against the notification-tap UX model; may need copy update |
| `Views/Onboarding/OnboardingPermissionView.swift` | Shows notification card mock — correct expectation, but backend is broken | No change needed if notifications are re-enabled; verify the round-trip works |

---

## Decision

**Re-enable `UNNotificationRequest` scheduling as the primary cross-app reminder mechanism. ScreenTimeTracker should be a foreground-precision supplement, not the sole trigger path.**

This is a breaking architectural rollback of the "superseded notification scheduling" decision. The previous decision to replace notification scheduling with foreground-only ScreenTimeTracker eliminated the product's core value proposition.

**Immediate action items:**
1. Reinstate notification scheduling in `AppCoordinator.scheduleReminders()`
2. Remove "never called in production" dead-code status from `ReminderScheduler`
3. Validate the notification → tap → overlay round-trip end-to-end
4. Decide in Sprint: wall-clock intervals (simple) vs hybrid screen-time-aware scheduling (complex)

No overlay will ever appear over TikTok. The product is notification-tap-driven. Accept this and build it correctly.

# Decision: Screen Time Shield Path — Corrected Architecture Assessment

**Author:** Rusty (iOS Architect)  
**Date:** 2026-04-28  
**Status:** Architecture assessment — corrects prior incomplete claim  
**Priority:** HIGH — affects product roadmap and MVP scope

---

## What Triggered This

The user pushed back on our prior statement that "normal iOS apps cannot overlay over other apps," citing apps like LookAway. The user is correct that we were incomplete. This document is the corrected, complete assessment.

---

## Prior Statement Was Incomplete — Here Is the Correction

Our prior statement (`rusty-ios-reminder-feasibility.md`) was **technically accurate but materially incomplete**. We said:

> "iOS has a strict process isolation model… There is no API, no permission dialog, no Settings toggle, and no entitlement available to regular App Store developers that lets you draw custom UI over another app."

This is true for *arbitrary custom UI*. What we missed: there IS a system-provided, OS-enforced mechanism that appears over other apps — Apple's **Screen Time Shield** (ManagedSettings + DeviceActivity + FamilyControls). Apps like LookAway use this path.

We were wrong to list "Screen Time / Parental Controls" as "Apple-internal only." Since iOS 16, the FamilyControls framework is available to third-party developers — with approval. Our prior decision omitted this entirely.

---

## Q1: Can kshana implement cross-app interruptions using Screen Time Shield APIs?

**Yes — with significant constraints.**

The mechanism works as follows:

1. `DeviceActivityMonitor` extension is triggered when a configured screen-time threshold is reached (e.g., 20 minutes of use across all apps)
2. The extension calls `ManagedSettingsStore().shield.applicationCategories = .all()` (or specific apps)
3. iOS immediately displays a **system-enforced full-screen shield overlay** — over the *current* app if the user is mid-session in it, or when they try to open any app
4. The user sees the shield until they take a configured action (tap a button, which fires the `ShieldActionExtension`)
5. The action extension can remove the shield, resetting the monitoring cycle

**What appears over other apps:** A system-managed full-screen overlay (not custom SwiftUI). The visual is Apple-controlled — a modal sheet with:
- A system blur/frost glass background (not customizable)
- Your title (customizable, attributed string)
- Your subtitle (customizable)
- Primary button label (customizable text only, not style)
- Optional secondary button label (customizable text only)
- System-provided icon (not fully customizable)

**This is NOT arbitrary "draw over any app" UI.** It is a system-gated shield that iOS controls. You cannot render a full custom OverlayView with your animations, color palette, or brand over another app. You get a system sheet with configurable text.

**Critical timing nuance:** The DeviceActivityMonitor fires on threshold events, not on a continuous timer. It is accurate enough for "after 20 minutes of screen use, interrupt the user," but the exact timing is system-batched (not millisecond-precise). If the user is mid-session in TikTok when the threshold fires, the shield DOES appear over TikTok.

---

## Q2: What capabilities, entitlements, and extension targets are required?

### Entitlement (requires Apple approval)
- **`com.apple.developer.family-controls`** — the FamilyControls entitlement. This is **not granted automatically**. You must request it at [developer.apple.com/contact/request/family-controls-distribution](https://developer.apple.com/contact/request/family-controls-distribution). Apple reviews your stated use case before granting. Without this, the entire Screen Time path is unavailable.

### Frameworks (no special approval, available to all)
- `FamilyControls` — authorization flow
- `DeviceActivity` — monitoring schedules + threshold events
- `ManagedSettings` — applying/removing shields

### Xcode Project Additions Required
| Target | Type | Purpose |
|---|---|---|
| `kshanaDeviceActivityMonitor` | App Extension (DeviceActivityMonitor) | Receives threshold callbacks, applies shields via ManagedSettingsStore |
| `kshanaShieldConfiguration` | App Extension (ShieldConfigurationExtension) | Returns `ShieldConfiguration` (title/subtitle/button labels) to system |
| `kshanaShieldAction` | App Extension (ShieldActionExtension) | Handles button taps — remove shield, resume monitoring |
| App Group | Shared container | State sharing between main app and all three extensions |

### Entitlements file additions
- `com.apple.developer.family-controls`
- App Groups entitlement for shared container

---

## Q3: What user onboarding flow is required?

1. **Authorization request** — must call `AuthorizationCenter.shared.requestAuthorization(for: .individual)`. This presents a **system sheet** (cannot be customized) asking the user to grant Screen Time monitoring to your app. If denied, nothing works.
   - `.individual` mode = monitoring your **own** device (iOS 16+) — this is the self-wellness path
   - `.family` = parental control path (controlling a child's device under Family Sharing) — not applicable for kshana

2. **App/category selection** (optional or automatic) — you can either:
   - Let the user select which apps to monitor via `FamilyActivityPicker` (system sheet, shows app icons)
   - Or automatically shield all app categories (`.all()`) without user selection

3. **Conceptual explanation step** — users need to understand "kshana will pause all apps for a break reminder." This is a bigger UX commitment than a notification banner.

The authorization step alone adds a mandatory new onboarding screen with a system-managed modal. This is non-trivial UX.

---

## Q4: Is this App Store-compliant for a wellness app?

**Likely yes — with caveats — under `.individual` authorization mode.**

Apple added the `.individual` authorization mode specifically in iOS 16 to support self-monitoring apps (not just parental control). This was a deliberate policy expansion.

**What we know:**
- Multiple wellness/productivity apps have shipped using FamilyControls `.individual` (OpalApp, Roots, one-sec, Freedom, etc.)
- Apple's documented purpose: "apps whose primary purpose is to help people manage their own device usage" — this covers an eye break / posture wellness app
- App Review will verify: does the app's onboarding use `.individual` mode, not `.family`? Is the feature genuinely self-wellness?

**Risk factors:**
- Apple's entitlement request process is manual and takes time (typically days to weeks)
- If kshana's primary use case reads as "for parents to manage kids" (it won't — it's clearly a self-wellness app), it could be rejected
- If the app uses `.family` mode or requests permissions beyond its stated scope, rejection is likely

**Verdict:** App Store-compliant for kshana's stated purpose, but entitlement approval is a gating external dependency — not in our control.

---

## Q5: Screen Time Shield vs Local Notifications — MVP vs longer-term?

### Local Notifications (current correct path — MVP ✅)
| | |
|---|---|
| **Entitlement needed** | `com.apple.developer.usernotifications.time-sensitive` (or standard, no special approval) |
| **User approval required** | Notification permission (single system prompt, standard) |
| **Interrupt cross-app** | Yes — banner + sound while user is in TikTok |
| **User action required** | Tap banner to see full overlay |
| **Customizable** | Full custom overlay after tap |
| **Complexity** | LOW — already partially wired in current codebase |
| **App Store risk** | Near zero |
| **Time to ship** | Days |

### Screen Time Shield (longer-term, Phase 3+ 🔮)
| | |
|---|---|
| **Entitlement needed** | FamilyControls — requires Apple approval (external dependency) |
| **User approval required** | Screen Time authorization system sheet + notification permission |
| **Interrupt cross-app** | Yes — full-screen shield appears over current app |
| **User action required** | Tap button on system shield |
| **Customizable** | Title + subtitle + button labels only; no custom SwiftUI |
| **Complexity** | HIGH — 3 new extension targets, App Groups, shared state, new onboarding |
| **App Store risk** | Low–medium (entitlement approval is a dependency) |
| **Time to ship** | Weeks minimum |

**Recommendation:**

- **MVP (now):** Local Notifications, as decided in `rusty-ios-reminder-feasibility.md`. This is the correct call. Reinstating notification scheduling in `AppCoordinator` is the immediate unblock.
- **Phase 3:** Evaluate Screen Time Shield as a premium/opt-in upgrade path. "True interrupt mode" — shield appears over any app. Requires FamilyControls entitlement request as a pre-work step. ONLY pursue if Yashasg decides the product warrants the complexity and external approval dependency.

Local notifications + tap-to-open-overlay is a legitimate, proven UX pattern used by most reminder/wellness apps. It is not a compromise — it is the right tool for the job for MVP.

---

## Q6: What code/project changes are required if we choose Screen Time path?

This is a substantial engineering undertaking. Summary of required changes:

### New Extension Targets (not possible in SPM-only build — requires .xcodeproj)
- `kshanaDeviceActivityMonitor` — app extension target
- `kshanaShieldConfiguration` — app extension target
- `kshanaShieldAction` — app extension target

### New Framework Imports
- `FamilyControls`, `DeviceActivity`, `ManagedSettings` in main app + relevant extensions

### New App Groups Entitlement
- `group.com.yashasg.eyeposturereminder` — required for all extensions to share state with main app

### New Service: `ScreenTimeShieldManager`
- Owns `AuthorizationCenter.shared.requestAuthorization(for: .individual)`
- Defines `DeviceActivitySchedule` + `DeviceActivityEvent` (one event per break interval)
- Calls `ManagedSettingsStore.shield.applicationCategories = .all()` on threshold
- Removes shield after user acknowledges

### `AppCoordinator` changes
- Wire in `ScreenTimeShieldManager` as an opt-in mode alongside notification scheduling
- New `ReminderDeliveryMode` enum: `.notification` vs `.screenTimeShield`

### Onboarding changes
- New mandatory screen: Screen Time authorization request (before or alongside notification permission)
- `FamilyActivityPicker` optional app selection

### Existing code NOT changed
- `OverlayManager` — the UIWindow overlay stays; it is used after the user taps the notification or after the app opens from the shield action
- `ScreenTimeTracker` (our internal tracker) — stays as foreground precision complement

### Note on SPM build
The current project is SPM-only (no .xcodeproj main target). App extension targets CANNOT be added to SPM `Package.swift`. This path **requires** creating an `.xcodeproj` that hosts the three extension targets (a task already partially anticipated given the TestFlight xcodeproj work).

---

## Q7: What to tell the user

**Correction of prior statement:**

We owe a correction. Our prior statement was not wrong, but it was incomplete. We said normal iOS apps cannot overlay over other apps — this is true for arbitrary custom UI. We failed to mention that iOS provides a system-managed "Shield" mechanism via Screen Time APIs that CAN appear over other apps. Apps like LookAway do use this. We should have known and included it.

**The complete picture:**

1. ✅ The Screen Time Shield path is real and available to third-party developers (since iOS 16)
2. ✅ It CAN show a system overlay over the app the user is currently using
3. ⚠️ It is NOT the same as "drawing custom UI over TikTok" — the shield is system-managed with limited text customization (no custom animations, colors, or SwiftUI views)
4. ⚠️ It requires an Apple-approved entitlement (FamilyControls), which is a real external dependency
5. ⚠️ It requires 3 new extension targets and App Groups — substantial engineering lift
6. ✅ For an eye/posture wellness app using `.individual` mode, App Store approval is likely (not guaranteed)

**Recommendation stays:** Local notifications for MVP. Screen Time shield for a future "Pro Interrupt Mode" if the product demands it. The prior architecture decision (`rusty-ios-reminder-feasibility.md`) remains valid in its recommendation — only its claim that the shield path doesn't exist needs to be struck.

---

## Architectural Decision

**The Screen Time Shield path is real, viable, and App-Store-compliant in principle, but is a Phase 3+ feature for kshana.** Local notifications remain the correct MVP mechanism.

If Yashasg wants to pursue Screen Time Shield:
1. File the FamilyControls entitlement request at developer.apple.com immediately (external dependency with no guaranteed timeline)
2. Create the `.xcodeproj` extension target structure
3. Scope a new `ScreenTimeShieldManager` service
4. Add Screen Time authorization to onboarding

**Status of prior decision `rusty-ios-reminder-feasibility.md`:** The recommendations remain correct. The claim "Screen Time / Parental Controls (OS-level, Apple-internal only)" should be struck — it is available to third-party developers with entitlement approval.

# Decision: Interrupt Mode Deep Proof — DeviceActivity + Screen Time Shield

**Author:** Rusty (iOS Architect)  
**Date:** 2026-04-29  
**Status:** Architecture decision — proof/kill investigation. No code changes yet.  
**Priority:** HIGH — product direction decision  
**Context:** Yashasg directive: "local reminders are just noise, useless — look into interrupt mode more, if we can leverage Apple Screen Time API, good, but if the app is just setting screen time then it's a waste."  
**Depends on:** `rusty-screen-time-shield-path.md`, `virgil-screen-time-entitlement-path.md`

---

## Verdict First

**kshana CAN be meaningfully more than a settings/reminder app using Screen Time Shield. The interrupt is real, cross-app, and system-enforced. But the value proposition is earned by how we use the mechanism — not by the mechanism alone.** The architecture is viable. The engineering path is clear. The blocker is an external approval process with Apple.

Local notification work should be **kept as a working fallback, not a product promise**. The product promise is interrupt mode. The notification fallback serves users who don't grant Screen Time permission.

---

## Q1: Can DeviceActivity + ManagedSettings Shield produce recurring break interruptions after selected usage windows?

**Yes — this is the core mechanism and it works.**

The loop looks like this:

```
DeviceActivityCenter.startMonitoring(activity, during: schedule)
  → user hits threshold (e.g. 20 min of cumulative app use)
  → iOS wakes DeviceActivityMonitor extension (background, no app process needed)
  → extension: ManagedSettingsStore().shield.applicationCategories = .all()
  → system-enforced full-screen shield appears over whatever the user is in (TikTok, Instagram, browser)
  → user taps "Start Break" (ShieldAction)
  → ShieldAction extension: removes shield, writes break-start timestamp to App Group
  → after break duration, main app or background task calls DeviceActivityCenter.startMonitoring() again
  → cycle repeats
```

**Critical details:**
- The `DeviceActivitySchedule` defines a time window (e.g., 9am–11pm daily). Inside that window, `DeviceActivityEvent` defines the threshold (e.g., 20 minutes of total app use).
- After the threshold fires, the monitoring session for that schedule is considered complete. **You must restart monitoring** after the break — it does not auto-repeat at the same interval like a repeating timer.
- Restart can be triggered from the ShieldAction extension (via `DeviceActivityCenter` call in the extension) or from the main app when it next foregrounds.
- **Timing reliability caveat:** iOS batches threshold delivery — events are NOT millisecond-precise. Real-world reports (including one-sec developer, 2024) show delays of 30–90 seconds past the threshold, especially after device sleep. Plan for "approximately 20 minutes," not exactly 20 minutes.
- Monitoring the shield-over-app behavior while the user is mid-session: **confirmed working**. If the user is in TikTok when the threshold fires, the shield appears over TikTok immediately. They cannot switch to another app (shield survives app switches) until they dismiss it.

**For eye breaks (20-20-20 rule):** Set threshold to 1200 seconds (20 minutes). The shield fires when the user has accumulated 20 minutes of app usage in the window.

**For posture breaks:** Same mechanism, different threshold and copy.

---

## Q2: Does the user have to select apps/categories up front? What are the restrictions?

**This is the most nuanced question. The answer depends on what you're trying to do.**

### For SHIELDING (blocking apps to trigger the break):

**No picker required.** `ManagedSettingsStore().shield.applicationCategories = .all()` is a direct API call. It shields all app categories system-wide, including social, entertainment, games, utilities — everything except core system functions (Phone app, Emergency calls survive because Apple hard-excludes them).

This means: after the threshold fires, kshana's DeviceActivityMonitor extension can call `.all()` and EVERY app the user might open is shielded. No `FamilyActivityPicker` needed. No user selection ceremony beyond the initial FamilyControls authorization.

### For MONITORING (tracking usage to trigger the threshold):

You also do not need FamilyActivityPicker to monitor total device activity. `DeviceActivityEvent` can be configured against all categories. You're monitoring "total app usage time" in aggregate, not per-app. The user's privacy is protected because you never receive identifiers for specific apps — just that the threshold was crossed.

### What DOES require FamilyActivityPicker:

**Specific app token-level monitoring.** If you want to know "the user spent 20 minutes in social media apps specifically" (not all apps), you need the user to select app tokens via FamilyActivityPicker. This is Apple's privacy gate: specific app identities are protected. Broad category/all monitoring does not require it.

### Summary for kshana's use case:

| Goal | FamilyActivityPicker required? |
|---|---|
| Shield all apps after 20 min total use | ❌ Not required |
| Monitor total device usage (all apps) | ❌ Not required |
| Shield specific apps only (e.g., social media) | ✅ Required for initial app selection |
| Track usage by specific app name | ✅ Required |

**kshana's use case (interrupt after N minutes of total device use, shield everything) does NOT require FamilyActivityPicker.** The only required user action is the initial FamilyControls authorization system sheet.

### Hard restrictions (what cannot be done):

- Core system apps (Phone, Emergency SOS) cannot be shielded — Apple hard-excludes them
- The user can fully revoke Screen Time permission at any time in iOS Settings → Screen Time
- If the user has Screen Time PIN-protected on their device, your monitoring scope may conflict with their existing setup (rare edge case)
- Apple Watch usage is not covered by this API path
- Lock screen and Home Screen interactions are not countable as app usage time

---

## Q3: Can the shield be temporary and automatically lifted after break duration? ShieldAction buttons — what are the limits?

### Shield lift:

**Yes — but it's not automatic via a timer. It requires an explicit API call.**

There is no built-in "lift shield after X seconds" timer in ManagedSettings. The shield stays up until your code removes it.

Two practical patterns for auto-lift after break duration:

**Pattern A — ShieldAction dismisses immediately, break is honour-system:**
- User taps "Start Break" → ShieldActionExtension returns `.close` + calls `ManagedSettingsStore().shield.applicationCategories = nil` → shield gone → user takes break manually → after break, they return to app → AppCoordinator restarts monitoring
- Simple. Puts break duration on user trust. Works well for wellness apps (you trust the user).

**Pattern B — Shield stays up for break duration (hard enforcement):**
- Harder. Extension has limited background execution time (~30s).
- Requires: ShieldAction writes "break started at X" to App Group → schedules a separate DeviceActivity schedule that fires after break duration → that second monitor removes the shield
- Or: ShieldAction calls a lightweight background task to sleep and then remove shield
- This is considerably more complex, and the break timer schedule adds a second DeviceActivity registration
- For a wellness app, Pattern A is correct. Hard enforcement is parental-control territory.

**Recommended pattern for kshana:** Pattern A. User taps "Start Break", shield lifts, trust the user. After break, main app (on next foreground) or a restart call in ShieldAction restarts monitoring.

### ShieldAction buttons:

**Primary button**: Yes, required. Customizable label text only. You can call it "Start Break", "Take a Break", "20-Second Rest".

**Secondary button**: Optional. Customizable label text only. You can call it "Skip", "Snooze 5 min", "Not Now".

**Third button**: Not available. Two actions maximum.

**What you CANNOT do in ShieldAction:**
- Custom SwiftUI — not available. The action handler runs in an extension, produces no UI.
- Custom button styling — system colors, system fonts. Text only.
- Show a countdown timer IN the shield — not possible. The shield UI is system-controlled. (You can put "20 seconds" in the subtitle as a hint, but the actual countdown timer is honor-system.)
- Haptic feedback — not available in ShieldAction extensions.

**ShieldConfiguration (the shield's visual):**
- Title: attributed string (limited formatting — bold, foreground color supported)
- Body subtitle: attributed string
- Primary button label: plain string only
- Secondary button label: plain string only (optional)
- Icon: `ShieldConfiguration.Image` — you CAN provide a custom image (your logo). This IS customizable since iOS 16.1.
- Background: system-controlled blur/frosted glass. No custom background.
- Layout: fixed. No custom layout.

**Practical kshana shield:**
```
[kshana logo]
"Eye Break Time"
"You've been staring for 20 minutes. Look at something 20 feet away for 20 seconds."
[Start Break]   [Skip This Once]
```

This is achievable and looks credible. Not as beautiful as kshana's own OverlayView, but it IS the system-trusted interrupt UI.

---

## Q4: Can kshana enforce posture/eye breaks based on total device use, or only selected app activity? What is impossible?

### What IS possible:

- **Total device app usage threshold**: Monitor cumulative time across all apps in a time window. When user hits 20 min across any/all apps → break fires. This is achievable with `DeviceActivityEvent` using `.all` categories against a daily schedule.
- **Two separate thresholds**: One for eye breaks (20 min), one for posture breaks (45 min). Both can be registered in the same DeviceActivity schedule.
- **Recurring throughout the day**: Re-register monitoring after each break → fires again after next 20 min accumulation.
- **Monitoring works even when kshana is not the foreground app**: The DeviceActivityMonitor extension wakes independently of the main app process. kshana does not need to be running.

### What is IMPOSSIBLE or unreliable:

- **Exact screen-on time** (not just app usage duration): DeviceActivity counts time spent in apps, not raw screen-on seconds. Lock screen pulls, notification handling, Siri don't count. So "20 minutes of active eyes-on-screen use" maps approximately to DeviceActivity's "20 minutes of foreground app time" — close enough for wellness, not millisecond-precise.
- **Detecting when the user puts the phone down mid-app**: If the user opens TikTok and sets their phone down (screen stays on), DeviceActivity still counts it as usage. kshana cannot distinguish "eyes on screen" from "phone face-up on desk." This is a fundamental limitation. The current foreground `ScreenTimeTracker` has the same problem.
- **Posture-specific sensor data**: CMMotionActivityManager detects driving/walking but not "seated with neck bent forward." There is no posture sensor API on iPhone. Posture break timing is still interval-based, not posture-detected.
- **Reliable sub-minute precision**: iOS batches DeviceActivity events. A 5-minute threshold might fire at 5 min 45 sec. A 20-minute threshold might fire at 21 min. Do not build features that depend on exact timing.
- **Cross-device posture monitoring** (Apple Watch): Out of scope for this phase. DeviceActivity is phone-only.
- **Monitoring ALL device interactions** (biometric unlock, lock screen widgets, Control Center swipes): Only foreground app usage time counts. Peripheral interactions don't accumulate toward the threshold.

### Bottom line on total device use:

**kshana can fire breaks based on "accumulated time spent in apps" which is the closest available approximation to "screen use time."** This IS the right signal for eye breaks. It's not perfect, but it's the same signal Apple's own Screen Time feature uses for its "daily app limits." The 20-20-20 rule doesn't require millisecond precision.

---

## Q5: Exact targets, capabilities, files, entitlements, and project changes required

This has already been partially documented by Virgil. Complete consolidated view:

### Entitlements

| Entitlement | Where | Approval Process |
|---|---|---|
| `com.apple.developer.family-controls` | Main app `.entitlements` | Manual Apple approval — file at developer.apple.com/contact/request/family-controls-distribution |
| `com.apple.security.application-groups` | Main app + all 3 extensions | Self-service in Developer Portal (no approval queue) |
| `com.apple.developer.usernotifications.time-sensitive` | Main app | Self-service (already planned) |

### New Extension Targets

| Target | Extension type | Key file | Purpose |
|---|---|---|---|
| `kshanaDeviceActivityMonitor` | `com.apple.deviceactivity-monitor` | `DeviceActivityMonitorExtension.swift` | Receives threshold callback, applies shield |
| `kshanaShieldConfiguration` | `com.apple.shieldconfiguration` | `ShieldConfigurationExtension.swift` | Returns title/subtitle/buttons to system |
| `kshanaShieldAction` | `com.apple.shieldaction` | `ShieldActionExtension.swift` | Handles button taps, removes shield, restarts cycle |

### New Framework Imports

| Framework | Used in |
|---|---|
| `FamilyControls` | Main app (authorization request) |
| `DeviceActivity` | Main app (start/stop monitoring), DeviceActivityMonitor extension |
| `ManagedSettings` | DeviceActivityMonitor extension (apply/remove shield), ShieldConfiguration (configuration), ShieldAction (remove shield) |

### App Groups

Single shared container: `group.com.yashasg.eyeposturereminder`

Contents (App Group shared UserDefaults or FileManager):
- `breakLastStartedAt: Date?` — when the break started
- `breakDuration: TimeInterval` — configured break length
- `eyeInterval: TimeInterval` — configured eye break interval
- `postureInterval: TimeInterval` — configured posture break interval
- `monitoringActive: Bool` — whether monitoring is currently running

### New Service: `ScreenTimeShieldManager`

Lives in main app. Responsibilities:
- Owns `AuthorizationCenter.shared.requestAuthorization(for: .individual)` 
- Defines `DeviceActivitySchedule` (daily window, e.g. 8am–11pm, repeats: true)
- Registers `DeviceActivityEvent` with threshold per break type
- Writes configuration to App Group shared container
- Starts/stops `DeviceActivityCenter` monitoring
- Provides `isAuthorized: Bool` to drive onboarding UI
- Provides `isMonitoringActive: Bool` to drive settings UI

### New Onboarding Screen

One new mandatory screen (or integrated into existing Permission screen):
- Explains what Screen Time interrupt mode does: "kshana will pause all apps and show a break reminder after [interval]"
- Presents `AuthorizationCenter.shared.requestAuthorization(for: .individual)` trigger button
- Shows current authorization status

### `AppCoordinator` changes

- New `ReminderDeliveryMode` enum: `.notifications` (current), `.screenTimeShield`, `.hybrid`
- `ScreenTimeShieldManager` injected and owned by coordinator
- Shield mode enables/disables based on FamilyControls authorization status

### Build system (Virgil owns this)

- New top-level `project.yml` (XcodeGen) defining all 4 targets
- Extension targets: separate Info.plist per extension, separate entitlements file
- `build_signed.sh` ExportOptions.plist: 4 bundle ID → profile mappings
- 3 new App IDs registered in Developer Portal
- 4 provisioning profiles (dev + distribution for each)

### Files NOT changed

- `ScreenTimeTracker.swift` — stays, used in foreground precision mode alongside shield
- `OverlayManager.swift` — stays, shown when user taps notification or when app opens from shield action
- `ReminderScheduler.swift` — stays, powers notification fallback mode
- `AppDelegate.swift` — notification handling stays unchanged

---

## Q6: Smallest credible prototype — spike plan and success criteria

**Goal:** Validate that the DeviceActivity → Shield → ShieldAction loop actually works end-to-end on a physical device, before committing to the full engineering scope.

**This spike requires the FamilyControls entitlement to be approved first.** You can build and compile without it, but you cannot validate the shield behavior on device without it.

### Spike plan

**Throw-away Xcode project — not in the kshana repo.**

Create: `KshanaScreenTimeSpike.xcodeproj` with 4 targets:
1. `SpikeiOSApp` — minimal SwiftUI app, 1 screen
2. `SpikeDeviceActivityMonitor` — extension
3. `SpikeShieldConfiguration` — extension
4. `SpikeShieldAction` — extension

**Step 1: Authorization** (~1h)
```swift
// In SpikeiOSApp, on a button tap:
try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
```
Success: System authorization sheet appears. User grants permission. App shows "authorized."

**Step 2: Register monitoring with a 1-minute threshold** (~1h)
```swift
let schedule = DeviceActivitySchedule(
    intervalStart: DateComponents(hour: 0, minute: 0),
    intervalEnd: DateComponents(hour: 23, minute: 59),
    repeats: true
)
let event = DeviceActivityEvent(
    applications: ApplicationToken.all,  // or .allApps
    categories: ActivityCategoryToken.all,
    threshold: DateComponents(minute: 1)
)
try DeviceActivityCenter().startMonitoring(.daily, during: schedule, events: [.breakThreshold: event])
```
Note: 1 minute chosen for testability. Production would be 1200 seconds (20 min).

**Step 3: DeviceActivityMonitor applies shield** (~30 min)
```swift
class SpikeMonitor: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) { }
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        ManagedSettingsStore().shield.applicationCategories = .all()
    }
}
```

**Step 4: ShieldConfiguration returns content** (~30 min)
```swift
class SpikeShieldConfig: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        ShieldConfiguration(
            title: AttributedString("Eye Break Time"),
            subtitle: AttributedString("Look 20 feet away for 20 seconds."),
            primaryButtonLabel: AttributedString("Start Break"),
            secondaryButtonLabel: AttributedString("Skip")
        )
    }
}
```

**Step 5: ShieldAction removes shield and restarts** (~1h)
```swift
class SpikeShieldAction: ShieldActionExtension {
    override func handle(action: ShieldAction, for application: Application) async -> ShieldActionResponse {
        let store = ManagedSettingsStore()
        store.shield.applicationCategories = nil  // lift shield
        // Restart monitoring
        try? DeviceActivityCenter().startMonitoring(.daily, during: schedule, events: [.breakThreshold: event])
        return .close
    }
}
```

**Total spike time: ~5-6 hours of coding. Blocked on entitlement approval.**

### Success criteria for the spike:

1. ✅ Authorization sheet appears and grants permission
2. ✅ DeviceActivityCenter.startMonitoring() does not throw
3. ✅ After 1 minute of app usage (any app), shield appears over that app
4. ✅ Shield shows kshana-authored title and "Start Break" button
5. ✅ Tapping "Start Break" dismisses the shield
6. ✅ After another 1 minute of use, shield appears again (recurring cycle confirmed)
7. ✅ Shield survives app switching (user switches from TikTok to Instagram — shield still present)

If all 7 pass: green-light Phase 3 Shield implementation in kshana.
If 3 or 4 fail (shield doesn't appear): escalate to Apple developer forums, check iOS version. Known issue territory.
If 6 fails (no recurrence): fix the restart logic. This is a known sharp edge in the API.

---

## Q7: App Store and entitlement review — what Yashasg needs to do

### What Apple reviews for FamilyControls entitlement

The entitlement request form asks:
1. Your app name and bundle ID
2. What the app does
3. How you use FamilyControls
4. Which authorization mode (`.individual` or `.family`)
5. Whether Family Sharing is involved

### Suggested request wording

> kshana is a digital wellness iOS app that helps users protect their eye health and maintain good posture during screen use. The app monitors total device usage time and delivers system break reminders when the user has been using their device continuously for their configured interval (e.g., 20 minutes).
> 
> We are requesting the FamilyControls entitlement using exclusively `.individual` authorization mode (iOS 16+). There is no parental control, Family Sharing, or child device feature in this app. The user monitors and restricts their own device on their own behalf.
> 
> Specifically: after the user's configured break interval of continuous device use, kshana's DeviceActivityMonitor extension triggers a ManagedSettings shield over all app categories. The shield prompts the user to take a break (eye rest, look away, posture check). The user can start the break or skip it. There is no lock-out, no PIN, no parent/guardian approval flow.
> 
> This use case is architecturally identical to how one-sec, Opal, and Roots use FamilyControls `.individual` mode. The app's Privacy Policy and onboarding clearly disclose Screen Time API usage to the user.

### Likelihood of approval

**High for self-wellness use case.** Apple added `.individual` mode in iOS 16 specifically for this category. Multiple comparable apps have been approved. The framing is important — emphasize self-wellness, individual mode, user-controlled, not parental control.

**What would cause rejection:**
- Accidentally referencing `.family` mode or parental controls
- Ambiguous wording that makes it sound like the app monitors other people's devices
- No working prototype at the time of submission (have the spike ready)

### Timeline

No SLA. Typical community-reported range: 3–21 days. File the request on the same day as deciding to pursue this path — it's the only hard external dependency. Everything else (code) can happen in parallel.

### App Store Review (after entitlement is granted)

App Review will check:
- Does the app use `.individual` mode only? ✅ Yes
- Is there clear user consent flow (Screen Time authorization prompt)? ✅ Yes — system sheet
- Does PrivacyInfo.xcprivacy declare Screen Time API usage? → Must add this entry when implementing
- Does the app accurately describe its Screen Time usage in its App Store listing and privacy policy? → Update docs at launch

---

## Q8: What to do with local notification work

**Keep as a functional fallback. Change the product promise.**

Here is the honest analysis:

| Mechanism | Status | UX Mode | User effort |
|---|---|---|---|
| Local notifications (current, fixed by AppCoordinator) | Working now | "Gentle tap on shoulder" | Tap banner → open app → see overlay |
| Screen Time Shield | Phase 3, needs entitlement | "Hard interrupt" | Can't ignore it — shield blocks everything |

These are two different user experiences. For habit change and health intervention, **the Shield is genuinely more effective** — you cannot dismiss a full-screen system block as easily as flicking away a notification banner. This is the product insight Yashasg is pointing at.

However:

- Some users actively DO NOT want hard interrupts. They want the gentle reminder. Notifications serve them correctly.
- Not every user will grant Screen Time permission. The notification path serves users who don't.
- FamilyControls approval could take weeks. Notification path works TODAY.

### Recommendation:

1. **Do NOT remove notification work.** It is working (post AppCoordinator fix), it took engineering effort, and it serves a real user population.
2. **Change the product promise.** kshana's pitch is not "notification reminders." It is "break interrupts." The Shield is the feature that makes that true. Build toward it.
3. **Ship notifications as the Phase 2 complete deliverable** — working, reliable, across all apps. Keep copy honest: "you'll receive a reminder banner" not "kshana will interrupt whatever you're doing."
4. **File FamilyControls entitlement request immediately** — this is the only time-gated external dependency.
5. **Build the spike** once entitlement is approved — validate before full commitment.
6. **Phase 3: Ship Shield as "Interrupt Mode"** — opt-in toggle in Settings. Users who want hard interrupts enable it; users who prefer notifications keep it off.

The app is NOT a waste as a notifications app. But it is also not fulfilling its potential. The Shield is what makes it genuinely different from setting an iPhone alarm.

---

## Phase-Gate Criteria

Before committing to Phase 3 Shield implementation, ALL of the following must be true:

| Gate | Criteria | Status |
|---|---|---|
| G1 — Entitlement | `com.apple.developer.family-controls` granted by Apple | ❌ Not filed yet |
| G2 — Spike | Spike project passes all 7 success criteria on a physical device | ❌ Blocked on G1 |
| G3 — Build system | XcodeGen project.yml with 4 extension targets compiles cleanly | ❌ Not started |
| G4 — Notification baseline | Phase 2 notification path validated working end-to-end in TestFlight | 🟡 In progress |
| G5 — Product decision | Yashasg confirms interrupt mode is a product priority worth the scope | ❓ Pending this doc |

When G1-G5 are all green: proceed to Phase 3 Shield implementation.

---

## Architectural Decision

**Screen Time Shield interrupt mode is the correct long-term architecture for kshana's core promise. It is not a settings app — it is a health intervention tool. The Shield makes the intervention real.**

**Immediate actions:**

1. **File FamilyControls entitlement request today** — go to developer.apple.com/contact/request/family-controls-distribution, use the wording from Q7 above. This is the only external-dependency step with an unknown timeline. File immediately.
2. **Complete Phase 2 notification path** — ship notifications as working baseline. Do not remove or deprioritize.
3. **Keep ScreenTimeTracker for foreground precision** — it complements the Shield mode (measures actual eyes-on-screen time when kshana is foreground).
4. **After entitlement approval: build the spike** — 5-6 hour validation before committing full Phase 3 scope.
5. **Phase 3 gate: Virgil builds XcodeGen project.yml** with extension targets before Rusty wires `ScreenTimeShieldManager`.

**What this is NOT:**
- kshana is not a parental control app.
- kshana is not a screen time statistics dashboard.
- kshana uses Screen Time as an interrupt delivery mechanism — not as a feature in its own right. The user doesn't see "Screen Time." They see "break time."

If the app does its job right, the user doesn't know or care that ManagedSettings is involved. They just get interrupted, take a break, and feel better.

# Decision: Screen Time Entitlement & CI/CD Path

**Author:** Virgil (CI/CD Dev)
**Date:** 2026-04-29
**Status:** Research report — no code changes
**Priority:** HIGH — gates Phase 3 architecture
**Complements:** `rusty-screen-time-shield-path.md` (architecture) — this document covers signing, provisioning, and CI

---

## Context

Rusty's `rusty-screen-time-shield-path.md` correctly identifies that the Screen Time Shield path (FamilyControls + DeviceActivity + ManagedSettings) is real, available to third-party developers since iOS 16, and viable for a self-wellness app. This document covers the **capability/provisioning/signing mechanics** and what the CI/CD pipeline needs to handle.

---

## Q1: Which entitlements and capabilities are required?

### Entitlement requiring Apple approval (NOT automatic)

| Entitlement key | Where to add | Approval required? |
|---|---|---|
| `com.apple.developer.family-controls` | Main app `.entitlements` file | **YES — manual Apple approval** |

This is the gating entitlement. Without it, all FamilyControls APIs throw an authorization error at runtime. The entitlement request portal is:
[https://developer.apple.com/contact/request/family-controls-distribution](https://developer.apple.com/contact/request/family-controls-distribution)

### Entitlements that are automatic (enabled in Developer Portal, no request form)

| Entitlement key | Xcode Capability name | Notes |
|---|---|---|
| `com.apple.security.application-groups` | App Groups | Toggle in Developer Portal → App ID → Capabilities |
| `com.apple.developer.usernotifications.time-sensitive` | Time Sensitive Notifications | Already planned for current notification path |

App Groups must be explicitly configured in the Developer Portal App ID (it is "automatic" in the sense that no separate approval email is needed — you toggle it yourself). The provisioning profile must then be regenerated to include the App Groups entitlement.

### Extension target entitlements (all require separate App IDs)

Each extension target needs its **own** App ID registered in the Developer Portal with the same App Groups entitlement:

| Extension App ID | Entitlements |
|---|---|
| `com.yashasg.eyeposturereminder.deviceactivitymonitor` | App Groups (same group as main app) |
| `com.yashasg.eyeposturereminder.shieldconfiguration` | App Groups |
| `com.yashasg.eyeposturereminder.shieldaction` | App Groups |

The main app App ID (`com.yashasg.eyeposturereminder`) needs:
- `com.apple.developer.family-controls` (requires Apple approval)
- `com.apple.security.application-groups` with value `group.com.yashasg.eyeposturereminder`

---

## Q2: Automatic Xcode capabilities vs manually approved entitlements

### Category A — Toggle yourself in Developer Portal (no approval queue)
- **App Groups** — add capability to App ID, regenerate provisioning profile
- **Push Notifications** — add capability to App ID, regenerate profile
- **Time Sensitive Notifications** — add capability to App ID, regenerate profile
- **Background Modes** — add capability to App ID, regenerate profile

### Category B — Request-only, Apple reviews and approves
- **`com.apple.developer.family-controls`** — submit at developer.apple.com/contact/request/family-controls-distribution. Apple reviews the use case. Typical timeline: several days to a few weeks. There is no SLA. Approval is not guaranteed. The entitlement is tied to your Team ID, not to an individual app.

**Practical implication:** You cannot develop or test the live FamilyControls authorization flow on a physical device until this entitlement is granted. Simulator may run partial code paths but will not grant authorization. Local development is blocked on the critical auth flow until Apple approves.

---

## Q3: Project structure changes required

### The SPM-only build cannot support extension targets

`Package.swift` currently declares a single `.executableTarget`. App extension targets (DeviceActivityMonitor, ShieldConfiguration, ShieldAction) **cannot be expressed in `Package.swift`**. This is a hard SPM limitation — extensions require host app embedding, Info.plist with `NSExtension` key, and Xcode build system target types that SPM does not model.

### Required changes to build system

#### 1. New `project.yml` (XcodeGen) for the main app + extensions

The current `UITests/project.yml` is a test-only XcodeGen spec. We need a new top-level `project.yml` that defines:

```
targets:
  EyePostureReminder:        (application)
  DeviceActivityMonitor:     (app extension — com.apple.deviceactivity-monitor)
  ShieldConfiguration:       (app extension — com.apple.shieldconfiguration)
  ShieldAction:              (app extension — com.apple.shieldaction)
```

The main app target wraps the SPM executable as a dependency (same pattern as UITests/project.yml). All four targets share the same App Group.

#### 2. Separate entitlements files per target

Each extension needs its own `.entitlements` file with the App Groups key. The main app entitlements file gets the FamilyControls entitlement added when the Apple approval arrives.

```
EyePostureReminder/EyePostureReminder.Development.entitlements
EyePostureReminder/EyePostureReminder.Distribution.entitlements  ← add family-controls + app-groups
Extensions/DeviceActivityMonitor/DeviceActivityMonitor.entitlements
Extensions/ShieldConfiguration/ShieldConfiguration.entitlements
Extensions/ShieldAction/ShieldAction.entitlements
```

#### 3. Extension Swift files

Each extension target needs a minimal Swift source file (the extension entry point). These are separate from the main app's SPM source tree.

```
Extensions/
  DeviceActivityMonitor/
    DeviceActivityMonitorExtension.swift
    Info.plist
    DeviceActivityMonitor.entitlements
  ShieldConfiguration/
    ShieldConfigurationExtension.swift
    Info.plist
    ShieldConfiguration.entitlements
  ShieldAction/
    ShieldActionExtension.swift
    Info.plist
    ShieldAction.entitlements
```

---

## Q4: Impact on signing, TestFlight export, and CI

### Provisioning profiles — what changes

Today there is **one** provisioning profile (distribution, App Store) tied to `com.yashasg.eyeposturereminder`. With three extension targets, we need **four** distribution profiles:

| Profile | App ID |
|---|---|
| Main app | `com.yashasg.eyeposturereminder` |
| DeviceActivityMonitor | `com.yashasg.eyeposturereminder.deviceactivitymonitor` |
| ShieldConfiguration | `com.yashasg.eyeposturereminder.shieldconfiguration` |
| ShieldAction | `com.yashasg.eyeposturereminder.shieldaction` |

All four profiles must include the App Groups capability. The main app profile must include the FamilyControls entitlement (only available after Apple approval).

### `scripts/build_signed.sh` — what changes

The `ExportOptions.plist` embedded in `build_signed.sh` will need a `provisioningProfiles` dictionary mapping each bundle ID to its provisioning profile name:

```xml
<key>provisioningProfiles</key>
<dict>
  <key>com.yashasg.eyeposturereminder</key>
  <string>kshana App Store Distribution</string>
  <key>com.yashasg.eyeposturereminder.deviceactivitymonitor</key>
  <string>kshana DeviceActivityMonitor Distribution</string>
  <key>com.yashasg.eyeposturereminder.shieldconfiguration</key>
  <string>kshana ShieldConfiguration Distribution</string>
  <key>com.yashasg.eyeposturereminder.shieldaction</key>
  <string>kshana ShieldAction Distribution</string>
</dict>
```

### `.github/workflows/testflight.yml` — what changes

Currently the workflow installs one provisioning profile. It must be updated to decode and install **four** provisioning profiles, one per target. This means four new GitHub secrets:

| Secret name | Contents |
|---|---|
| `BUILD_PROVISION_PROFILE_BASE64` | Main app profile (existing) |
| `BUILD_PP_DEVICEACTIVITY_BASE64` | DeviceActivityMonitor profile |
| `BUILD_PP_SHIELDCONFIG_BASE64` | ShieldConfiguration profile |
| `BUILD_PP_SHIELDACTION_BASE64` | ShieldAction profile |

The install step will loop over all four profiles and copy them to `~/Library/MobileDevice/Provisioning Profiles/`.

### What can be tested locally before entitlement approval

| What | Testable without approval? | Notes |
|---|---|---|
| Extension target compilation | ✅ Yes | Code compiles without the entitlement |
| App Groups shared container | ✅ Yes | Works in development signing with App Groups enabled |
| DeviceActivityMonitor registration | ⚠️ Partial | Can register schedules, but `AuthorizationCenter.requestAuthorization` will fail |
| Shield appearing over other apps | ❌ No | Requires entitlement + real authorization |
| ShieldConfiguration rendering | ⚠️ Simulator only | System may render a placeholder shield in simulator without full auth |
| ShieldAction button tap | ⚠️ Partial | Action handler code can be unit tested; end-to-end requires entitlement |

**In practice:** You can build the extension targets, wire the shared state via App Groups, and unit test the logic before the entitlement is approved. The live cross-app shield behavior cannot be validated end-to-end on device until approval.

---

## Q5: Steps for Yashasg in Apple Developer / App Store Connect

### Immediate pre-work (no approval needed)

1. **Register three new App IDs** in the Developer Portal under Certificates, Identifiers & Profiles → Identifiers:
   - `com.yashasg.eyeposturereminder.deviceactivitymonitor`
   - `com.yashasg.eyeposturereminder.shieldconfiguration`
   - `com.yashasg.eyeposturereminder.shieldaction`

2. **Enable App Groups capability** on all four App IDs (main app + 3 extensions). Create a new App Group container: `group.com.yashasg.eyeposturereminder`.

3. **Regenerate development and distribution provisioning profiles** for all four App IDs after enabling App Groups.

### Entitlement request — FamilyControls

Navigate to: [https://developer.apple.com/contact/request/family-controls-distribution](https://developer.apple.com/contact/request/family-controls-distribution)

**Suggested wording for the approval request:**

> kshana (Eye & Posture Reminder) is a self-care wellness app that helps users protect their eye health and maintain good posture during screen time. The app reminds users to take breaks and rest their eyes at regular intervals.
>
> We are requesting the FamilyControls entitlement to use the `.individual` authorization mode (iOS 16+). This allows the app to trigger a Screen Time Shield — a system-managed full-screen interrupt — when the user has been using their device continuously for longer than their configured break interval (e.g., 20 minutes). The user must explicitly authorize the app via the system Screen Time permission prompt. No Family Sharing, parental control, or child device features are used.
>
> The intended use case is strictly self-wellness: the user controls their own break schedule, and the shield is a voluntary interrupt mechanism the user opts into. This is architecturally equivalent to how apps like one-sec, Opal, and Roots use FamilyControls `.individual` mode.
>
> Primary framework usage: `FamilyControls` (`.individual` authorization), `DeviceActivity` (threshold-based monitoring), `ManagedSettings` (applying/removing shields on threshold events).

### After entitlement approval

1. Add `com.apple.developer.family-controls` to the main app's `.entitlements` files (both development and distribution).
2. Regenerate the main app provisioning profiles (development + distribution) — Apple's portal will now allow this capability to be included.
3. Download and install the new profiles.
4. Update the `BUILD_PROVISION_PROFILE_BASE64` secret in GitHub with the regenerated distribution profile.

---

## Q6: Risk register

| Risk | Severity | Likelihood | Notes |
|---|---|---|---|
| FamilyControls entitlement denied | HIGH | Low–Medium | Apple reviews use case. Self-wellness apps using `.individual` mode have been approved (Opal, one-sec, Roots). Denial is possible if Apple reads the use case as parental control. Mitigation: use the wording above, emphasise `.individual` mode and user-controlled opt-in. |
| Entitlement approval delay | MEDIUM | HIGH | No SLA. Days to weeks. This is a hard external dependency that blocks all end-to-end testing. Do not let this block extension target development — build the code while waiting. |
| Extension signing complexity | MEDIUM | Medium | Four profiles instead of one. CI step must install and map all four. A profile mismatch causes a cryptic signing error at archive time. Mitigation: add explicit `provisioningProfiles` mapping to ExportOptions.plist and verify with a dry-run archive before pushing to TestFlight CI. |
| App Store Review scrutiny | MEDIUM | Low | Review will look at: does the app use `.individual` mode? Is there a clear user-facing onboarding for Screen Time permission? Does the app accurately describe the Screen Time usage in its privacy manifest (`PrivacyInfo.xcprivacy`)? The PrivacyInfo.xcprivacy will need a Screen Time usage entry. |
| iOS version support floor | LOW | LOW | FamilyControls `.individual` mode requires iOS 16+. The current deployment target is iOS 16.0 — this is already aligned. No version support change needed. |
| SPM executable target incompatibility | MEDIUM | Certain | Extension targets **cannot** be added to `Package.swift`. A new `project.yml` XcodeGen spec must be created for the main app + extensions. This is build system work that must happen before any extension code can be compiled. |
| App Group state corruption | LOW | Low | Extensions sharing UserDefaults/FileManager via App Group container can corrupt state if a write happens concurrently from multiple processes. Mitigation: use a simple keyed archive or SQLite via GRDB in the shared container with proper serialization. |
| ShieldAction extension memory limits | LOW | Low | App extensions have strict memory limits (~60 MB). The ShieldAction handler must be minimal — no heavy logic, no image loading. The main business logic stays in the main app. |

---

## CI/CD Summary

**Today:** 1 app target, 1 entitlements file, 1 provisioning profile, 1 GitHub secret for the profile.

**With Screen Time Shield:** 4 app/extension targets, 4 entitlements files, 4 provisioning profiles, 4 GitHub secrets for profiles, updated ExportOptions.plist with explicit bundle ID → profile mapping.

**Build system:** New top-level `project.yml` (XcodeGen) with all four targets. `build_signed.sh` continues to drive archive + export; only ExportOptions.plist changes structurally.

**Gating dependency:** `com.apple.developer.family-controls` entitlement approval. File the request immediately to start the clock. Build extension targets and write tests while waiting.

**Local pre-approval testing scope:** Compilation, App Groups shared state, unit tests for monitor/shield logic. End-to-end shield behavior on device blocked until approval.

### 2026-04-28T21:56:44-07:00: User directive
**By:** Yashasg (via Copilot)
**What:** Local reminder alerts are noise and not the core product. Prioritize proving Apple Screen Time / interrupt mode; if kshana only sets ordinary reminders or Screen Time-like settings without meaningful interruption, the app is not worth pursuing.
**Why:** User request — captured for team memory


---

## Phase 3: True Interrupt Mode Pivot — Screen Time APIs Integration

### Decision 3.1: Product Pivot to True Interrupt Mode via Screen Time APIs (Danny)
**Date:** 2026-04-29  
**Status:** 🔄 APPROVED (implementing)  
**Related Issues:** #201-#211 (Phase 3 backlog)

#### Problem
Current Phase 1-2 model (notification + dismissible overlay) cannot enforce breaks — users can ignore reminders indefinitely. iOS prevents app-initiated interruptions users cannot bypass. Notification + overlay model is "best effort" only.

#### Solution
Pivot kshana's core value from "gentle reminders" to "True Interrupt Mode via Apple Screen Time APIs." When a break reminder fires, kshana shields user's selected apps (e.g., Instagram, Twitter, games) using FamilyControls. User cannot bypass shield immediately; must request access (logged). Privacy-first: all data is local device-only; no cloud storage or third-party sharing. Notification reminders remain fallback if shield unavailable.

#### Architecture Changes
| Aspect | Phase 1–2 | Phase 3+ |
|---|---|---|
| **Primary Interruption** | Notification + dismissible overlay | Non-dismissible shield (Screen Time APIs) |
| **Authorization** | UNUserNotificationCenter | FamilyControls (new permission) |
| **Extension Targets** | None | ShieldConfiguration + ShieldAction (2 new targets) |
| **Data Model** | ReminderSettings only | + ShieldedAppCategory (user-selected apps) |
| **App Group** | None | group.com.yashasg.eyeposturereminder (main app ↔ extensions) |
| **Fallback** | N/A | Notifications sent if shield fails |

#### Critical Dependencies
1. **FamilyControls Entitlement Approval** — Case ID 102881605113 (P0 blocker #201)
2. **Extension Target Setup** (#203) — ShieldConfiguration + ShieldAction with app group entitlements
3. **Authorization + App Picker** (#204) — User opt-in to FamilyControls + app selection

#### Timeline
- Blocked on entitlement approval (Apple SLA: 2–5 days)
- Spike work (M3.2) required before full build-out (3 weeks estimated for full Phase 3)
- Phase 3 is now critical path to MVP (not optional Polish/Advanced)

#### Acceptance Criteria
- ✅ FamilyControls entitlement approved (or clear rejection reason + remediation path)
- ✅ All extension targets build and sign in CI/CD
- ✅ App group communication verified (main app ↔ extensions)
- ✅ User can authorize FamilyControls + select apps to shield
- ✅ Shields apply correctly during breaks (non-dismissible)
- ✅ Notifications sent as fallback if shield unavailable
- ✅ Privacy policy + legal docs updated
- ✅ TestFlight build includes extensions; ready for beta distribution

**Approved by:** Yashasg (Owner)

---

### Decision 3.2: True Interrupt Mode Privacy & Legal Disclosure (Frank)
**Date:** 2026-04-29  
**Status:** Implemented  
**Priority:** HIGH — affects App Store submission readiness

#### Scope
1. **Truthful Data Handling Disclosure** — Screen Time integration reads only aggregate, user-authorized data; never reads message/browser/call content
2. **Approval Uncertainty** — Clear statement that feature is pending Apple approval and not yet available to users
3. **Wellness Disclaimer Consistency** — "Not medical advice" language maintained across all formats
4. **Privacy Label Preparation** — Updated guidance for pre- and post-approval privacy labeling

#### Changes Made
**docs/legal/PRIVACY.md:**
- Updated Overview section to introduce optional Screen Time monitoring
- Section 1: Added subsection on device activity & screen time data (aggregate-only, in-memory, no persistence)
- Section 2: Added explicit statement about NOT reading message content, browser history, etc.

**docs/legal/DISCLAIMER.md:**
- Added approval status note with case ID 102881605113
- Added comprehensive Screen Time feature section (pending approval, pending release)

**docs/PRIVACY_NUTRITION_LABELS.md:**
- Added new row to "Data the App Accesses but Does NOT Collect" table
- New section: "If Screen Time / Device Activity Features Are Added (Pending Approval)" with Device Status privacy label template

#### Owner-Only Fields Preserved
⚠️ **Untouched per Frank's charter:**
- `[PUBLISHER NAME]` in PRIVACY.md — owner-only
- `[CONTACT EMAIL]` in PRIVACY.md — owner-only
- `[JURISDICTION]` in TERMS.md Section 10 — owner-only

#### GitHub Issues Created
- **#199:** Legal & Privacy Docs Updated: True Interrupt Mode (closed with redirect to #209)
- **#200:** App Store Listing: Coordinate Legal Disclaimer Updates for Screen Time Feature (kept open)

---

### Decision 3.3: True Interrupt Mode UX & Onboarding (Reuben)
**Date:** 2026-04-28  
**Status:** Implemented — UX docs updated  
**Scope:** Onboarding, messaging, permissions flow, user-facing terminology

#### Key UX Decisions

**1. Four-Screen Onboarding (was 3 screens)**
- Added Screen 2 — "App Break Explanation" — a calm, pre-permission education screen before the system prompt
- Rationale: iOS Screen Time / Family Controls prompt is intimidating; pre-screen improves permission grant rates and user trust
- Flow: Welcome → App Break Explanation (NEW) → Screen Time Permission → Setup Preview

**2. Calm Pre-Permission Language**
- Renamed to "Screen Time Permission"; updated copy to avoid scary framing
- Focus on user benefit, not system capability
- Reassurance: "Your privacy matters. This does not give kshana access to your messages, photos, or any other content."

**3. Avoided "Family Controls" User-Facing**
- Rule: Never use "Family Controls" in app UI or user-facing copy
- Use instead: "Screen Time access", "app break access", "True Interrupt Mode", "break screen"
- Why: "Family Controls" has parental-control connotations; users worry app will restrict their use
- Exception: Developer/legal context (IMPLEMENTATION_PLAN.md, etc.) may use "Family Controls" technically

**4. Acknowledged Technical Reality: Local Alerts as Fallback**
- Current reality: Local reminder alerts (fallback)
- Future promise: Screen Time Shield-based interruption (when entitlement approved)
- Updated materials: README.md, ONBOARDING_SPEC.md, TESTFLIGHT_METADATA.md

**5. Swipe Lock on Screen 3 (Permission Screen)**
- Implemented `highPriorityGesture` to block accidental forward-swipe
- Encourages conscious interaction ("I choose to skip" vs. "I accidentally swiped")

#### Terminology Lock-In
**User-facing:**
- ✅ "App break", "break screen", "break reminders"
- ✅ "Screen Time access", "app break access"
- ✅ "True Interrupt Mode" (product marketing language)
- ❌ No "Family Controls" in UI
- ❌ No "Notifications" unless discussing iOS system

#### Files Updated
1. **UX_FLOWS.md** — Section 1.3 autonomy principle, Section 2.1 4-screen onboarding
2. **docs/ONBOARDING_SPEC.md** — Complete rewrite: 4 screens, pre-permission education, swipe lock
3. **README.md** — Feature list repositioned, True Interrupt Mode highlighted
4. **docs/APP_STORE_LISTING.md** — Subtitle and description for user control / app selection
5. **docs/TESTFLIGHT_METADATA.md** — Beta description updated, testing scope expanded

---

### Decision 3.4: True Interrupt Mode Architecture — FamilyControls & DeviceActivityMonitor (Rusty)
**Date:** 2026-04-28  
**Status:** Decision — Architecture Reference  
**Phase:** 3+

#### Four-Target Extension Architecture

| Target | Type | Bundle ID | Role |
|---|---|---|---|
| Main App | App | `com.yashasg.eyeposturereminder` | Core app: settings, FamilyControls auth request, fallback overlay, local notification fallback |
| DeviceActivityMonitor | Extension | `com.yashasg.eyeposturereminder.monitor` | System-triggered when thresholds reach; applies shields via ManagedSettingsStore |
| ShieldConfiguration | Extension | `com.yashasg.eyeposturereminder.shieldconfiguration` | Returns shield UI data (title, subtitle, icon, buttons); system renders |
| ShieldAction | Extension | `com.yashasg.eyeposturereminder.shieldaction` | Handles button taps; writes to App Groups, cannot directly open main app |

**All four targets must:**
- Live in the same Xcode project (not SPM — `.xcodeproj` required)
- Share App Groups entitlement (`com.apple.security.application-groups` = `group.com.yashasg.eyeposturereminder`)
- Carry FamilyControls entitlement (`com.apple.developer.family-controls` = `individual` scope)

#### FamilyControls Authorization Flow
User sees native iOS prompt once in main app. If approved, FamilyControls remains enabled for session. If denied, shield mode unavailable until user manually re-enables in Settings → Screen Time → [App Name].

```swift
try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
```

#### Extension Communication: App Groups Only
Extensions and main app cannot share memory directly. **Communication channel:** `UserDefaults(suiteName: "group.com.yashasg.eyeposturereminder")`

**State schema:**
```
shieldedApps: [String]              Apps to block (set by main app)
shieldActive: Bool                  Set by extension during threshold
shieldStartTime: Double             Timestamp when shield applied
breakStartedAt: Double?             Button tap time from ShieldAction
preferredShieldInterrupt: String    "shield" or "overlay" (user preference)
fallbackToNotification: Bool        Enable Phase 2 fallback (default true)
```

#### ShieldConfiguration: Data-Only, No Animations
**Critical constraint:** ShieldConfiguration is a **data structure**, not a SwiftUI canvas. Apple renders the shield UI.

**What you CAN customize:**
| Property | iOS Support | Type |
|---|---|---|
| `title` | 16+ | Custom string, up to ~50 chars |
| `subtitle` | 16+ | Custom string, up to ~100 chars |
| `icon` | 16+ | SF Symbol (system or custom) |
| `primaryButton` | 16+ | Custom label + verdict (`.close` or `.defer`) |
| `secondaryButton` | 16+ | Optional second button |
| `backgroundColor` | 17+ | Solid color |

**What you CANNOT do:**
- Animated SwiftUI views
- Custom layouts or positioning
- Font face customization
- Button styling (Apple controls colors, shapes)
- Arbitrary images (SF Symbols only)
- Any UIKit or SwiftUI composition

**YinYangEyeView in Shield: Impossible.** Static logo via custom SF Symbol is the only visual customization.

#### Local Notification Fallback (Phase 2-3 Bridge)
Both modes active simultaneously during transition:
1. Shield appears (iOS 16+, FamilyControls authorized, device allows)
2. If user defers (.defer verdict), main app detects via App Group state
3. Main app shows Phase 2 overlay + local notification as fallback
4. User can snooze via overlay or notification action
5. Next threshold or user interaction triggers shield again

**Graceful degradation:**
- User disables FamilyControls → Phase 2 overlay activates
- iOS 15 device → Phase 2 overlay only (Shield APIs not available)
- Device under MDM with Shield disabled → Phase 2 overlay only

#### Distribution Gating: FamilyControls Entitlement
`com.apple.developer.family-controls` is **restricted** and requires manual Apple approval. Blocks Phase 3 external distribution.

| Phase | Status | Distribution | Entitlement |
|---|---|---|---|
| **Phase 1-2** | Live | TestFlight / App Store | Not required |
| **Phase 3 (dev)** | Pending approval | Local dev + internal device testing only | Entitlement not yet granted |
| **Phase 3+ (post-approval)** | Ready | TestFlight / App Store | Approved and active |

**Timeline:**
- Entitlement request filed: 2026-04-29 (case ID 102881605113)
- Typical SLA: 3–10 business days (no guarantee)
- Phase 3 code CAN be written and tested locally while approval in progress
- **External distribution BLOCKED** until approved

#### Phase 3 Spike Scope (~1 day)
After FamilyControls entitlement approval:
1. Add three extension targets to Xcode project
2. Implement `DeviceActivityMonitor` subclass — apply shield to test app on 1-min schedule
3. Implement `ShieldConfigurationDataSource` — return title/subtitle/icon/buttons
4. Implement `ShieldActionDelegate` — handle button taps, write to App Group
5. Test on physical device (iOS 16+)
6. Verify: shield appears, custom text visible, buttons fire correct verdicts, main app reads App Group flag

**Risk:** Zero — extension targets are additive. Main app binary unchanged.

#### Testing Implications
**Unit Testing:**
- `MockManagedSettingsStore` — tracks shield application calls
- `MockAppGroupUserDefaults` — isolated shared state per test
- `MockAuthorizationCenter` — mocks FamilyControls auth without OS prompt
- 80%+ coverage target for non-system-API logic

**Device Testing (Manual):**
- 10 manual test cases (EXT-01 through EXT-10)
- Physical device required (simulator does not support Screen Time APIs)
- Test matrix: iOS 16.0, iOS 17.x, multiple device sizes
- Regression on each entitlement approval + every new OS version

#### Key Learnings
1. **ShieldConfiguration is a data struct, not a view.** Blocks ambitious visual customization (animated YinYang, complex layouts). Static logo via SF Symbol is practical limit.
2. **Static logo via custom SF Symbol recommended.** Design yin-yang geometry as SVG, import to Xcode as Symbol Set.
3. **Extensions cannot open the main app directly.** Indirect path (write App Group flag + schedule notification with deep link) is only user-initiated way.
4. **App Groups are the only extension-main app bridge.** No shared memory, no direct calls. All state serialized to `UserDefaults(suiteName:)`.
5. **Simulator does not support Screen Time APIs.** Physical device mandatory for any Screen Time / FamilyControls testing.
6. **Both Phase 2 overlay and Phase 3 shield coexist during transition.** Enables graceful degradation if authorization denied or OS version < 16.
7. **Entitlement approval is only external blocker.** All Phase 3 code can be written, compiled, verified locally immediately.

#### Files Updated
- `ARCHITECTURE.md` § 5.5 (full technical reference)
- `docs/TEST_STRATEGY.md` § 3.5, § 4.7 (extension mocks and device tests)

---

### Decision 3.5: Screen Time Shield Implementation — Build & Signing Implications (Virgil)
**Filed:** 2026-04-29 (Virgil, CI/CD Dev)  
**Status:** Initial assessment — Phase 3 blockers identified  
**Priority:** P0 — External dependency (FamilyControls entitlement approval) gates feature

#### Executive Summary
Implementing Screen Time Shield requires significant build system and code-signing changes. Primary blocker is **FamilyControls entitlement approval**, but infrastructure changes can proceed in parallel:

1. **Current state:** Single app target (SPM executable), single provisioning profile, manual signing for TestFlight
2. **Phase 3 target state:** 4 targets (main app + 3 extensions), 4 provisioning profiles, 4 entitlements files, explicit provisioning mapping in CI
3. **Timeline:** Build system work can begin now. External distribution (TestFlight + App Store) blocked until Apple approves entitlement

#### Extension Target Architecture
Screen Time Shield requires three extension targets in addition to the main app:

| Target | Bundle ID | Purpose | Signing |
|--------|-----------|---------|---------|
| Main app | `com.yashasg.eyeposturereminder` | Existing; enhanced for Shield UI setup + state management | Yes (manual) |
| **DeviceActivityMonitor** | `com.yashasg.eyeposturereminder.monitor` | Detects when user reaches configured threshold; triggers Shield UI | Yes (manual) |
| **ShieldConfiguration** | `com.yashasg.eyeposturereminder.shieldconfiguration` | UI shown when Shield first appears; user picks options | Yes (manual) |
| **ShieldAction** | `com.yashasg.eyeposturereminder.shieldaction` | Action handler when user taps Shield (e.g., "Extend Limit") | Yes (manual) |

#### Why XcodeGen + project.yml
**Current:** SPM executable target works for single-app builds. **Problem:** SPM does NOT support extension targets.

**Solution:** Create new `.xcodeproj` (via XcodeGen) that:
- Declares all 4 targets (main app + 3 extensions)
- References SPM executable as package dependency for main app target
- Applies entitlements, capabilities, signing configuration uniformly

**Impact on CI:**
- `scripts/build.sh` (dev/test) continues using SPM → no workflow changes for unit/UI tests
- `scripts/build_signed.sh` (archive/export/upload) must generate + use new root-level `.xcodeproj`
- Local development can use `.xcodeproj` directly for faster extension iteration

#### Provisioning Profile & Signing Strategy

**4 Profiles Required:**

| App ID | Profile Specifier | Environment Variable | Used By |
|--------|-------------------|----------------------|---------|
| Main app | E.g., "kshana Distribution" | `MAIN_APP_PROFILE` | Main target |
| Monitor ext. | E.g., "kshana Monitor Distribution" | `MONITOR_EXT_PROFILE` | DeviceActivityMonitor target |
| Configuration ext. | E.g., "kshana Configuration Distribution" | `CONFIG_EXT_PROFILE` | ShieldConfiguration target |
| Action ext. | E.g., "kshana Action Distribution" | `ACTION_EXT_PROFILE` | ShieldAction target |

**ExportOptions.plist Changes:**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store</string>
  <key>uploadBitcode</key><false/>
  <key>uploadSymbols</key><true/>
  <key>provisioningProfiles</key>
  <dict>
    <key>com.yashasg.eyeposturereminder</key>
    <string>kshana Distribution</string>
    <key>com.yashasg.eyeposturereminder.monitor</key>
    <string>kshana Monitor Distribution</string>
    <key>com.yashasg.eyeposturereminder.shieldconfiguration</key>
    <string>kshana Configuration Distribution</string>
    <key>com.yashasg.eyeposturereminder.shieldaction</key>
    <string>kshana Action Distribution</string>
  </dict>
</dict></plist>
```

#### Entitlements & Capabilities

**Required Entitlements (All 4 Targets):**

1. **FamilyControls** (Approval-gated)
```xml
<key>com.apple.developer.family-controls</key>
<array><string>individual</string></array>
```
- Restricted entitlement: Manual approval required
- Scope: `individual` (user controls own usage)
- Approval target: Team ID (one approval covers all targets)

2. **App Groups** (Self-service)
```xml
<key>com.apple.security.application-groups</key>
<array><string>group.com.yashasg.eyeposturereminder</string></array>
```
- Normal capability (no special approval)
- Enable on each of 4 App IDs in Developer Portal

3. **Focus Status** (Existing)
```xml
<key>com.apple.developer.focus-status</key>
<true/>
```
- Already in EyePostureReminder.entitlements (Phase 2)
- Include on all 4 targets

#### CI/CD Changes

**build_signed.sh Enhancements:**

1. **XcodeGen project generation** — Check for root `project.yml`; generate `.xcodeproj` with all 4 targets + proper settings; fall back gracefully if `project.yml` doesn't exist
2. **Multi-profile provisioning** — Read 4 profile specifiers from environment; validate all 4 profiles exist locally; inject into ExportOptions.plist
3. **Entitlements validation** — Check that entitlements include FamilyControls + App Groups; warn if FamilyControls present but approval not visible in provisioning profiles
4. **Archive injection** — Verify all 4 extensions bundled in `.app/Frameworks`

**GitHub Actions Workflow Changes:**

`testflight.yml`:
1. Update prerequisites to mention 4 App IDs + 4 profiles
2. Add secrets: `MONITOR_EXT_PROVISION_PROFILE_BASE64`, `CONFIG_EXT_PROVISION_PROFILE_BASE64`, `ACTION_EXT_PROVISION_PROFILE_BASE64`
3. Decode and install all 4 profiles before archive step
4. Pass profile specifiers as environment variables to `build_signed.sh`

#### Pre-Approval Development (Local + Internal TestFlight)

**Development Profile Path:**

1. Generate development provisioning profiles for all 4 App IDs
2. Use automatic signing locally: `SIGNING_STYLE=automatic` + development profiles
3. Run `./scripts/build_signed.sh export` locally — generates unsigned IPA
4. Install unsigned IPA on personal device via Xcode or `ios-deploy`
5. All FamilyControls APIs work immediately (no runtime rejection)

**Internal TestFlight (Same Apple Account):**

1. Keep using distribution profiles + FamilyControls entitlements in code
2. Build signed archive with distribution profiles
3. Upload to App Store Connect → TestFlight → Internal only
4. Apple's upload validator checks provisioning profile capabilities, NOT entitlements pre-approval
5. Internal testers can install + run; Shield UI won't function (FamilyControls APIs rejected at runtime), but app boots and reminder system works

**External TestFlight / App Store (Approval Required):**

1. After Apple approves FamilyControls entitlement:
2. Distribution profiles automatically updated with FamilyControls capability
3. No code changes needed; re-run `build_signed.sh upload`
4. ASC validator now permits FamilyControls entitlements
5. External testers receive Shield functionality

#### Risk Mitigation

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| **FamilyControls approval denied** | Low | Entire Phase 3 blocked | Request early; provide detailed app description. Approval SLA = unpredictable. |
| **Provisioning profile mismatch at export** | High | Export fails; tedious re-download cycle | Script validation: auto-detect + explicit error on missing profiles. |
| **Entitlements signature mismatch** | Medium | Archive succeeds; ASC upload fails with cryptic error | Validate entitlements before archive; include FamilyControls check in `build_signed.sh doctor`. |
| **Extension not bundled in .app** | Medium | App boots; Shield features silently absent | Add post-build script to verify `.app/Frameworks` contains extension binaries. |
| **CI secrets management (4 profiles = 4 secrets)** | Low | Secrets leak / false negatives in deploy | Rotate profiles regularly; use GitHub OIDC for future secrets. |

#### Action Items (For Yashasg / Reuben)

**Immediate (Today):**
1. File FamilyControls entitlement approval request: `developer.apple.com/contact/request/family-controls-distribution`
   - Use `individual` scope (self-care use case, not parental controls)
   - Explain: "Personal digital wellbeing — users set own reminder thresholds and Shield preferences"
2. Create 4 App IDs in Developer Portal:
   - `com.yashasg.eyeposturereminder` (main)
   - `com.yashasg.eyeposturereminder.monitor` (DeviceActivityMonitor)
   - `com.yashasg.eyeposturereminder.shieldconfiguration` (ShieldConfiguration)
   - `com.yashasg.eyeposturereminder.shieldaction` (ShieldAction)
3. Enable App Groups capability on all 4 App IDs (self-service in portal)

**While Waiting for Approval (Parallel Work — Virgil + Reuben):**
1. Create root-level `project.yml` (XcodeGen) with all 4 targets
2. Create `.entitlements` files for 3 new extensions
3. Update `build_signed.sh` to detect + use new `.xcodeproj`
4. Document multi-profile flow in README

**After Approval:**
1. Regenerate 4 distribution profiles (now with FamilyControls capability)
2. Add 3 new profile secrets to GitHub Actions
3. Run full CI cycle on dev branch
4. Merge to main + tag for TestFlight release


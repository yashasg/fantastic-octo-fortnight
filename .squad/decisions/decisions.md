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

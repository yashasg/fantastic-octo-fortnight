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

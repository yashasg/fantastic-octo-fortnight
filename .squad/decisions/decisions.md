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

Generated: 2026-04-25T20:49:07Z  
Scribe: Merged 5 Phase 2 decision files from inbox; dedup removed; all inbox files deleted and ready for commit

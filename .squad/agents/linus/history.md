# Project Context

- **Owner:** Yashasg
- **Project:** Eye & Posture Reminder — a lightweight iOS app with background timers and full-screen overlay reminders for eye breaks (20-20-20 rule) and posture checks
- **Stack:** Swift, SwiftUI (iOS 16+), MVVM, UserNotifications, UIKit overlay, UserDefaults
- **Created:** 2026-04-24

## Core Context

**Phase 1 UI Layer (M1.2, M1.5) — 2026-04-24 to 2026-04-25:**
OverlayView lives in UIWindow with no EnvironmentObjects; self-contained via UIHostingController. SettingsView is sheet-presented from HomeView (NavigationStack root). Patterns:
- Swipe UP to dismiss (translation.height < 0); isDismissing guard ensures onDismiss() called once (manual OR timer, not both).
- Fade animations use opacity state var; overlayAppearCurve (appear), overlayDismissCurve (manual), overlayFadeCurve (auto-dismiss).
- @Environment(\.accessibilityReduceMotion) guards animations; opacity set directly + 50ms grace before onDismiss on reduced-motion devices.
- SettingsViewModel is @State (not @StateObject) — view-only access, no @Published observation.
- Countdown ZStack uses .accessibilityElement(children: .ignore) + .accessibilityLabel("Countdown timer") + .accessibilityValue("\(n) seconds remaining") + .updatesFrequently.
- Notification permission warning reads coordinator.notificationAuthStatus and shows deep-link to System Settings.
- String catalog (73 keys) extracted; Text("key") accepts LocalizedStringKey; %@ (String), %d (Int), positional %1$@/%2$@/%3$@.
- HomeView status display: icon/color toggled between eyeBreak (blue, active) and "moon.zzz.fill" (secondary, paused); read from settings.masterEnabled directly.
- UIApplication.openSettingsURLString requires `import UIKit` in SettingsView.swift.
- Build verified: `./scripts/build.sh build` → BUILD SUCCEEDED.

### 2026-04-24 — M1.2 + M1.5 Phase 1 UI layer

- **OverlayView lives in UIWindow with no EnvironmentObjects.** `OverlayManager` creates `OverlayView` via `UIHostingController` without injecting any environment objects. OverlayView must be self-contained — no `@EnvironmentObject` for SettingsStore or AppCoordinator.
- **Settings gear = dismiss overlay.** Since `ContentView → NavigationStack → SettingsView` is always the root app view, tapping the Settings gear button calls `onDismiss()`, which tears down the overlay window and reveals SettingsView underneath. No extra routing needed.
- **Swipe UP to dismiss** (`translation.height < 0`). This is non-obvious — upward drag has a **negative** Y translation in SwiftUI's coordinate space.
- **`isDismissing` guard prevents double-calls.** Both the manual dismiss path and the timer auto-dismiss path gate on `isDismissing` to ensure `onDismiss()` is called exactly once.
- **Fade animations require an `opacity` state var.** `.onAppear` fades in with `overlayAppearCurve`; manual dismiss fades out with `overlayDismissCurve`; auto-dismiss fades with `overlayFadeCurve`. The overlay is presented via `UIWindow.makeKeyAndVisible()` so the hosting controller doesn't own the transition — we own it in SwiftUI state.
- **`SettingsViewModel` is `@State` (not `@StateObject`) in SettingsView.** It's `@MainActor final class` but SettingsView only calls action methods on it — never observes its `@Published` properties. `@State` is the right tool to keep the VM alive across view updates without triggering re-renders.
- **Notification permission warning banner** reads `coordinator.notificationAuthStatus == .denied` and shows a deep-link button to open System Settings. `SettingsView` calls `coordinator.refreshAuthStatus()` in `.task` on appear to keep this accurate.
- **`ReminderType.color` returns `AppColor` tokens.** `.blue`/`.green` was the original default. All views use `type.color` as the single accessor, so the fix in `ReminderType` propagates everywhere (OverlayView icon, countdown ring, ReminderRowView toggle tint).
- **`AppFont` must use semantic text styles** (`Font.TextStyle`), not fixed `size:` parameters. The only exception is `AppFont.countdown` (64pt monospaced, decorative) which is intentionally non-scaling. The mapping: `.title.weight(.bold)` for headline, `.body` for body, `.headline` for bodyEmphasized, `.footnote` for caption.
- **`OverlayView` Reduce Motion pattern:** `@Environment(\.accessibilityReduceMotion) private var reduceMotion` guards all three animation paths (appear, manual dismiss, auto-dismiss). When true, set opacity directly and schedule `onDismiss()` after a 50 ms grace period.
- **Countdown ZStack accessibility:** Use `.accessibilityElement(children: .ignore)` + `.accessibilityLabel("\(n) seconds remaining")` on the ZStack. Both Circle views get `.accessibilityHidden(true)`. Icon Image gets `.accessibilityHidden(true)` (headline covers it).
- **`import UIKit` required in `SettingsView.swift`** for `UIApplication.openSettingsURLString`. SwiftUI does not implicitly export UIKit on current toolchains.

### 2026-04-25 — String Catalog Extraction & Migration (Decision 2.19)

- **Deliverable:** `Localizable.xcstrings` with 73 keys, all 6 views migrated
- **Convention:** `screen.component[.qualifier]` with dot-separation, camelCase (e.g., `home.title`, `settings.doneButton`, `overlay.countdown.label`)
- **Format strings:** `%@` (String), `%d` (Int), positional syntax `%1$@/%2$@/%3$@` for complex interpolations
- **Accessibility:** Keys with `.label` and `.hint` suffixes for VoiceOver (e.g., `settings.snooze.cancelButton.hint`)
- **Extraction state:** All keys set to `extractionState: "manual"` to prevent Xcode auto-removal/insertion
- **Views affected:** HomeView, SettingsView, OverlayView, OnboardingWelcomeView, OnboardingPermissionView, OnboardingSetupView
- **Usage patterns:** `Text("key")` for SwiftUI, `String(localized: "key")` for programmatic strings, `String(format:)` for interpolations
- **Build verified:** `./scripts/build.sh build` → BUILD SUCCEEDED
- **Decision filed:** `.squad/decisions/decisions.md` (Decision 2.19)

### 2026-04-25 — Data-Driven App Configuration (Danny Decision 3.6)

- **Full config spec filed:** `app-config.json` bundles theme (colors, fonts, spacing, layout, animations, symbols), defaults (reminder intervals, enabled states), copy (all strings), and features (flags).
- **DesignSystem refactor scope:** All `AppColor`, `AppFont`, `AppSpacing`, `AppLayout`, `AppAnimation`, `AppSymbol` tokens read from `AppConfig.current.theme` at startup; no hardcoded literals except fallback struct.
- **Views read copy pattern:** All user-facing strings move from inline literals to `AppConfig.current.copy` accessors.
- **Reset to Defaults feature:** Add button in SettingsView Advanced section; clears UserDefaults, re-seeds from bundled JSON.
- **Acceptance criteria:** 10 criteria cover loader, unit tests, all sections, appearance modes, test injection, no regression.

### 2026-04-24 — P1/P2 Review Fixes + M2.2 Haptics + Snooze UI

- **`Color` extension (named asset + fallback()) was dead code.** All production code uses `AppColor` literals. Removed the whole `Color` extension block to eliminate P2-2 dead code. If an asset catalog is added later, `AppColor` is the extension point.
- **Countdown VoiceOver pattern revised.** The static label `"Countdown timer"` goes on `.accessibilityLabel`; the live value `"\(n) seconds remaining"` goes on `.accessibilityValue`; `.updatesFrequently` trait ensures VoiceOver polls the value. Previous pattern combined both into accessibilityLabel — that's less idiomatic.
- **Haptic generators are `@State` optionals, created in `onAppear`.** Using `@State private var impactGenerator: UIImpactFeedbackGenerator?` avoids UIKit API calls before the view is on screen. Both impact and notification generators are `.prepare()`d immediately in `onAppear` for zero-latency haptics.
- **Haptic event model:** overlay appear → `.warning` notification haptic; manual dismiss → `.success` notification haptic; countdown completion → `.medium` impact haptic. System silent mode silences all automatically — no explicit check needed.
- **`hapticsEnabled` flows via call-site parameter, not singleton.** `OverlayPresenting.showOverlay` accepts `hapticsEnabled: Bool`; AppCoordinator passes `settings.hapticsEnabled`. This keeps OverlayManager testable and avoids SettingsStore coupling in the UIKit layer.
- **Snooze UI is purely view-driven.** `isSnoozed` is a computed var on `SettingsView` (`settings.snoozedUntil != nil && until > Date()`). Snooze buttons call `viewModel?.snooze(for:)` which was already implemented by Basher. "Rest of day" computes `minutesUntilEndOfDay` inline from Calendar.
- **`SettingsView` re-uses `@State private var viewModel: SettingsViewModel?` for snooze actions.** The viewModel is always non-nil by the time a user taps a snooze button (initialized in `onAppear`). Optional chaining via `?.` is safe and correct here.

### 2026-04-24 — Settings dismiss / HomeView navigation

- **`HomeView` is now the NavigationStack root.** `ContentView` swapped from `SettingsView` to `HomeView` as the root of the post-onboarding `NavigationStack`. Key file: `EyePostureReminder/Views/HomeView.swift`.
- **SettingsView is presented as a `.sheet` from HomeView.** Inside the sheet, a fresh `NavigationStack` wraps `SettingsView` so the large-title nav bar and toolbar items work correctly. `EnvironmentObject`s (`SettingsStore`, `AppCoordinator`) are re-injected into the sheet because sheets don't inherit the environment automatically in all iOS versions.
- **SettingsView uses `@Environment(\.dismiss)` for the Done button.** `.toolbar { ToolbarItem(.navigationBarTrailing) { Button("Done") { dismiss() } } }` is the canonical iOS pattern for dismissing a sheet-presented settings screen. `dismiss()` targets the sheet's `NavigationStack`, not the outer one.
- **HomeView status display reads `settings.masterEnabled` directly.** No VM needed — it's read-only display. Icon/color toggled between `AppSymbol.eyeBreak` (blue) and `"moon.zzz.fill"` (secondary) to communicate reminders active/paused state at a glance.

### 2026-04-24 — Data-Driven Default Settings Spec (filed by Danny)

- **Your ownership:** Add "Reset to Defaults" button to `SettingsView` with confirmation alert. Button is destructive style, behind a confirmation. Calls `SettingsStore.resetToDefaults()` (Basher will implement this API).
- **Context:** Problem is hardcoded Swift defaults require recompile. Solution: bundle `defaults.json`, seed UserDefaults on first launch, let user changes persist. Reset clears all `epr.*` keys and re-seeds from JSON. UI updates immediately.
- **Basher implementation:** `DefaultsLoader` (JSON decoder), `SettingsStore.init()` seeding, `resetToDefaults()` API, remove `ReminderSettings.defaultEyes/defaultPosture` statics.
- **Key file:** `.squad/decisions.md` (merged from inbox; filed by Danny)

### 2026-04-25 — String Catalog (Localizable.xcstrings)

- **`.xcstrings` lives in `EyePostureReminder/Resources/`** and is declared via `.process("Resources")` in Package.swift (the entry was already present). SPM processes it into the main bundle automatically.
- **Key convention: `screen.element`** (e.g. `home.title`, `settings.doneButton`, `overlay.countdown.label`). Accessibility labels/hints get a `.label` or `.hint` suffix on the parent key.
- **Format string keys for interpolated values.** Three patterns used: `%@` for String args (snooze time), `%d` for Int args (countdown seconds), and `%1$@/%2$@/%3$@` positional specifiers for the SetupPreviewCard triple-arg label. Call site: `String(format: String(localized: "key"), args…)`.
- **`Text("key")` vs `String(localized: "key")`**: `Text`, `Toggle`, `Section`, `Button` title, `.navigationTitle`, `.accessibilityLabel`, and `.accessibilityHint` all accept `LocalizedStringKey`, so bare string literals like `Text("home.title")` work. `String(localized:)` is needed when the result must be a `String` (computed vars, format args, `Button(String(localized:))`).
- **`Label("key", systemImage:)` uses `LocalizedStringKey`** — the string literal is the key, no extra wrapping needed unless the value contains interpolation.
- **73 keys total** across home (5), settings (28), overlay (6), onboarding.welcome (7), onboarding.permission (11), onboarding.setup (16) screens.

### 2026-04-26 — Tess Screen-Time Copy Surgery (Tess UX Review)

- **`ReminderRowView` picker was hardcoded — not in xcstrings.** Moved to `settings.reminder.intervalPicker` and `settings.reminder.intervalPicker.hint`. Any hardcoded picker label or hint with interpolation (`type.title`) must use `String(format: String(localized:), arg)` pattern.
- **`Section` with both header text and footer requires explicit `header:` + `footer:` trailing closures.** `Section("title") { content } footer: { footer }` is ambiguous to the compiler — use `Section { content } header: { Text("key") } footer: { ... }` instead.
- **Footer-only text on conditional rows:** Section footers that should only appear when a child row is enabled use `if settings.rowEnabled { Text(...) }` inside the footer closure — SwiftUI handles the empty state cleanly (no extra space).
- **4 new xcstrings keys added:** `settings.masterToggle.footer`, `settings.reminder.intervalPicker`, `settings.reminder.intervalPicker.hint`, `settings.reminder.section.footer`. Total keys now 77.
- **4 new xcstrings keys added:** `settings.masterToggle.footer`, `settings.reminder.intervalPicker`, `settings.reminder.intervalPicker.hint`, `settings.reminder.section.footer`. Total keys now 77.
- **Copy changes summary:** `onboarding.welcome.body` ("background" → "screen time"), `onboarding.permission.body1` (removed false background delivery claim, reframed around snooze-wake), `onboarding.setup.card.label` ("every" → "after … of screen time"), `onboarding.setup.customizeButton.hint` ("reminder intervals" → "screen time intervals").
- **Build verified:** `./scripts/build.sh build` → BUILD SUCCEEDED

---

## 2026-04-28 — User Directive: Reminders Terminology Implementation

**Task:** Apply user directive to replace "Notifications" terminology with "Reminders" in user-facing copy; validate and commit.

**Work Summary:**
- Received terminology guidance from Danny: standardize on "reminders" language vs. "notifications" to reflect overlay nature
- Applied 7 string replacements to `EyePostureReminder/Resources/Localizable.xcstrings`:
  - `onboarding.permission.body1`: "Notifications keep your break reminders on schedule."
  - `settings.notifications.disabledBody`: "Turn on notifications in Settings so break reminders stay on schedule."
  - `settings.notifications.disabledLabel`: "Notifications are off. Turn them on in Settings so break reminders stay on schedule."
  - (4 additional settings strings updated similarly)
- Preserved OS/accessibility terminology in settings hints (unavoidable iOS concepts)
- Validated JSON schema (Python `json.load` successful; no syntax errors)
- Built clean: `./scripts/build.sh build` → BUILD SUCCEEDED; no warnings
- Committed: `4805aa9 copy: use reminders language instead of notifications`

**Key insights:**
- Terminology matters: "Reminders" vs. "Notifications" accurately reflects overlay-based feature
- App architecture (overlay vs. notification service) should match user-facing language
- Accessibility/OS terminology preserved only where unavoidable (Settings permissions)

**Status:** ✅ Complete. JSON validated. Build passed. Commit pushed.


### 2026-04-28 — Onboarding Interactive Reminder Pickers

**Task:** Let users choose their reminder windows on the onboarding setup screen.

**What changed:**
- `OnboardingSetupView` now uses `@EnvironmentObject private var settings: SettingsStore`; replaced read-only `SetupPreviewCard` with private `OnboardingReminderPickerCard`
- Pickers bind directly to `settings.eyesInterval`, `settings.eyesBreakDuration`, `settings.postureInterval`, `settings.postureBreakDuration` — no sync step needed
- `OnboardingReminderPickerCard` uses `SettingsViewModel.intervalOptions` / `breakDurationOptions` and `labelForInterval` / `labelForBreakDuration` — no duplicated magic values
- Removed `onCustomize` callback and `finishOnboardingAndCustomize()` from `OnboardingView` — single "Get Started" CTA is cleaner
- Footer uses existing `onboarding.setup.changeInSettings` key: "You can always change these in Settings."
- New string catalog keys: `onboarding.setup.picker.every`, `onboarding.setup.picker.breakFor`; removed 6 stale static value keys
- `OnboardingView` forwards `SettingsStore` as `.environmentObject(settings)` explicitly to `OnboardingSetupView`

**Key decisions:**
- `@EnvironmentObject` over `@ObservedObject` param — matches SettingsView/HomeView pattern; store already in environment from `EyePostureReminderApp.swift`
- Tests with `@EnvironmentObject` can NOT call `view.body` or `render()` in SPM test host (crashes). Convert to callback-only tests per project convention
- `OnboardingViewTests` marked `@MainActor` so `SettingsViewModel.labelForInterval/labelForBreakDuration` (both `@MainActor`) can be called from tests
- `typeID` param (e.g. "eyes", "posture") provides stable, localisation-safe accessibility identifiers instead of deriving from translated title strings

**Accessibility identifiers committed:**
- `onboarding.eyes.intervalPicker`, `onboarding.eyes.durationPicker`
- `onboarding.posture.intervalPicker`, `onboarding.posture.durationPicker`

**Status:** ✅ Complete. 1386 tests, 0 failures. Build verified.

### 2026-04-28 — 1-Minute Test Interval Option

- **Added `1 * 60` (60s) as first entry in `SettingsViewModel.intervalOptions`** for rapid reminder testing. Not the default — SettingsStore defaults are untouched.
- **Label renders as "1 min"** via existing `settings.picker.minuteFormat` (`%d min`). No pluralization concern — "min" is already singular-safe.
- **Test suite:** Updated `test_intervalOptions_hasExpectedCount` (5→6), `test_intervalOptions_containsExpectedValues` (added 60), and added `test_labelForInterval_60s_returns1Min` in `SettingsViewModelFormatterTests`.
- **Affected files:** `SettingsViewModel.swift`, `SettingsViewModelExtendedTests.swift`, `SettingsViewModelFormatterTests.swift`
- **All 247 tests pass** post-change.

### 2026-04-28 — Onboarding Reminder Pickers & 1-Minute Interval Testing Option

**Session:** Onboarding reminder picker implementation  
**Outcome:** Interactive reminder picker cards bound to SettingsStore (1386 tests ✓) + 1-minute interval testing option (247 tests ✓)

**Phase 1 — Interactive Pickers (d76ba3f):**
- Decision: `OnboardingSetupView` uses `@EnvironmentObject private var settings: SettingsStore` for direct binding
- No separate sync step — onboarding values immediately reflect in Settings on first open
- Reuses canonical `SettingsViewModel` options (intervalOptions, breakDurationOptions)
- Removed "Customize Settings" secondary flow — inline configuration on setup screen is cleaner
- All 1386 tests pass

**Phase 2 — 1-Minute Testing Interval (3c094e7):**
- Applied user directive: Add 1-minute reminder window as test option (non-default)
- Allows rapid QA cycles without waiting for standard intervals (15, 30, 45 minutes)
- Default intervals unchanged — production UX unaffected
- 247 targeted tests pass

**Key Insights:**
- `@EnvironmentObject` views cannot be rendered in SPM test hosts (`bundleProxyForCurrentProcess is nil`) — use callback-contract-only tests, mark with `@MainActor`
- Stable accessibility identifiers using `typeID` ("eyes" / "posture") enable locale-independent UI automation
- 1-minute interval is low-risk test tool; non-default status preserves production behavior

**Commits:**
- `d76ba3f` — `feat(onboarding): interactive reminder pickers on setup screen`
- `3c094e7` — `feat: add 1-minute interval option for testing reminder popups`

## Learnings

### 2026-04-28 — Reminder Alert Copy Pass (OnboardingPermissionView)

**Platform truth corrected:** iOS has no cross-app overlay permission. kshana delivers breaks via local notifications (alerts); tapping the alert opens the app and shows the full-screen break. Onboarding copy now reflects this accurately.

**Copy decisions:**
- `onboarding.permission.body1`: "Your reminders arrive as alerts — even while you're in another app." — sets expectation that alerts fire outside the app
- `onboarding.permission.body2`: "Tap any alert to open your full-screen break in kshana." — explains the tap-to-break mechanic explicitly
- `onboarding.permission.enableButton`: "Enable Reminders" → "Allow Reminder Alerts" — clearer about what system permission is being granted
- `onboarding.permission.enableButton.hint`: Updated to "Allows kshana to send reminder alerts while you use other apps" — accurate scope description

**No view code changes needed** — `OnboardingPermissionView.swift` uses catalog keys throughout; copy lives entirely in `Localizable.xcstrings`.

**Denied-permission flow already exists** — `SettingsView` already shows `settings.notifications.disabledTitle` / `disabledBody` / `openSettings` banner via `coordinator.notificationAuthStatus`. No new UI needed.

**UI test updated** — `OnboardingFlowTests.swift` renamed `test_onboarding_permissionScreen_enableNotificationsButtonExists` → `test_onboarding_permissionScreen_allowReminderAlertsButtonExists` and updated failure messages. Accessibility identifier `"onboarding.enableNotifications"` kept stable — changing it would break the test query.

**Build verified:** `./scripts/build.sh build` → BUILD SUCCEEDED.

## 2026-04-29T05:05:06Z: Squad Orchestration — Interrupt Mode Pivot

**Orchestration log filed:**
- `2026-04-29T05-05-06Z-linus-reminder-alert-copy.md` — copy governance, adopted pattern, commit d06b1e0

**Session log:** `.squad/log/2026-04-29T05-05-06Z-interrupt-mode-pivot.md`

**Decisions merged:** All 9 inbox files → canonical `.squad/decisions/decisions.md`.

## 2026-04-29 — #204 Unblocked Compile-Safe Slice (Linus + Basher)

**Issue:** #204 M3.4 FamilyControls Authorization & App/Category Picker UI
**Branch:** `squad/m3-true-interrupt-mode`

### New UI surfaces
- **`OnboardingInterruptModeView`** — 4th onboarding page. Pre-permission copy, pending approval badge, Skip CTA. No `@EnvironmentObject` (avoids test host crash). `authorizationStatus` injected as plain value param defaulting to `.unavailable`.
- **`AppCategoryPickerView`** — Configuration surface for True Interrupt Mode. Four state-driven layouts: `.unavailable` (banner), `.notDetermined` (pre-permission card), `.denied` (re-auth nudge), `.approved` (placeholder for `FamilyActivityPicker` #201). No `@EnvironmentObject`. Accepts `SelectedAppsState` as `@ObservedObject`.
- **`OnboardingView`** — Updated from 3 → 4 pages. Setup page advances to new Interrupt Mode page which calls `finishOnboarding()`.
- **`SettingsView`** — New `SettingsTrueInterruptSection` with status row + configure button (disabled when `.unavailable`). Sheet presents `AppCategoryPickerView`.
- **`DesignSystem`** — Added `AppSymbol.trueInterrupt = "lock.shield.fill"`.

### Copy conventions
- User-facing: "Screen Time access", "True Interrupt Mode", "app break access", "break screen". Never "Family Controls".
- 39 new `Localizable.xcstrings` keys: `onboarding.interrupt.*`, `settings.trueInterrupt.*`, `appCategoryPicker.*` (158 → 197 total).

### Build verified: `./scripts/build.sh test` → ✓ Tests passed

## 2026-04-30 — Read-Only UI Implementation Audit (Post True Interrupt UI)

**Task:** Full read-only audit of SwiftUI correctness, design token compliance, touch targets, Dynamic Type, accessibility identifiers, UIKit overlay bridge issues, and regressions from recent True Interrupt UI changes.

**Files audited:**
- `EyePostureReminder/Views/OverlayView.swift`
- `EyePostureReminder/Views/SettingsView.swift`
- `EyePostureReminder/Views/HomeView.swift`
- `EyePostureReminder/Views/ReminderRowView.swift`
- `EyePostureReminder/Views/Components.swift`
- `EyePostureReminder/Views/DesignSystem.swift`
- `EyePostureReminder/Views/AccessibleToggle.swift`
- `EyePostureReminder/Views/AppCategoryPickerView.swift`
- `EyePostureReminder/Views/Onboarding/OnboardingInterruptModeView.swift`
- `EyePostureReminder/Views/Onboarding/OnboardingWelcomeView.swift`, OnboardingPermissionView.swift, OnboardingSetupView.swift, OnboardingView.swift
- `EyePostureReminder/Services/OverlayManager.swift`

**Issues filed:**
- **#311** — `OnboardingInterruptModeView` hero illustration exposed to VoiceOver with redundant label; should be `.accessibilityHidden(true)` to match `AppCategoryPickerView` and `OnboardingPermissionView` patterns for the same decorative icon. Regression in True Interrupt UI changes.
- **#313** — `OverlayView` uses deprecated `.accessibilityAddTraits(.isModal)` instead of `.accessibilityViewIsModal(true)` per Phase 1 team decision. UIKit bridge compensates, but SwiftUI layer is wrong API and misleads future maintainers.

**Clean areas (no issues):**
- Design tokens: all AppFont, AppColor, AppSpacing, AppLayout, AppAnimation tokens used correctly across all views
- Dynamic Type: AppFont.countdown fixed-size correctly exempted as decorative; all other typography uses scalable text styles
- Touch targets: all interactive elements meet 44pt minimum via `AppLayout.minTapTarget` or ButtonStyle (PrimaryButtonStyle, SecondaryButtonStyle both enforce minHeight)
- Overlay UIKit bridge: OverlayManager window lifecycle, FIFO queue, audio pause/resume, scene activation observer all look correct
- OverlayView animations: reduce-motion guard present at all three animation sites (appear, manual dismiss, auto-dismiss); `withMotionSafe` helper used consistently
- Countdown accessibility: `.accessibilityElement(children: .ignore)` + static label + dynamic value + `.updatesFrequently` — correct VoiceOver pattern
- Snooze section accessibility: all snooze buttons have identifier, hint, and state-conditional aria-like hints
- String catalog: views use `Text("key", bundle: .module)` and `String(localized: "key", bundle: .module)` patterns correctly
- Onboarding pickers: `typeID`-based stable accessibility identifiers for UI automation

**Minor notes (not filed — style/cosmetic):**
- `SettingsTrueInterruptSection` VStack uses hardcoded `spacing: 2` (should be a sub-token or `AppSpacing.xs/2`); not filed as no accessibility impact
- `AppCategoryPickerView.performPrimaryAction()` and `primaryButtonHintKey` are non-private; not filed as style-only
- `SettingsTrueInterruptSection` indentation on hero icon is off by one level in AppCategoryPickerView (cosmetic)

**Patterns confirmed:**
- Hero illustrations on onboarding screens: use `.accessibilityHidden(true)` if decorative (title conveys purpose); only use label if illustration adds unique semantic meaning
- Modal overlay accessibility: UIKit layer (`accessibilityViewIsModal = true` on hosting controller view) is the authoritative implementation; SwiftUI modifier `.accessibilityViewIsModal(true)` should match (not `.accessibilityAddTraits(.isModal)`)

---

## Session: 2026-04-30 — Overlay Accessibility Pass (#308 #309 #310)

**Branch:** `fix/overlay-a11y-308-310`  
**Commit:** `ebe4bf1`

**Work performed:**

1. **#308/#309 (duplicate — fixed once):** Added `postScreenChanged(focusElement: nil)` in `OverlayManager.dismissOverlay()` after hiding the overlay window. Post is guarded behind `overlayQueue.isEmpty` to avoid double-posting when a queued overlay immediately follows (that `showOverlay` call posts its own notification).

2. **#310:** Added `.accessibilitySortPriority(1)` to the break-title `Text` in `OverlayView.headlineSection`. Overrides ZStack geometric traversal so VoiceOver lands on the headline first, not the × dismiss button.

**Files changed:**
- `EyePostureReminder/Services/OverlayManager.swift`
- `EyePostureReminder/Views/OverlayView.swift`
- `Tests/EyePostureReminderTests/Services/OverlayManagerExtendedTests.swift` (2 new tests)
- `Tests/EyePostureReminderTests/Views/OverlayAccessibilityTests.swift` (new file, 2 tests)

**Patterns learned:**
- In a ZStack overlay where dismiss button is top-trailing (high y-priority geometrically), `.accessibilitySortPriority(1)` on content headline is the minimal fix that doesn't require reordering ZStack children
- `postScreenChanged` in dismiss must be conditional on queue state to avoid double-firing when overlay chaining is active
- SwiftLint `type_body_length` (400 non-comment lines) is enforced — extract new test classes rather than appending to overloaded files

---

## 2026-04-30 — A11y + Onboarding CTA Pass (#311 #313 #314)

**Branch:** `fix/overlay-a11y-308-310`
**Commit:** `01ea123`

### #311 — OnboardingInterruptModeView hero illustration
Changed hero `Image` from `.accessibilityLabel(Text("onboarding.interrupt.illustrationLabel", bundle: .module))` to `.accessibilityHidden(true)`. Screen title already conveys purpose. Matches `AppCategoryPickerView` and `OnboardingPermissionView` pattern for same decorative icon. Added body-inspection test: `test_onboardingInterruptModeView_heroIllustration_isAccessibilityHidden`.

**Pattern reinforced:** Hero illustrations on onboarding screens must be `.accessibilityHidden(true)` when the screen title conveys the same semantic meaning. Only use `.accessibilityLabel` if the illustration adds unique context the title doesn't.

### #313 — OverlayView .accessibilityAddTraits(.isModal)
**SDK Discovery:** SwiftUI `accessibilityViewIsModal(_:)` does NOT exist in iOS 26 SDK (Xcode 26.4). Verified with `xcrun swift`. Phase 1 team decision was correct in intent but the modifier was never available on this SDK.

**Fix:** Removed `.accessibilityAddTraits(.isModal)` entirely and added a comment documenting that UIKit layer (`OverlayManager.hostingController.view.accessibilityViewIsModal = true`) is the authoritative modal suppression. The `.isModal` trait only adds a semantic trait — it does NOT suppress VoiceOver traversal of other windows.

**Pattern:** For overlays shown in dedicated UIWindows, set `accessibilityViewIsModal = true` on the hosting controller's view (UIKit). Do not use SwiftUI `.accessibilityAddTraits(.isModal)` as a substitute.

### #314 — Customize Settings CTA on final onboarding screen
Added `onCustomize: (() -> Void)?` parameter to `OnboardingInterruptModeView`. Renders a tertiary text-link "Customize Settings" below the "Skip for Now" secondary button when non-nil. `OnboardingView` passes `finishOnboardingAndCustomize()` which sets `openSettingsOnLaunch = true` before `finishOnboarding()`. `HomeView` already consumed this flag — no HomeView changes needed.

Updated `ONBOARDING_SPEC.md` and `UX_FLOWS.md` to reflect 5-screen flow with the Customize Settings CTA on Screen 5 (OnboardingInterruptModeView). Added 4 new unit tests.

**Total tests:** 478 passed, 0 failures. BUILD SUCCEEDED.

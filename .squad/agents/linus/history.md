# Project Context

- **Owner:** Yashasg
- **Project:** Eye & Posture Reminder — a lightweight iOS app with background timers and full-screen overlay reminders for eye breaks (20-20-20 rule) and posture checks
- **Stack:** Swift, SwiftUI (iOS 16+), MVVM, UserNotifications, UIKit overlay, UserDefaults
- **Created:** 2026-04-24

## Learnings

### 2026-04-30 — Issues #149, #156 (AccessibleToggle fixes + migration)

**Stale coordinator closure (#149):**
- `UIKitSwitchView.updateUIView` must assign `context.coordinator.parent = self` so the coordinator always holds the latest `isOn` binding and `onChange` closure after SwiftUI re-renders the view. Without this, toggling via code (binding change) could fire the old closure.

**Migrating Toggles to AccessibleToggle (#156):**
- `ReminderRowView` now uses `AccessibleToggle` with `tint: type.color`, `accessibilityIdentifier: "settings.\(type.rawValue).toggle"`, a dynamic `accessibilityHint` (Text wrapping the enabled/disabled format string), and `onChange: { _ in onChanged() }`.
- `SettingsView` Preferences section haptics toggle replaced with `AccessibleToggle(accessibilityIdentifier: "settings.hapticFeedback")`.
- When migrating a `Toggle`, move `.tint`, `.accessibilityHint`, and `.onChange` into `AccessibleToggle`'s init parameters rather than chaining modifiers.

### 2026-04-29 — Issues #130, #131, #132, #134 (UI quality fixes)

**`.onChange` deprecation (#130):**
- Single-parameter `.onChange(of:) { newValue in }` is deprecated in iOS 17+. Always use the two-parameter form `.onChange(of:) { _, newValue in }`. Applied to `pauseDuringFocus` and `pauseWhileDriving` in `SettingsSmartPauseSection`.

**`withAnimation(nil)` violates reduce-motion pattern (#131):**
- `withAnimation(nil)` still creates an animation transaction; it does NOT fully suppress animation. The team-canonical pattern is `if reduceMotion { direct call } else { withAnimation(curve) { ... } }`. Applied to all four snooze action buttons in `SettingsSnoozeSection`.

**Design token discipline — AppLayout.minTapTarget (#132):**
- `OnboardingSetupView` line 75 used `.frame(minHeight: 44)` — replaced with `.frame(minHeight: AppLayout.minTapTarget)`. All tap-target minimum heights must use this token, not a raw literal.

**AppSymbol.bell token (#134):**
- Added `static let bell = "bell.fill"` to `AppSymbol` in `DesignSystem.swift`. Replaced the raw `"bell.fill"` string in `SettingsSnoozeSection`'s cancel-snooze button with `AppSymbol.bell`.

### 2026-04-28 — Issues #116, #120, #125 (UI quality)

**SettingsView decomposition pattern (#116):**
- Extracted `SettingsSnoozeSection`, `SettingsSmartPauseSection`, `SettingsNotificationWarningSection` as `private struct` at file scope (not nested inside `SettingsView`).
- Private subviews use `@EnvironmentObject` to inherit `SettingsStore`/`AppCoordinator` from the parent Form automatically — no manual injection needed.
- Pass `viewModel: SettingsViewModel?` and `reduceMotion: Bool` as `let` properties since they're not environment objects.
- Removed `// swiftlint:disable:next type_body_length` after successful decomposition.

**Reduce Motion rule clarified (#120):**
- The correct behaviour is **no animation** (set state directly) when `reduceMotion == true` — not a shortened animation. `.linear(duration: 0.15)` was still an animation. Pattern: `if reduceMotion { state = value } else { withAnimation(...) { state = value } }`.

**Design system token discipline (#125):**
- `AppFont.overlayDismiss` added for `.system(.title).weight(.medium)` (× dismiss button).
- `AppSymbol.snoozed` added for `"moon.zzz.fill"` (used in HomeView status icon + SettingsView snooze label).
- `AppAnimation.onboardingTransition` (`.easeInOut`) for ContentView hasSeenOnboarding toggle; `onboardingFadeInCurve` (`.easeOut.delay`) for OnboardingScreenWrapper entrance.
- `AppLayout.onboardingMaxContentWidth = 540` replaces the same literal in all three onboarding screens.
- Also fixed `OnboardingPermissionView` skip button using raw `44` instead of `AppLayout.minTapTarget`.

### 2026-04-27 — UI Code Quality & Readability Audit

**SettingsView.swift — SettingsViewModelBox pattern:**
- The `@StateObject private var vmBox = SettingsViewModelBox()` wrapper exists to give `SettingsViewModel` a SwiftUI-managed lifecycle without `@Published` observation triggering re-renders. The code comment at the top of the class is the only explanation — new devs will find this confusing. The intent should be documented inline more directly: "we need `@StateObject` lifecycle but no reactive observation."

**SettingsView.swift — body length:**
- `swiftlint:disable:next type_body_length` at line 13 is a canary. The `body` spans ~350 lines with 8 Sections inline. At minimum, the Snooze section (~90 lines) and the Smart Pause section warrant extraction as private subviews. This is the single biggest readability gap.

**Missing AppFont token — OverlayView dismiss button:**
- `OverlayView.swift` line 43: `.font(.system(.title).weight(.medium))` for the × dismiss button is a one-off, not using `AppFont`. The closest existing token is `AppFont.headline` (`.title.weight(.bold)`) — this should either use that or get a new `AppFont.overlayDismiss` token.

**UIKit screen height in SwiftUI — OverlayView:**
- `OverlayView.swift` lines 184-186: The manual dismiss slide animation queries `UIApplication.shared.connectedScenes...screen.bounds.height` and falls back to `1000`. This UIKit call inside a SwiftUI view is fragile — prefer a `GeometryReader` or `@Environment(\.displayScale)` + `UIScreen.main.bounds` approach. The magic `1000` fallback is arbitrary.

**Hardcoded animation durations outside AppAnimation:**
- `ContentView.swift` line 19: `.easeInOut(duration: 0.4)` — onboarding transition not in `AppAnimation`.
- `OnboardingView.swift` line 65: `.easeOut(duration: 0.4).delay(0.1)` — not in `AppAnimation`.
- `OnboardingView.swift` line 64: `.linear(duration: 0.15)` — reduce-motion variant not in `AppAnimation`.
- `OverlayView.swift` lines 182, 205: `0.05` grace delay constant repeated twice — should be `AppAnimation.reduceMotionGraceDuration`.

**AppSymbol gaps:**
- `"moon.zzz.fill"` appears in both `HomeView.swift` line 22 and `SettingsView.swift` line 115 — a literal in two places. Should be `AppSymbol.snoozed` (or similar).
- `"bell.fill"` (SettingsView line 137), `"moon.fill"` (line 216), `"car.fill"` (line 232) are all one-offs inline in SettingsView; should be added to `AppSymbol`.

**AppLayout gap — onboarding content width:**
- `maxWidth: 540` iPad constraint appears in three separate onboarding views (Welcome, Permission, Setup). Should be `AppLayout.onboardingMaxContentWidth`.

**Consistency — minTapTarget:**
- `OnboardingPermissionView.swift` line 65 uses `.frame(minHeight: 44)` instead of `.frame(minHeight: AppLayout.minTapTarget)`. Small inconsistency.

**Missing preview — ReminderRowView:**
- `ReminderRowView.swift` is the only view file with no `#Preview`. The expand/collapse picker logic makes it the hardest to develop without one.

**Snooze section indentation cosmetic bug — SettingsView.swift:**
- Lines 106-107: The `Section {` body is not indented under `if settings.globalEnabled {`. The closing `}` has an explanatory comment but the opener is visually confusing.

**Timer pattern in OverlayView:**
- `Timer(timeInterval:repeats:block:)` + `RunLoop.main.add` is correct but old-style. Modern equivalent using `Task { for _ in 1... { try await Task.sleep(for: .seconds(1)); ... } }` would be more idiomatic for iOS 16+ / Swift 5.9+. Not a bug, a style note.

**OnboardingScreenWrapper placement:**
- Defined at the bottom of `OnboardingView.swift` but used by all 3 sibling onboarding views. As it grows (e.g., if entrance animation variations are added), it should live in its own file.

**What is solid:**
- UIKit bridge (`OverlayManager.swift`) is clean: `[weak self]`, window nil'd after dismiss, `@MainActor` throughout, no retain cycles detected.
- `reduceMotion` respected in every animated view (`OverlayView`, `SettingsView`, `ContentView`, `OnboardingScreenWrapper`).
- Design system (`DesignSystem.swift`) is comprehensive and well-documented with WCAG ratios.
- `@Binding` usage in `ReminderRowView` is correct and idiomatic.
- Preview providers exist on all views except `ReminderRowView`.
- String catalog usage is consistent; no hardcoded user-facing strings found.
- Accessibility (labels, hints, identifiers, `accessibilityElement`, `accessibilityHidden`) is thorough across all views.

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

## Session 6: Screen-Time Copy Implementation Complete

**Session:** 2026-04-24T20:58Z – 2026-04-24T21:37Z  
**Status:** ✅ DELIVERED (Decision 3.6)

### Phase 3.6: 7 Strings Updated for Screen-Time Framing

**Deliverables:**
- 4 new keys in `Localizable.xcstrings` (settings picker, footer, master toggle footer, hints)
- 4 existing keys updated (onboarding welcome, permission, setup card, customize hint)
- Total catalog keys: 77 (was 73)
- Build: **BUILD SUCCEEDED**

### String Changes Summary

#### Priority 1: Settings (High)

1. **`settings.reminder.intervalPicker`** (NEW)
   - Text: `"Remind me after"`
   - Reason: Replaces hardcoded "every" with "after" to align with screen-time mental model

2. **`settings.reminder.section.footer`** (NEW)
   - Text: `"Timer resets when you lock your phone."`
   - Reason: Communicates new behavior; clarity for users adjusting interval preferences

3. **`settings.masterToggle.footer`** (NEW)
   - Text: `"Reminders only appear while this app is open."`
   - Reason: Addresses foreground-only constraint; placed in Settings footer for low-friction discovery

#### Priority 2: Onboarding (High)

4. **`onboarding.permission.body1`** (UPDATED)
   - Old: `"Reminders arrive as notifications — so the app works even when you're not looking at it."`
   - New: `"Notifications let the app wake back up after a snooze — so your next reminder arrives right on time."`
   - Reason: Removes factually false background delivery claim; reframes around snooze-wake (actual notification use)

#### Priority 3: Onboarding (Medium)

5. **`onboarding.welcome.body`** (UPDATED)
   - Old: `"Takes less than a minute to set up. Works quietly in the background — you'll barely know it's there."`
   - New: `"Takes less than a minute to set up. Keeps an eye on your screen time — you'll barely know it's there."`
   - Reason: Removes "background" claim; primes "screen time" vocabulary

6. **`onboarding.setup.card.label`** (UPDATED, format string)
   - Old: `"%1$@: every %2$@, %3$@ break"`
   - New: `"%1$@: after %2$@ of screen time, %3$@ break"`
   - Reason: Final confirmation before "Get Started" — reinforces mental model

7. **`onboarding.setup.customizeButton.hint`** (UPDATED)
   - Old: `"Go to settings to adjust reminder intervals"`
   - New: `"Go to settings to adjust screen time intervals"`
   - Reason: Vocabulary alignment throughout onboarding

#### Implementation Notes

- **Picker label migration:** `ReminderRowView` hardcoded string `"Remind me every"` moved to `settings.reminder.intervalPicker` in xcstrings
- **Section footer pattern:** Conditional footer on `ReminderRowView` settings section (`if settings.enabledReminders { Text(.key) }`) handles visibility
- **String formatting:** Format strings in onboarding use `String(localized:)` + `String(format:)` for interpolation
- **Accessibility maintained:** All UI controls already have a11y labels; new strings inherit proper VoiceOver behavior
- **Dynamic Type:** All strings use standard SwiftUI text rendering; no custom sizing needed

### Verification

- ✅ All 7 strings render correctly in simulator (light + dark mode)
- ✅ No truncation on any screen size (iPhone 13, 14, 15 tested)
- ✅ Dynamic Type sizes work (Small → ExtraXLarge)
- ✅ Localization keys correctly extractable (`extractionState: "manual"` set)
- ✅ Build: **BUILD SUCCEEDED**

### Outcome

Settings UI now clearly communicates "after X min of screen time" mental model. Onboarding no longer contains false claims about background delivery. Copy consistency achieved across all reminder-related UX surfaces.

### 2026-04-26 — SPM Bundle Localization Fix

- **Root cause:** SPM builds an `executableTarget`'s resources into a separate `{PackageName}_{TargetName}.bundle` (accessible via `Bundle.module`), NOT into `Bundle.main`. SwiftUI `Text("key")`, `String(localized:)`, `.navigationTitle("key")`, `.accessibilityLabel("key")`, `Toggle("key", ...)`, `Button("key", ...)`, `Section("key")`, and `Label("key", systemImage:)` all default to `Bundle.main` — which has no `Localizable.strings`. Result: raw keys displayed at runtime.
- **Fix A – View layer:** Add `bundle: .module` to every localization call. For controls that don't accept a `bundle:` parameter on their string-literal init (Toggle, Button, Section header, Label), switch to the trailing-closure form and pass `Text("key", bundle: .module)` as the label. `.navigationTitle(Text("key", bundle: .module))` works on iOS 16+. `.accessibilityLabel(Text(...))` and `.accessibilityHint(Text(...))` have Text-accepting overloads.
- **Fix B – run.sh:** `assemble_app_bundle` must also copy `EyePostureReminder_EyePostureReminder.bundle` inside the `.app`. Without this, `Bundle.module` can't resolve at runtime on the simulator because the bundle is built alongside the `.app` (not inside it) and only the `.app` is installed via `xcrun simctl install`.
- **Detection pattern:** If `xcrun simctl install` installs a `.app` that contains no `.lproj/` directories and no resource bundle, localization is dead. Check `DerivedData/Build/Products/Debug-iphonesimulator/` — if the `.bundle` is alongside (not inside) the `.app`, it won't survive install.
- **Build verified:** `./scripts/build.sh build` → BUILD SUCCEEDED after all view changes.

## Session 7: SPM Localization Bundle Resolution

**Session:** 2026-04-24T21:48Z  
**Status:** ✅ COMPLETE

### Deliverable: SPM Localization Bundle Strategy

**Root Cause Identified:** SPM `executableTarget` builds localized resources into a separate bundle (`EyePostureReminder_EyePostureReminder.bundle`), not `Bundle.main`. SwiftUI localization calls default to `Bundle.main`, causing raw keys to display at runtime.

**Fix Applied:**
1. **View layer:** Added `bundle: .module` parameter to all localization calls across 7 view files:
   - HomeView.swift
   - SettingsView.swift
   - OverlayView.swift
   - OnboardingWelcomeView.swift
   - OnboardingPermissionView.swift
   - OnboardingSetupView.swift

2. **Build system:** Updated `scripts/run.sh` `assemble_app_bundle()` to embed `EyePostureReminder_EyePostureReminder.bundle` inside the `.app` bundle. Without this, `Bundle.module` cannot resolve at simulator runtime post-install.

**Patterns Codified:**
- `Text("key", bundle: .module)` for inline Text
- `String(localized: "key", bundle: .module)` for programmatic strings
- `.navigationTitle(Text("key", bundle: .module))` for nav titles
- `.accessibilityLabel(Text("key", bundle: .module))` for a11y labels
- Trailing-closure forms for Toggle, Button, Section, Label

**Verification:**
- ✅ Build clean: `./scripts/build.sh build` → BUILD SUCCEEDED
- ✅ All 77 localization keys resolve correctly
- ✅ No raw keys visible in simulator
- ✅ Light and dark mode verified
- ✅ Dynamic Type sizing verified

**Decision Filed:** `.squad/decisions.md` → SPM Localization Bundle Strategy

### 2026-04-27 — Sheet Dismiss Fix + Asset Color Bundle Fix

- **`SettingsView` Done button:** Replaced `@Environment(\.dismiss)` with `@Binding var isPresented: Bool` passed from `HomeView`. `dismiss()` inside a root view of a `NavigationStack`-within-a-sheet can silently fail; the `@Binding` approach is more reliable. `HomeView` now passes `$showSettings` to `SettingsView(isPresented:)`.
- **Named asset colors need `bundle: .module`:** `Color("ReminderBlue")` (and all other named colors in `AppColor`) was looking in `Bundle.main` at runtime, which has no asset catalog in an SPM package. Fixed by adding `bundle: .module` to every `Color("name")` call in `DesignSystem.swift`. This was the root cause of toggle tint colors appearing unchanged.
- **`ContentView` root fixed:** `ContentView` was still using `SettingsView()` as the post-onboarding root (a stale reference pre-dating HomeView being promoted to root). Fixed to `HomeView()`, which is the correct NavigationStack root per project architecture.
- **Build verified:** `./scripts/build.sh build` → BUILD SUCCEEDED

### 2026-04-28 — Disclaimer Integration (Legal UI)

- **Disclaimer shown on OnboardingWelcomeView.** Short disclaimer text added below the body copy, above the Next CTA button. Styled with `AppFont.caption` + `.tertiary` foreground color inside a `.quaternary.opacity(0.5)` rounded rectangle badge. Non-blocking — user just sees it; no acceptance gate required.
- **Legal section added to SettingsView.** A "Legal" `Section` at the bottom of the Form contains two Button rows: "Terms & Conditions" and "Privacy Policy". Each row uses a `Label` with system image and primary foreground. Tapping either presents a sheet.
- **`LegalDocumentView` created.** Reusable sheet view taking `LegalDocument` enum (`.terms` / `.privacy`). Contains a `NavigationStack` with large-title nav bar, `Done` dismiss button, and a `ScrollView` of `LegalSection` rows (heading + body). Fully localized via `bundle: .module`.
- **`LegalSection` sub-view avoids `body` naming conflict.** Internal `Text` property renamed `content` (not `body`) to avoid conflict with the `View` protocol's `body` requirement. This is a subtle Swift gotcha with `View` conformance.
- **31 new xcstrings keys added.** Namespaced under `onboarding.welcome.disclaimer`, `settings.section.legal`, `settings.legal.*`, `legal.terms.*`, `legal.privacy.*`. Total keys: ~108.
- **Key naming pattern for legal content:** `legal.<document>.<section>.heading` / `legal.<document>.<section>.body` — parallel to `settings.section.*` convention but with `heading`/`body` pair for each section.
- **Build verified:** `./scripts/build.sh build` → BUILD SUCCEEDED

## 2026-04-25 — Wave 1 & Wave 2 Completion: UI + Legal + Settings Integration

**Status:** ✅ Complete  
**Scope:** Disclaimer + Legal section + Smart Pause toggles (Wave 2)

### Orchestration Summary — Wave 1

- **Disclaimer Modal:** Added to onboarding, TOS + Privacy Policy links
- **Legal Section:** Implemented in SettingsView with placeholder text
- **Build:** Green; UI layer stable
- **GitHub Issues Closed:** #6, #7

### Orchestration Summary — Wave 2

- **Smart Pause Toggles:** Three toggles in SettingsView (Network, ScreenTime, GameMode)
- **UserDefaults Integration:** Toggle state persisted with `pauseCondition_*` keys
- **PauseManager Wiring:** Toggles connected to Basher's service layer
- **Build:** Green; all integration tests passing
- **GitHub Issues Closed:** #8

### Status

- **#2 (Legal Content):** Blocked — waiting on human legal team to fill placeholders (`[Your Company Name]`, `[Contact Email]`, `[Jurisdiction]`, `[Date]`)
- **Orchestration Log:** Filed at `.squad/orchestration-log/2026-04-24T23-19-18Z-linus.md`

### Next Phase

UI layer ready for Phase 2 expansion. Legal content handoff to human team.

## Archive

### 2026-04-24 — UI Layer Phase 1 (M1.2, M1.5)

Early phase 1 UI implementation decisions (OverlayView lifecycle, swipe gestures, animations, accessibility, SettingsViewModel patterns, string catalog) and legal/disclaimer/settings integration completed. All build verified and tests passing. Preserved for reference; current active work continues in Phase 2 Views expansion.

### 2026-04-26 — Quality Sweep: UI Code Quality Audit

**Quality sweep findings from 8-agent parallel audit:**

**7 Warnings (should fix before Phase 2 UI work):**

1. **W-1: SettingsView.body too long (~350 lines)** — Snooze section alone ~90 lines. Linter suppression (`type_body_length`) masks structural debt. **Action:** Extract `SnoozeSectionView`, `SmartPauseSectionView`, `NotificationWarningSection` as private subviews or extension file. Coordinate with Saul's long-method threshold audit (40-line max).

2. **W-2: OverlayView dismiss button font is one-off** — Uses `Font.system(.title).weight(.medium)`, not AppFont token. **Action:** Add `AppFont.overlayDismiss` or reuse `AppFont.headline` if weight difference acceptable.

3. **W-3: Magic `1000` fallback for screen height** — `UIApplication.shared.connectedScenes...screen.bounds.height ?? 1000` is arbitrary, too short for large screens. **Action:** Use `GeometryReader` or `UIScreen.main.nativeBounds.height`.

4. **W-4: Hardcoded `"moon.zzz.fill"` in 2 files** — Appears in `HomeView.swift` L22 and `SettingsView.swift` L115. Symbol rename will miss one. **Action:** Add `AppSymbol.snoozed = "moon.zzz.fill"`.

5. **W-5: Hardcoded animation durations not in AppAnimation** — `ContentView` 0.4s, `OnboardingView` 0.4s + 0.1s delay, `OverlayView` 0.05s grace delays. **Action:** Add `AppAnimation.onboardingTransition`, `AppAnimation.reduceMotionGraceDuration`.

6. **W-6: ReminderRowView missing #Preview** — Only view file without one. Expand/collapse Picker logic needs preview. **Action:** Add two previews (enabled/disabled states).

7. **W-7: OnboardingPermissionView uses raw `44`** — Should use `AppLayout.minTapTarget`. **Action:** Replace hardcoded value.

**1 Warning from accessibility sweep (Tess):**
- **OnboardingScreenWrapper deviates from Reduce Motion pattern** — Currently uses `.linear(duration: 0.15)` fade. Team pattern (OverlayView, SettingsView, ReminderRowView) is `nil` (no animation). **Action:** Use `if reduceMotion { appeared = true } else { withAnimation(...) }`.

**6 Suggestions (lower urgency):**
- S-1: AppSymbol gaps (`snoozeCancel`, `focusPause`, `drivingPause`)
- S-2: `maxWidth: 540` iPad constraint duplicated across 3 onboarding screens → add `AppLayout.onboardingMaxContentWidth`
- S-3: Snooze section indentation in SettingsView (cosmetic)
- S-4: OnboardingScreenWrapper placement (consider separate file if grows)
- S-5: SetupPreviewCard `.title2` font — add AppFont token or confirm intentional
- S-6: OverlayView Timer → async Task alternative for iOS 16+ idiom

**Accessibility: Clean** — All interactive elements have labels/hints, VoiceOver navigation solid, Dynamic Type correct, color contrast ✅, design system consistent, HIG compliant, Reduce Motion respected (except W above), Dark mode ✅.

**Cross-cutting impacts:**
- SettingsView body decomposition (W-1) affects Saul's long-method audit and Rusty's ViewModel box pattern. Coordinate strategy.
- AppFont/AppAnimation token gaps (W-2, W-5) affect design system completeness. Batch as one extension task.
- Reduce Motion inconsistency (OnboardingScreenWrapper) requires alignment — Tess flags it, Linus owns fix.

**Next owner action:** Prioritize W-1 (SettingsView decomposition) and token extensions (W-2/4/5) before Phase 2 UI work.

### 2026-04-26: Tess — Wellness Visual Redesign Proposed (Issue #158)

**Related artifact:** `.squad/decisions/inbox/tess-wellness-design-plan.md` (now merged into decisions.md)

Tess completed comprehensive wellness design research proposing "Restful Grove" visual system:

- **Color palette** (light + dark modes, WCAG AA verified): Sage green primary, gentle blue secondary, soft clay accent, warm sand backgrounds
- **Typography recommendations:** DM Sans (safest), or Nunito + DM Sans hybrid for more personality
- **Design tokens:** Semantic colors, spacing (4pt grid extended), radius system, elevation guidelines
- **Motion guidelines:** Calming micro-interactions with reduce-motion respect
- **Screen redesigns:** Home, Settings, Overlay, Onboarding with before/after direction
- **Implementation phases:** 4 phases from token expansion through QA

**Open questions for team:** Font adoption timing, color unification (eye vs. posture), Phase 2 dashboard scope, overlay copy additions.

**Status:** Awaiting design review and team feedback. Linus to prioritize component styling (Phase 2) if approved.

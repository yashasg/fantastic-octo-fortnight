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

### 2026-05-16 — App Rename: "Eye & Posture Reminder" → "kshana"

**Scope of the rename:**
- All user-facing strings in `Localizable.xcstrings` updated: `home.title`, `onboarding.permission.notificationCard.appName`, `onboarding.welcome.title`, plus legal/privacy text (terms of service, third-party services, children's privacy).
- `Info.plist`: `CFBundleName` set to `"kshana"` (was `$(PRODUCT_NAME)`). Usage descriptions (notifications, focus, motion) now reference "kshana" instead of "Eye & Posture Reminder".
- Swift file header comments updated from `// Eye & Posture Reminder` → `// kshana`.
- `.swiftlint.yml` header comment updated.
- `StringCatalogTests` assertion updated to expect `"kshana"` for `home.title`.

**What was NOT changed (by design):**
- SPM target/module name `EyePostureReminder` — renaming would break all imports; saved for a dedicated PR.
- `EyePostureReminder/` folder path — tied to Package.swift.
- Test target names and paths.
- Git repo name.

**Key learning:** `CFBundleName` was previously `$(PRODUCT_NAME)` which resolves to the SPM target name. Hardcoding `"kshana"` decouples the display name from the module name, which is the correct approach when branding diverges from code identifiers.

## Learnings (2026-04-28 — Logo contrast + adaptive app icon)

### Problem
- `AppColor.surfaceTint` light = `#EEF6F1` was nearly invisible (barely distinguishable from the warm cream background `#F8F4EC`) on the yin-yang logo's yang half.
- `surfaceTint` dark = `#203128` was also barely visible on dark background `#101714`.
- `surfaceTint` is used widely across the app as a surface/panel background — changing it globally would have affected unrelated UI.

### Solution
- **New scoped color token `LogoYangMint`** (light: `#50C4A4`, dark: `#2A6A52`) added to `Colors.xcassets` and `AppColor`. Logo-only — marked with a comment not to use for generic surface fills.
- `YinYangEyeView`: replaced all `AppColor.surfaceTint` with `AppColor.logoYangMint`. Sage/yin side stays on `AppColor.primaryRest`.
- **App icon**: regenerated light icons with saturated mint `#50C4A4`; generated dark variants (`AppIcon-Dark-*.png`) with `#101714` bg, `#8ED2B1` sage, `#2A6A52` yang (3.7:1 internal contrast).
- **Adaptive icon switching**: `Contents.json` updated with `appearances: [{luminosity: dark}]` entries per size — activates iOS 18+ automatic icon theming while iOS 16-17 falls back to default entries.

### Key file paths
- `EyePostureReminder/Resources/Colors.xcassets/LogoYangMint.colorset/Contents.json` — new logo-specific color token
- `EyePostureReminder/Views/YinYangEyeView.swift` — uses `AppColor.logoYangMint`
- `EyePostureReminder/Views/DesignSystem.swift` — `AppColor.logoYangMint` token defined
- `EyePostureReminder/AppIcon.xcassets/AppIcon.appiconset/Contents.json` — dark appearance entries added
- `scripts/generate_icons.py` — Pillow-based icon palette remap; barycentric color interpolation preserves AA edges

### Patterns
- `.gitignore` has `*.png` — icon PNGs need `git add -f` to track them.
- `swift build` on macOS always fails with `no such module 'UIKit'` — pre-existing, iOS-only; use Xcode/xcodebuild for real validation.
- iOS 18 adaptive icon switching: add sibling `images` entries with `"appearances": [{"appearance": "luminosity", "value": "dark"}]` in the `.appiconset/Contents.json`. No new appiconset name needed — existing `AppIcon` name preserved.
- Barycentric color remap (3-palette pixels) via numpy pseudo-inverse preserves anti-aliasing smoothly when remapping icon PNGs.

### 2026-04-28 — Logo Contrast Improvement & Icon Generation (Wave 17)

**Task:** Improve yin-yang logo contrast in light/dark mode and explore dark/light app icon switching.

**Outcome:** ✅ Complete — all acceptance criteria met.

**Work completed:**
- Added `AppColor.logoYangMint` token (light `#50C4A4`, dark `#2A6A52`) to `Colors.xcassets` and `DesignSystem.swift`
- Updated `YinYangEyeView` to use `logoYangMint` instead of `surfaceTint` for the yang half
- Verified no regression to surface tints in `SettingsView`, `OnboardingView`
- Regenerated light and dark app icon PNGs with improved contrast
- Attempted dark AppIcon variants via `appearances` entries in `AppIcon.appiconset/Contents.json`
- **Correction cycle:** Discovered iOS 16 deployment target does not support dark AppIcon `appearances`. Removed unsupported entries and `AppIcon-Dark-*` files.
- Created `scripts/generate_icons.py` to regenerate icon assets; updated to generate only default/light icons (iOS 16 compatible)
- Final validation:
  - `python3 -m py_compile scripts/generate_icons.py` ✅
  - JSON validation for AppIcon and LogoYangMint ✅
  - Clean build on iPhone 17 Pro simulator, no "unassigned children" warnings ✅

**Decisions filed:**
- `.squad/decisions/decisions.md` — LogoYangMint token + design direction + iOS 16 limitation

**Key learnings:**
- Logo-specific tokens avoid collateral breakage (surfaceTint used elsewhere).
- iOS 16 is our deployment floor — dark AppIcon appearances require iOS 18+. Document platform limitations in token comments.
- Icon regeneration script is maintainable; documented in generate_icons.py comments.

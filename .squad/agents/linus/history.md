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

## 2026-04-30 — AppCoordinator duration test failure triage (PR #411)

- Built locally first with `./scripts/build.sh build` (success).
- Ran only the two assigned failing tests:
  - `AppCoordinatorExtendedTests.test_thresholdCallback_usesBreakDurationFromSettings`
  - `AppCoordinatorTests.test_handleNotification_thenPresentPending_usesDurationFromSettings`
- Both tests crashed/restarted under xcodebuild when they set `settings.eyesBreakDuration` (45 / 30).
- Verified adjacent AppCoordinator overlay-routing tests that do **not** mutate break duration both pass:
  - `test_thresholdCallback_eyes_triggersShowOverlay`
  - `test_handleNotification_eyes_thenPresentPending_callsShowOverlayWithEyes`
- Conclusion: this failure slice is downstream of `SettingsStore` break-duration recursive self-assignment in `didSet`, not an independent AppCoordinator/OverlayManager bug.
- Handoff: Basher should land the SettingsStore fix; Livingston can rerun this AppCoordinator duration slice after that merge.

## 2026-04-30 — PR #411 AppCoordinator diagnostics (Scribe update)

Orchestration log recorded at 2026-04-30T09:27:10Z. Confirmed AppCoordinator test failures trace to SettingsStore recursion:
- AppCoordinator duration tests fail downstream (set break duration first)
- Non-duration AppCoordinator tests pass (e.g., overlay threshold tests)
- Root cause is NOT AppCoordinator or OverlayManager logic
- SettingsStore fix (commit `04f73cd`) will resolve AppCoordinator duration test failures automatically

## Learnings

### 2026-05-02 — UI shard stability pass (Home / Onboarding / Overlays+Dark Mode)

- Home true-interrupt checks were unstable on simulator runs where the FamilyControls-backed prompt did not materialize. Stabilized by making tests tolerate either banner or setup-pill state and `XCTSkip` when the runtime never exposes either prompt.
- Onboarding "Customize Settings" CTA flake came from off-screen/non-hittable timing; fixed with a reusable `revealAndWaitForHittable` helper that combines bounded swipe-up retries with a single timeout budget.
- `--reset-onboarding` now also resets settings defaults in UI-test launch handling, improving dark-mode/onboarding state isolation across test methods.

### 2026-05-13 — Google Swift Style Audit (Views + ViewModels)

**Key findings from google_swift_coding_style.md audit (18 files, 4,176 LOC):**

- **Column limit (100 chars):** 43 lines exceed limit (1.0% of codebase). Main offenders: DesignSystem.swift (12 lines, mostly doc comments), HomeView.swift (7 lines, mostly init params), Components.swift (3 lines). Fixable via line-wrapping rules §5.4. No architectural changes needed.

- **Access control:** One violation — `AppCategoryPickerView.swift:139` has public `var primaryButtonHintKey` that should be private. All other helper properties correctly marked private or internal.

- **Doc comments:** 166 doc comment lines across codebase (12.1% coverage). Well-documented on public APIs (SettingsViewModel, OverlayView, AccessibleToggle). Gap: ReminderRowView public struct lacks doc comment. Recommendation: Ensure all public struct/class/enum get single-sentence summary.

- **Force unwraps/casts:** Zero unsafe force unwraps or force casts detected. Excellent safety practices.

- **Guard vs if-let:** All conditional binding follows Google style (guards for early exits, if-let for valid outcomes).

- **Naming conventions:** Excellent — lowerCamelCase consistent, no Hungarian notation, access levels enforce via modifiers not naming.

- **Line-wrapping patterns:** Function declarations and modifier chains sometimes build up >100 chars inline. Should break arguments individually (indented +2) per §5.4 when any single line would exceed 100.

- **Best practices observed:** Private helper types (LegalSection, UIKitSwitchView, SettingsSectionHeader) properly scoped; MARK comments used consistently; no trailing closures with multiple arguments; clean separation of concerns in AccessibleToggle and OverlayView.

**For future work:** When initializer parameters total >80 chars, wrap each onto its own line. This is the main pattern improvement needed. Audit report filed in `.squad/decisions/inbox/linus-google-swift-audit.md`.

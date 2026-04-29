## Learnings

### 2026-05-01 — Issue #168 (Post-redesign review fixes — items 2, 3, 4)

**AppFont is a legacy alias — prefer AppTypography:**
- `AppFont` (DesignSystem.swift) is a pure forwarding enum for `AppTypography`; all static properties delegate to their `AppTypography` counterpart. New and migrated views should reference `AppTypography.*` directly. `AppFont` is retained only for backward compatibility.

**Deduplicating OnboardingPrimaryButtonStyle → PrimaryButtonStyle:**
- `OnboardingPrimaryButtonStyle` was functionally identical to `PrimaryButtonStyle` from `Components.swift` (same pill shape, `primaryRest` fill, 0.98 press scale, reduce-motion guard). Removed the duplicate; all three onboarding views now use `.buttonStyle(.primary)`. `OnboardingSecondaryButtonStyle` has no equivalent in Components and was kept.

**Replacing OnboardingScreenWrapper with .calmingEntrance():**
- `OnboardingScreenWrapper` duplicated `CalmingEntrance` exactly (opacity 0→1, entranceSlideOffset y, hasEverAppeared guard, reduce-motion skip). The only difference was the animation curve constant (`onboardingFadeInCurve` vs `calmingEntranceCurve`). Replaced all three `OnboardingScreenWrapper { content }` usages with `content.calmingEntrance()`, then deleted the wrapper struct. This reduces the animation surface from two parallel implementations to one canonical `CalmingEntrance` modifier.

**Structural pattern for eliminating OnboardingScreenWrapper:**
- `OnboardingScreenWrapper { ScrollView { ... }.background(...) }` → `ScrollView { ... }.background(...).calmingEntrance()`. The `.calmingEntrance()` modifier goes after `.background(...)` so the entrance animates the fully-styled scroll view as a unit, matching the previous wrapper behaviour.



**Gradient background for full-screen overlays:**
- Replace `Color.clear.background(.ultraThinMaterial)` with a `LinearGradient(colors: [AppColor.background, AppColor.surfaceTint], startPoint: .top, endPoint: .bottom).ignoresSafeArea()`. This adapts to dark mode automatically because both tokens are adaptive, and gives a calming directional tint rather than a flat blur.

**Soft circular icon aura pattern:**
- Wrap the reminder icon in a `ZStack { Circle().fill(type.color.opacity(0.12)); Image(...) }` sized to `overlayIconSize * 1.75`. The 0.12 opacity fill creates a subtle "glow" ring that's barely visible in dark mode but pleasant in light mode. Apply `.symbolRenderingMode(.hierarchical)` on the SF Symbol image to get the primary/secondary layer rendering at distinct opacities — this adds the nature/layered motif without extra assets.

**Countdown ring track token swap:**
- Changed countdown ring track from `Color.secondary.opacity(0.3)` to `AppColor.separatorSoft`. This ensures the track is palette-consistent and adapts correctly in both light and dark modes (the raw `.secondary` opacity approach was palette-agnostic).

**PrimaryButtonStyle for primary overlay CTA:**
- Use `Button { ... } label: { Text("overlay.doneButton", bundle: .module) }.buttonStyle(.primary)` as the main dismiss CTA in the content stack. Keep the floating × button (`overlay.dismissButton`) as a secondary escape hatch at top-right. Two dismiss points: primary styled pill (bottom) + secondary icon (top-right). Both are 44pt-accessible and VoiceOver-labelled.

**`accessibilityViewIsModal` — UIKit only:**
- `hostingController.view.accessibilityViewIsModal = true` must remain on the UIKit `UIHostingController.view` in `OverlayManager`. Do NOT use SwiftUI's `.accessibilityViewIsModal(_:)` modifier — it does not exist in the iOS 26 SDK. The UIKit property is the only correct path for overlay modal accessibility.

**Supportive text in ReminderType:**
- Added `overlaySupportiveText: String` computed property to `ReminderType` following the same `String(localized:bundle:.module)` pattern as `overlayTitle`. Localisation keys: `reminder.eyes.overlaySupportiveText` / `reminder.posture.overlaySupportiveText`. This keeps display copy co-located with the type, consistent with existing pattern.

**StringCatalogTests maintenance:**
- When adding new string keys used in a view, update three test methods: `test_allExpectedKeys_resolveToNonEmptyStrings`, `test_noDuplicateKeys_overlayScreen` (or the appropriate screen), and `test_noDuplicateKeys_acrossAllScreens`. Missing any one will cause test failures on the next run.



**Form background theming — `scrollContentBackground(.hidden)`:**
- To replace the default Form/List background, always pair `.scrollContentBackground(.hidden)` with `.background(AppColor.background)` on the Form. Without `.scrollContentBackground(.hidden)`, the system white/grey background overpaints the custom color. This is the canonical approach for iOS 16+.

**Per-row card styling in Form sections:**
- `.listRowBackground(AppColor.surface)` applied per-row (not per-section) is the iOS 16-compatible way to colour section cards. `.listSectionBackground` is iOS 17+ only.
- `.listRowSeparatorTint(AppColor.separatorSoft)` threads palette-consistent separators throughout without disrupting the Form layout engine.

**`SettingsSectionHeader` pattern:**
- Extracted a private `SettingsSectionHeader` view that accepts a `titleKey`, optional `iconName`, and `iconTint`. Pass `.textCase(nil)` on the label Text to suppress the system all-caps forced on section headers. Centralises icon-badge + caption header appearance across all sections.

**`SettingsRowIcon` helper:**
- Reusable `ZStack { Circle().fill(surfaceTint) + Image(...) }` at 32×32pt. Applied in master toggle label, section headers (snooze/smart-pause), and notification warning. Mark `.accessibilityHidden(true)` — icon is purely decorative reinforcement.

**Notification warning warm card:**
- `.listRowBackground(AppColor.accentWarm.opacity(0.10))` + `.listRowSeparatorTint(AppColor.accentWarm.opacity(0.25))` on both warning rows gives a cohesive amber wash without a heavy background. The warning icon moved inside a circular `accentWarm.opacity(0.18)` badge consistent with the rest of the icon system.

**Token migration — `reminderBlue` → `primaryRest`:**
- All toggle tints in `SettingsView` and subsection structs updated from `AppColor.reminderBlue` to `AppColor.primaryRest`. The `reminderBlue` token is retained for legacy backward-compatibility but should not appear in new views.

### 2026-04-30 — Issue #159 (Restful Grove color palette)

**Asset catalog naming convention for themed palettes:**
- Named all Restful Grove color assets with `RG` prefix (e.g. `RGBackground`, `RGPrimaryRest`) to namespace them from legacy colors and avoid collisions. Future palette additions should follow the same `<PaletteInitials><TokenName>` pattern.

**SPM bundle requirement:**
- All `Color(...)` asset lookups in a Swift Package must pass `bundle: .module`. Forgetting this silently returns the fallback color (clear/black) instead of the asset. Always include `bundle: .module` when adding new `AppColor` tokens.

**Semantic remap strategy:**
- When remapping `ReminderType.color` from old tokens (`reminderBlue`/`reminderGreen`) to new ones (`primaryRest`/`secondaryCalm`), the old tokens are kept in `AppColor` for backward compatibility with any views not yet migrated. The switch-based `var color` in `ReminderType` is the single remap site.

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


## 2026-04-28 — xcstrings Readability Clarity Pass Implementation

**Task:** Apply Danny's 14 string clarity improvements to `.xcstrings`, validate, build, and commit.

**Work Summary:**
- Applied all 14 recommended string replacements to `EyePostureReminder/Resources/Localizable.xcstrings`
- Examples applied:
  - `onboarding.permission.body1`: "Notifications let your breaks resume on time after a snooze."
  - `onboarding.welcome.body`: "Quick to set up. Runs quietly — you'll barely notice it."
  - `settings.snooze.limitReached.hint`: "Snooze limit reached. You can snooze again after your next reminder."
- Validated JSON schema (no syntax errors; Python `json.load` successful)
- Built clean: `./scripts/build.sh build` → BUILD SUCCEEDED; no warnings
- Committed: `e47a7bf strings: apply readability/clarity pass to xcstrings copy` (branch: fix/legal-placeholders)

**Key insights:**
- Plain-English phrasing resonates better than "wake … back up" mechanics-speak
- All 77 keys reviewed; only 14 needed improvement; legal copy left unchanged
- Placeholders preserved exactly; no functional changes; copy-only win
- Ready for merge into main branch

**Status:** ✅ Complete


## Learnings

### 2026-04-28 — xcstrings clarity pass (Danny's recommendations)
- Applied 14 string replacements to `EyePostureReminder/Resources/Localizable.xcstrings` per Danny's readability review in `.squad/decisions/inbox/danny-xcstrings-clarity-pass.md`.
- Key pattern: shorter, plain-English phrasing wins over verbose/formal copy (e.g. "Notifications wake reminders back up when a snooze ends" → "Notifications let your breaks resume on time after a snooze.").
- `onboarding.permission.body1` was the specific string the user flagged — now reads clearly.
- JSON structure preserved; validated with `python3 json.load` + full build on iPhone 17 Pro simulator.
- Build command: `xcodebuild -scheme EyePostureReminder -destination 'platform=iOS Simulator,id=179149FE-BAFF-4464-893B-7468D06F49B7' build`


## 2026-04-28 — Screen-Relevant Copy Scope Refinement Implementation

**Task:** Apply Danny's scope refinement — refine the clarity pass by removing snooze references from non-snooze screens while preserving snooze language on snooze-specific screens.

**Work Summary:**
- Applied three targeted replacements to `EyePostureReminder/Resources/Localizable.xcstrings`:
  - `onboarding.permission.body1`: "Notifications keep your break reminders on schedule."
  - `settings.notifications.disabledBody`: "Turn on notifications in Settings so break reminders stay on schedule."
  - `settings.notifications.disabledLabel`: "Notifications are off. Turn them on in Settings so break reminders stay on schedule."
- Validated JSON structure (Python `json.load` successful; no syntax errors)
- Built clean: `./scripts/build.sh build` → BUILD SUCCEEDED; no warnings
- Committed: `dd6a2fd fix: remove snooze references from notification copy on non-snooze screens`
- All `settings.snooze.*` and `settings.section.snooze` keys left untouched — snooze language is correct and expected on snooze-specific screens
- `settings.reset.body` unchanged — "clears your snooze history" is correct in reset context

**Key insights:**
- Screen context matters: snooze language is welcome on snooze settings, inappropriate on onboarding/permission screens
- Clarity pass + scope refinement work together: readability improvements stay; context-inappropriate references removed
- Coordinator-driven refinement process allows team to catch scope issues after initial implementation

**Status:** ✅ Complete. JSON validated. Build passed. Commit pushed.



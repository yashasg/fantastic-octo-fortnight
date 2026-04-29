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



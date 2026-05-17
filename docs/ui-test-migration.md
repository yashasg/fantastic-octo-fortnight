# UI Test → TCA TestStore Migration Audit (#806)

> Owner: Livingston · Reviewer: Rusty · Approval gate: Saul

## Why this exists

CI build time was unblocked by the Release + wholemodule + `cmd_test`
refactor (commit `edc772c`). The next bottleneck is **UI-test wall-clock**
— ~500 s per merge spent in 35 XCUITest cases, almost all of which assert
behaviour that now lives inside reducers we already test in milliseconds
via `TestStore`. This audit categorises every existing UITest into one of
three buckets:

- **(A) Pure state assertion** — behaviour lives in a TCA reducer or
  computed state; the XCUITest just drives an `XCUIElement.tap()` to
  validate the same transition. Migrate to / verify coverage in a
  `TestStore` test.
- **(B) Genuine E2E flow** — exercises app launch, deep-link routing,
  multi-window UIKit integration (overlay `UIWindow` at `.alert + 1`),
  the accessibility tree, system services, or `UserDefaults`-driven
  cross-feature flows. Keep in XCUITest.
- **(C) Redundant or replaceable** — UI-existence assertion duplicating
  another XCUITest or already covered by a reducer test (snapshot or
  truth-table). Delete and lean on the reducer or a single accessibility
  smoke test.

Current surface: **6 files, 1,736 LOC, 35 test methods.**

## Summary

| Bucket | Tests | Reasoning |
| :----- | ----: | :-------- |
| (A) Migrate to `TestStore` | 12 | Most reducer behaviour is already covered by `SettingsFeatureToggleEmissionTests`, `OverlayFeatureBehaviorTests`, `HomeFeatureTests`, `OnboardingFeatureTests`. Migration is mostly "delete XCUI, cite the reducer test". |
| (B) Keep XCUITest | 12 | Genuine E2E surfaces — sheet/overlay/window lifecycles, deep-link nav, screenshots, banner launch-arg seeding. |
| (C) Drop or consolidate | 11 | Accessibility-identifier existence duplicated 3–6×; collapses into 1 sanity test per screen. |

Estimated wall-clock cut after (A)+(C): **~55–65 %** of XCUITest time
(roughly 30 of 35 XCUI cases removed or reduced to identifier-only
checks; remaining 12 (B) cases are the slow, irreducible ones).

## Test-by-test classification

### `HomeScreenTests.swift` (10 tests, 241 LOC)

| # | Test | Bucket | Disposition |
| :- | :--- | :----: | :---------- |
| 1 | `test_homeScreen_onLaunch_displaysRequiredElements` | (C) | Collapse into a single `test_homeScreen_launch_accessibilityIDsPresent` sanity test (nav, title, statusLabel, settingsButton). |
| 2 | `test_homeScreen_openSettings_snoozeButtonExists` | (C) | Drop. `SettingsFeatureSnoozeTests` covers the snooze surface; `home.settingsButton` → sheet binding is exercised by #8. |
| 3 | `test_homeScreen_onLaunch_navigationBarHasTitle` | (C) | Drop — duplicates #1. |
| 4 | `test_homeScreen_settingsButton_isHittable` | (C) | Drop — duplicates #1. |
| 5 | `test_homeScreen_toggleGlobalSwitch_statusLabelChanges` | (A) | Already covered by `HomeFeatureTests.test_state_statusKey_paused_whenGlobalDisabled` + `test_static_statusLocalizationKey_paused` + `test_task_streamsEnabledFlagsIntoState`. Delete XCUI. |
| 6 | `test_homeScreen_onLaunch_titleShowsKshana` | (C) | Drop — brand-name literal asserted from a `LocalizedStringKey`; covered by snapshot/localisation tests if any drift matters. |
| 7 | `test_homeScreen_onLaunch_statusLabelIsNotEmpty` | (C) | Drop — duplicates #5. |
| 8 | `test_homeScreen_settingsSheet_canBeOpenedAndClosed` | (B) | Keep. SwiftUI `.sheet(isPresented:)` round-trip is a genuine binding-lifecycle test that `TestStore` cannot exercise. Slim to one open/close cycle. |
| 9 | `test_homeScreen_trueInterruptBanner_exists` | (B) | Keep. Exercises `--simulate-screen-time-not-determined` + `ScreenTimeAuthorizationStub` injection — system-integration surface. |
| 10 | `test_homeScreen_trueInterruptSetupPill_exists` | (B) | Keep. Banner-dismissed `@AppStorage` pre-seed exercised end-to-end. |

**Net for file:** 10 tests → 3 XCUI tests (#1 collapsed, #8, #9, #10) +
2 reducer tests already in place.

### `SettingsFlowTests.swift` (9 tests, 508 LOC)

| # | Test | Bucket | Disposition |
| :- | :--- | :----: | :---------- |
| 1 | `test_settings_doneButton_dismissesSheet` | (B) | Keep slim. SwiftUI sheet-dismiss lifecycle. |
| 2 | `test_settings_privacySheet_opensAndDismisses` | (B) | Keep. Multi-sheet nav stack + deep-link routing. |
| 3 | `test_settings_smartPauseControls_toggleAndShowFooter` | (A) | Toggle behaviour covered by `SettingsFeatureToggleEmissionTests.test_settingToggleChanged_allSilentSettingKeys_logSettingChanged` (rows include `pauseDuringFocus`, `pauseWhileDriving`). Footer copy is a localisation concern — assert via snapshot or drop. Delete XCUI. |
| 4 | `test_settings_globalToggle_changesStateOnTap` | (A) | Same — covered by `test_settingToggleChanged_globalEnabled_logsSettingChanged`. Delete XCUI. |
| 5 | `test_settings_secondaryControls_exist` | (C) | Bulk identifier existence (snooze x3, haptic, fallback, reset, feedback). Collapse into one `test_settings_accessibilityIDsPresent` sanity test. |
| 6 | `test_settings_reminderControls_exposeTogglesAndPickers` | (C) | Picker existence only. Collapse into the sanity test in #5. |
| 7 | `test_settings_globalToggle_persistsAfterSheetDismissal` | (A) | Persistence is `SettingsStore` + `SettingsClient.liveValue` + observer-broadcast. Covered by `SettingsStoreObserverTests` + `SettingsClient`-driven reducer flows. Add one targeted `SettingsClient.snapshot()` round-trip test if missing. Delete XCUI. |
| 8 | `test_settings_eyesReminderToggle_persistsAfterSheetDismissal` | (A) | Same as #7 — eyes-side covered by the same observer + snapshot chain. Delete XCUI. |
| 9 | `test_settings_savedBanner_appearsOnToggle` | (A) | Already covered by `SettingsFeatureToggleEmissionTests.test_settingToggleChanged_flipsShowSavedBannerAndSchedulesExpiry`. Delete XCUI. |

**Net for file:** 9 tests → 3 XCUI tests (#1, #2, collapsed accessibility
smoke) + reducer coverage already in place.

### `OnboardingFlowTests.swift` (6 tests, 229 LOC)

| # | Test | Bucket | Disposition |
| :- | :--- | :----: | :---------- |
| 1 | `test_onboarding_welcomeScreen_disclaimerIsVisible` | (C) | Collapse into a single `test_onboarding_welcome_accessibilityIDsPresent` sanity test (Next CTA + disclaimer). |
| 2 | `test_onboarding_fullFlow_completesSuccessfully` | (A) | Page-machine covered by `OnboardingFeatureTests.test_nextTapped_incrementsCurrentPage`, `test_nextTapped_clampsAtLastPageIndex`, `test_finishTapped_logsCompletedAndEmitsCompletedOnboarding`, `test_skipTapped_logsCompletedAndEmitsCompletedOnboarding`. Delete XCUI. |
| 3 | `test_onboarding_permissionScreen_controlsExist` | (C) | Identifier existence only. Drop or fold into #1's sanity test. |
| 4 | `test_onboarding_setupScreen_controlsExist` | (C) | Same — fold pickers into the sanity test. |
| 5 | `test_onboarding_interruptMode_actionsExistAndComingSoonIsDisabled` | (A) | `isEnabled = false` for the pre-entitlement setup CTA is a `View` conditional that maps directly to `OnboardingFeature.State` + `ScreenTimeAuthorizationStatus`. Add a `OnboardingFeatureTests.test_interruptMode_setupPreviewDisabledWhenUnauthorised` (if missing) and delete XCUI. |
| 6 | `test_onboarding_customizeButton_opensSettingsAfterCompletion` | (B) | Keep. Cross-feature flow: Onboarding → completes → `openSettingsOnLaunch` `@AppStorage` flag → Home appears → Settings sheet auto-presents. Touches scene-phase + UserDefaults + sheet binding chain that no single reducer covers in isolation. |

**Net for file:** 6 tests → 2 XCUI tests (#1 collapsed sanity, #6) +
1 new reducer test for #5's enable-flag truth-table.

### `OverlayTests.swift` (9 tests across 3 classes, 255 LOC)

| # | Test | Bucket | Disposition |
| :- | :--- | :----: | :---------- |
| 1 | `OverlayTests.test_overlay_onNormalLaunch_notPresent` | (B) | Keep. Negative-launch assertion of the `.alert + 1` `UIWindow`. |
| 2 | `OverlayTests.test_overlay_onNormalLaunch_homeScreenIsVisible` | (C) | Drop — duplicates #1's negative assertion. |
| 3 | `OverlayPresentationTests.test_overlay_onShowOverlayEyes_dismissButtonVisible` | (B) | Keep. Genuine launch-arg → AppDelegate → AppFeature → overlay window-presentation chain. |
| 4 | `OverlayPresentationTests.test_overlay_onShowOverlayEyes_doneButtonVisible` | (C) | Drop — duplicates #3 (all three subviews render together). |
| 5 | `OverlayPresentationTests.test_overlay_onShowOverlayEyes_supportiveTextVisible` | (C) | Drop — duplicates #3. |
| 6 | `OverlayPresentationTests.test_overlay_doneButton_dismissesOverlay` | (A) | Covered by `OverlayFeatureBehaviorTests.test_dismissTapped_callsOverlayClientDismissExactlyOnce` + `test_twoPhaseDismiss_dismissTapped_ordering`. Keep **one** thinner (B) variant to assert the UIKit `UIWindow` is released (the `#714` regression); migrate analytics + state to reducer. |
| 7 | `OverlayPresentationTests.test_overlay_onShowOverlayEyes_settingsLinkVisible` | (C) | Drop — covered by #3's combined render check. |
| 8 | `OverlayPresentationTests.test_overlay_settingsLink_opensSettingsWithSnoozeOptions` | (B) | Keep. Multi-window navigation: overlay → dismiss → UserDefaults write → onChange → sheet present. No reducer covers this without the UIKit window plumbing. |
| 9 | `OverlayPostureTests.test_overlay_postureVariant_visibleAndDismissible` | (B) + (A) split | Keep render check (B). Move the dismiss assertion to the reducer (already covered by `OverlayFeatureBehaviorTests`, just delete the dismiss portion). |

**Net for file:** 9 tests → 5 XCUI tests (#1, #3, #6-slim, #8, #9-slim) +
reducer coverage already in place.

### `AppStoreScreenshotTests.swift` (1 test, 119 LOC)

| # | Test | Bucket | Disposition |
| :- | :--- | :----: | :---------- |
| 1 | `test_captureAppStoreScreenshotSet` | (B) | Keep as-is. Pure screenshot capture; opt-in (`APP_STORE_SCREENSHOT_DIR` env). Not on the merge-time critical path. |

### `UITestHelpers.swift` (infrastructure, 384 LOC)

Not classified — pure helper surface (launch arguments, `XCUIElement`
wait/scroll/hittable helpers). All consumed by the surviving (B) tests
above, so no whole-file removal. After (A)+(C) lands, audit again for
helpers that no longer have any caller (e.g. picker-element resolvers
that only `test_settings_reminderControls_exposeTogglesAndPickers` used).

## Migration plan after this audit lands

1. **Phase 1 — delete (C)** (no reducer work needed):
   - `HomeScreenTests`: drop #2, #3, #4, #6, #7; collapse #1.
   - `SettingsFlowTests`: collapse #5+#6 into one sanity test.
   - `OnboardingFlowTests`: drop #3, #4; collapse #1.
   - `OverlayTests`: drop #2, #4, #5, #7.
   - **Outcome:** 11 fewer XCUI cases; immediate wall-clock saving.

2. **Phase 2 — delete (A) where reducer coverage already exists**:
   - `HomeScreenTests` #5 — already covered.
   - `SettingsFlowTests` #3, #4, #9 — already covered.
   - `OnboardingFlowTests` #2 — already covered.
   - `OverlayTests` #6 (state portion), #9 (dismiss portion) — already
     covered.
   - **Outcome:** 6 more XCUI cases removed.

3. **Phase 3 — backfill missing reducer coverage, then delete remaining (A)**:
   - `SettingsFlowTests` #7, #8 — add `SettingsClientLiveTests` for the
     persisted-snapshot round-trip if missing.
   - `OnboardingFlowTests` #5 — add an `OnboardingFeatureTests` enable-flag
     truth-table for the pre-entitlement setup-preview disabled state.
   - **Outcome:** the last 4 (A) XCUI cases gone; only (B) survives.

4. **Phase 4 — measure**:
   - Capture the baseline UI-test wall-clock on `main` before any
     deletions (commit a `.squad/work/ui-test-baseline.txt` snapshot of
     `xcodebuild test` timing per file).
   - After Phase 3 lands, re-run and record the new wall-clock. Goal per
     the issue acceptance criteria: **>40 % cut** (≈ 500 s → ≤ 300 s).

## Open questions

- The XCUI persistence tests (`SettingsFlowTests` #7, #8) assert the
  toggle survives a sheet dismiss-reopen cycle. The reducer covers
  state, and `SettingsStoreObserverTests` covers `UserDefaults` writes.
  The bit not yet covered is the `SettingsClient.liveValue` cache
  refresh after a sheet remounts. Decide in Phase 3 whether to add
  a small `SettingsClientLiveTests.test_snapshot_reflectsLatestStoreWrite`
  test or accept that the existing observer chain is sufficient.
- `SettingsFlowTests.test_settings_smartPauseControls_toggleAndShowFooter`
  also asserts the footer copy is present (`smart pause`/`focus mode`
  case-insensitive). That is a localisation assertion. If the team wants
  to keep localisation regression coverage in XCUITest, peel it off
  into a slim (B) test rather than dropping outright. Default: drop and
  rely on snapshot / `Localizable.strings` audit.

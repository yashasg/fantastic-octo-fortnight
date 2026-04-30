# Linus — Onboarding A11y & Modal Accessibility Decisions

**Author:** Linus (iOS Dev — UI)
**Date:** 2026-04-30
**Status:** Implemented (commit `01ea123`, fixes #311 #313 #314)

---

## Decision 1: Decorative hero illustrations must be `.accessibilityHidden(true)`

**Rule:** Onboarding hero illustrations (SF Symbol at large size on a circle background) must use `.accessibilityHidden(true)`, NOT `.accessibilityLabel(...)`, when the adjacent screen title conveys the same semantic meaning.

**Rationale:** VoiceOver announces the icon *and* the title, creating a redundant double-announcement. The title is always sufficient — the illustration is decorative.

**Applied pattern:**
- `AppCategoryPickerView` — ✓ `.accessibilityHidden(true)`
- `OnboardingPermissionView` — ✓ `.accessibilityHidden(true)`
- `OnboardingInterruptModeView` — fixed in #311 to `.accessibilityHidden(true)`

**Exception:** Only use `.accessibilityLabel` on a hero illustration if it adds semantic context the title does not provide (e.g., `OnboardingWelcomeView` YinYangEyeView which has distinct visual narrative).

---

## Decision 2: SwiftUI `accessibilityViewIsModal(_:)` is not available in iOS 26 SDK

**Finding:** Running `xcrun swift -e 'import SwiftUI; let _ = Text("").accessibilityViewIsModal(true)'` on Xcode 26.4 produces: *error: value of type 'Text' has no member 'accessibilityViewIsModal'*

**Correct modal suppression pattern for UIKit-hosted overlays:**
- Set `hostingController.view.accessibilityViewIsModal = true` in `OverlayManager` (UIKit layer)
- Do NOT use `.accessibilityAddTraits(.isModal)` — this adds a semantic trait but does NOT suppress VoiceOver traversal of other windows
- Document in SwiftUI view with a comment explaining UIKit ownership

**Impact:** Phase 1 UI Decision 2 must be updated to reflect that `.accessibilityViewIsModal(true)` is unavailable; UIKit path is the only correct implementation.

---

## Decision 3: `finishOnboardingAndCustomize()` pattern for Settings deep-link from onboarding

**Pattern:** When a "Customize Settings" CTA is needed at the end of onboarding, use a separate completion function that:
1. Sets `AppStorageKey.openSettingsOnLaunch = true` (UserDefaults)
2. Calls `finishOnboarding()` (sets `hasSeenOnboarding = true`)

`HomeView` observes `openSettingsOnLaunch` via `@AppStorage` and opens Settings sheet in `.onAppear`. No additional coordination needed.

**Why not pass @EnvironmentObject to onboarding view:** Keeps `OnboardingInterruptModeView` free of `@EnvironmentObject` dependencies, which would cause test-host crashes in SPM unit tests. Plain callbacks are testable without infrastructure.

**Location:** `OnboardingView.finishOnboardingAndCustomize()` → passed as `onCustomize:` to final screen.

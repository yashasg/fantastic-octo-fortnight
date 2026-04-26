# Tess Design Consistency Audit — Restful Grove

**Date:** 2026-04-26
**Branch:** `feature/restful-grove`
**Scope:** All files under `EyePostureReminder/Views/`, plus `DesignSystem.swift` and `Components.swift`.

## Summary

Restful Grove is broadly applied across the view layer: semantic `AppColor` tokens, Nunito `AppFont`/`AppTypography`, rounded-radius tokens, and adaptive surfaces are now the dominant pattern. I found and fixed several quick consistency gaps in Home, Legal, shared components, settings icons, dark-mode elevation, and SF Symbol rendering.

Build validation: `xcodebuild -scheme EyePostureReminder -destination 'generic/platform=iOS' build -quiet` passed. `swift build` still fails in this repo because it targets macOS where UIKit is unavailable; that appears to be an existing package/tooling limitation, not caused by this audit.

## Fixes Applied

- Replaced remaining visible `.primary`, `.secondary`, and `.accentColor` usages in view code with Restful Grove semantic tokens where they affected app UI.
- Updated `PrimaryButtonStyle` foreground from hardcoded `.white` to adaptive `AppColor.background` for dark-mode contrast on light sage primary buttons.
- Changed `SoftElevation` dark-mode border from `Color.primary.opacity(...)` to `AppColor.separatorSoft.opacity(...)`.
- Brought `HomeView` onto Restful Grove background/text/tint tokens and hierarchical SF Symbol rendering.
- Brought `LegalDocumentView` body text and dismiss action onto AppFont/AppColor tokens.
- Reused `IconContainer` for settings row/warning icons and added hierarchical rendering to shared/icon-heavy components.
- Added hierarchical rendering to onboarding hero, preview, and reminder-card SF Symbols.

## Findings

### 🔴 Must fix

None remaining after the quick fixes above.

### 🟡 Should fix

1. **Onboarding primary buttons still use a separate `OnboardingPrimaryButtonStyle`.**
   It matches Restful Grove closely, but duplicates `PrimaryButtonStyle` instead of adopting the shared component. This is not visually broken, but it increases drift risk.

2. **Some semibold text is expressed via `.fontWeight(.semibold)` after an AppFont token.**
   Examples: `SectionHeader`, notification-card app name. This still uses Nunito because the base font is an AppFont token, but adding caption-emphasized typography tokens would make intent cleaner.

3. **Settings form rows are visually tokenized, but still constrained by native `Form` styling.**
   Row backgrounds/separators use Restful Grove tokens, but a fully custom list/card settings surface would better express the `WellnessCard` direction.

### 🟢 Nice to have

1. **Use `WellnessCard` for onboarding preview cards.**
   The cards already manually match the modifier (`surface`, `radiusCard`, `separatorSoft`, `softElevation`). Swapping to `.wellnessCard(elevated: true)` would reduce duplication.

2. **Adopt `StatusPill` where short state labels appear.**
   Home/snooze states could eventually use a pill treatment for stronger component reuse, but current layouts are acceptable.

3. **Introduce icon-size typography helpers for `IconContainer`.**
   `IconContainer` uses `.font(.system(size:...))` appropriately for SF Symbols, but a helper token would make audit searches quieter.

## Emotional Tone

Overlay copy feels supportive and concise: “Look away and soften your focus.” and “Roll your shoulders and reset.” fit the calm wellness tone. Onboarding copy is warm enough overall, with reassuring phrases like “No spam” and “Works quietly in the background.” No copy changes needed for this pass.

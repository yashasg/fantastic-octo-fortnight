# Decision: Home Yin-Yang Eye Animation

**Author:** Tess  
**Date:** 2026-04-26  
**Status:** Implemented  
**Branch:** feature/restful-grove

## Context

Yashasg requested a Home screen animation based on a yin-yang concept: one open eye and one closed eye come together, rotate around each other briefly, then stop. The animation may later become the app logo, but the immediate scope is HomeView.

## Decision

Implement a self-contained `YinYangEyeView` and place it in HomeView's hero/status area above the title and status copy.

Design choices:
- Use SF Symbols `eye.fill` and `eye.slash.fill` for stronger visual weight at hero size.
- Use `AppColor.primaryRest` for the open eye and `AppColor.secondaryCalm` for the closed eye.
- Use a soft `AppColor.surfaceTint` circular field with two subtle tinted inner circles so the resting pose reads as a simplified yin-yang mark.
- Animate once on appear for 1.35 seconds with `.easeInOut`, with no bounce or looping.
- Start the symbols apart, pull them inward while rotating around the center, and settle vertically as a quiet logo-like composition.
- Respect Reduce Motion by rendering the final settled state immediately.

## Consequences

- HomeView now has a calmer branded hero moment while keeping the existing title and active/paused status copy.
- The old status icon no longer changes between active and paused; the status text remains the state indicator.
- The animation is isolated in `YinYangEyeView`, making future extraction into an app-logo component straightforward.
- Existing UI test identifiers remain available, including `home.statusIcon`.

## Validation

- Build passed with `xcodebuild build -scheme EyePostureReminder -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`.
- Tests passed with `xcodebuild test -scheme EyePostureReminder -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`.

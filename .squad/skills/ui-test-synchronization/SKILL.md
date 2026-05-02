# Skill: UI Test Synchronization Anchors

## Pattern
Prefer deterministic state anchors over broad waits or negative existence assertions.

## Use
- Wait for a positive interactive anchor before assertions (e.g., CTA button hittable).
- For dismiss flows, assert fallback screen readiness first, then overlay root disappearance.
- For hidden-but-mounted controls, assert `hittable == false` instead of `exists == false`.

## Why
Accessibility trees can keep elements mounted during transitions, making raw existence checks flaky.

## iOS/XCUITest Helpers
- `waitForHittable(timeout:)` with single total deadline.
- `waitForOverlayPresented()` anchored on a hittable control.
- `waitForOverlayDismissed()` anchored on fallback screen + overlay root non-existence.
- `waitForNotHittable()` for hidden mounted elements.

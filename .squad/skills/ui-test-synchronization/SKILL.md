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

## Runtime-gated prompt pattern
- For simulator-dependent surfaces (permissions/Screen Time prompts), assert one of the valid UI affordances (e.g., banner **or** fallback pill) instead of one brittle branch.
- If the runtime exposes neither affordance despite test setup, prefer `XCTSkip` over false-red failure and log the exact missing precondition.
- Keep skips narrowly scoped to the runtime-gated tests; do not broaden to unrelated UI checks.

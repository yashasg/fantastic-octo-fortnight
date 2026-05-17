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

## CI shard launch parity
- Before every helper-driven launch, terminate any running app instance so new launch arguments are guaranteed to apply.
- In shard setup, gate on overlay root visibility first (`overlay.root`) and reserve hittability checks for test-specific interactions.

## Simulator hit-point resilience
- In CI simulators, controls may `exists == true` but still report invalid activation points (zero-frame/transition timing artifacts).
- Prefer a two-step interaction policy for volatile overlays: assert existence/readiness first, then tap by normalized center coordinate as a fallback to direct `tap()`.
- Keep hittability waits for intent verification, not as the sole interaction gate.

## Overlay lifetime pinning for launch-arg tests
- For launch-argument driven overlay entry points, seed deterministic long break durations in app startup test hooks so overlays stay mounted through shard startup latency.
- Reset test defaults before seeding to avoid cross-test contamination between shards.

## waitForOverlayPresented timeout contract
- **Default: 20 s** on macos-15 CI runners. M-series Mac completes in <5 s; the larger budget only matters on loaded CI.
- Use a **single shared deadline** for the two sequential phases (visibility + hittability). Never give each phase the full timeout independently — that silently doubles wall-clock cost on failure paths.
- Reserve a minimum (3 s) for the hittability phase even when visibility consumed most of the budget.
- 8 s was the previous default, tuned on M-series hardware. CI failures in run 25957888870 showed overlay.root consistently appeared *after* 8 s on loaded macos-15 runners (every OverlayPresentationTests test failed with 14-15 s elapsed = 8 s + 6 s tearDown overhead).

## Cold-simulator accessibility-tree hang
- On a cold simulator (very first test after boot), XCTest's internal snapshot evaluation for `waitForExistence` / `isHittable` can block for minutes, surfacing as "Failed to get matching snapshots: Timed out while evaluating UI query".
- A generous timeout budget (20+ s) reduces the chance of our test-helper timeout racing ahead of XCTest's internal evaluation.
- If the "Failed to get matching snapshots" error appears alongside our XCTAssertTrue failure, the cold-simulator snapshot evaluation is the trigger, not a broken overlay identifier.

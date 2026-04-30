# Virgil Decision Inbox: Parallel UI Test Shards in CI

## Decision
Adopt class-based UI-test sharding in CI using a GitHub Actions matrix job (`uitest-shard`) and keep a lightweight aggregate `UI Tests` gate job.

## Why
- The previous single UI-test step was long-running and serialized.
- Class-level shards are deterministic and map cleanly to existing suite ownership/areas.
- Maintaining the aggregate `UI Tests` check preserves compatibility with downstream release gating that expects a stable check name.

## Implementation Convention
1. CI UI tests run as matrix shards using `./scripts/build.sh uitest` with repeated `--only-testing` filters.
2. `build.sh uitest` defaults to full-suite behavior when no filters are passed (local DX unchanged).
3. Each shard writes a unique result bundle path via `--result-bundle-path` and uploads a uniquely named artifact.
4. Keep build-for-testing + test-without-building for UITests; do not collapse back to single-pass `xcodebuild test` due to known `TEST_TARGET_NAME` ambiguity.

## Initial Shard Layout
- `onboarding`: `EyePostureReminderUITests/OnboardingFlowTests`
- `home`: `EyePostureReminderUITests/HomeScreenTests`
- `settings`: `EyePostureReminderUITests/SettingsFlowTests`
- `overlays-darkmode`: `EyePostureReminderUITests/OverlayTests`, `EyePostureReminderUITests/OverlayPresentationTests`, `EyePostureReminderUITests/OverlayPostureTests`, `EyePostureReminderUITests/DarkModeUITests`

## Follow-up
Rebalance shards by timing data if one shard becomes the long pole; keep naming and artifact conventions unchanged.

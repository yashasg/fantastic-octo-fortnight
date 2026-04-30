# Virgil — History

## Core Context

- **Project:** kshana (formerly Eye & Posture Reminder) — lightweight iOS app with True Interrupt Mode via Screen Time APIs
- **Stack:** Swift, SwiftUI (iOS 16+), MVVM, UserNotifications, UIKit overlay, UserDefaults, FamilyControls (Phase 3+)
- **Owner:** Yashasg
- **Joined:** 2026-04-24

## Wave 21 — CI/Build/Warning Enforcement Read-Only Audit (2026-04-30)

**Task:** Read-only CI/build audit. Verify warning-as-error enforcement, lint/test/coverage gates, artifact handling, action pinning, and signed/extension build blockers.

**Outcome:** Two material gaps found; two GitHub issues filed.

### Findings

**✅ Passing (no gaps):**
- `build.sh` enforces `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES` + `GCC_TREAT_WARNINGS_AS_ERRORS=YES` on all simulator builds
- `ci.yml` and `testflight.yml` actions are SHA-pinned (per #256, closed)
- SwiftLint runs with `--strict` (all warnings = errors)
- Coverage threshold at 80% enforced via `xcrun xccov` + `python3` with `exit 1` on fail
- `if: always()` on coverage step prevents bypass when tests fail
- Artifacts (dSYMs, test results, IPA) uploaded with retention-days and `if-no-files-found: error/warn`
- `testflight.yml` CI gate polls for both "Build & Test" and "UI Tests" check results before deploy
- Action pinning fully resolved for build/deploy workflows (ci.yml, testflight.yml)

**🔴 Gap 1 — build_signed.sh archive missing warning-as-error flags (#304, p1):**
- `build.sh` passes `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES` + `GCC_TREAT_WARNINGS_AS_ERRORS=YES` via `XCODE_FLAGS`
- `build_signed.sh` `cmd_archive` does NOT pass these flags to xcodebuild
- A warning that fails CI could silently pass the distribution archive
- `setup-screentime.sh --build` also uses grep-based warning detection (weaker) instead of compiler flags

**🔴 Gap 2 — Squad infrastructure workflows unpinned (@v4, @v7) (#305, p2):**
- squad-heartbeat.yml, squad-issue-assign.yml, squad-triage.yml, sync-squad-labels.yml all use `actions/checkout@v4` and `actions/github-script@v7`
- #256 (closed) only fixed ci.yml and testflight.yml; squad workflows were out of scope
- These workflows have `issues: write` permissions; floating tags are a supply-chain risk
- Fix requires updating both active workflows AND `.squad/templates/workflows/` source so `squad upgrade` doesn't revert

### Issues Filed

- **#304** — `build_signed.sh` archive missing `SWIFT_TREAT_WARNINGS_AS_ERRORS` (p1)
- **#305** — Squad workflow unpinned action refs, `@v4`/`@v7` (p2)

### Not-Duplicated

- #210 (extension signing/entitlement blocker) — explicitly excluded per task rules
- #201 (entitlement approval) — upstream blocker, not a CI enforcement gap

## Wave [next] — CI Hardening Pass: #304 + #305 Fixed (2026-04-30)

**Task:** Fix warning-as-error parity and action SHA pinning in one pass.

**Commit:** `5e2ab9786c50617b648ebf9650db092a2f180f24` on branch `fix/overlay-a11y-308-310`

### #304 — Warning-as-error flags added to build_signed.sh and setup-screentime.sh
- `scripts/build_signed.sh`: added `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES` and `GCC_TREAT_WARNINGS_AS_ERRORS=YES` to the `run_xcodebuild` archive call (before `archive` verb), after `${AUTH_FLAGS[@]}` expansion
- `scripts/setup-screentime.sh --build`: added same flags to the `xcodebuild build` invocation (previously only post-build grep detected warnings; now the compiler itself enforces them)
- Parity achieved with `scripts/build.sh` XCODE_FLAGS array

### #305 — All floating @vN action refs pinned
- Pinned `actions/checkout@v4` → `@34e114876b0b11c390a56381ad16ebd13914f8d5 # v4.3.1`
- Pinned `actions/github-script@v7` → `@60a0d83039c74a4aee543508d2ffcb1c3799cdea # v7.0.1`
- Applied to: `squad-heartbeat.yml`, `squad-issue-assign.yml`, `squad-triage.yml`, `sync-squad-labels.yml` (active + `.squad/templates/` copies)
- SHAs verified via `gh api repos/actions/*/git/refs/tags`

### Learnings
- macOS workflow YAMLs had CRLF line endings — `sed -i '' 's/...@v4$/...'` with `$` anchor fails silently; must use `perl -i -pe` with `\r?$` to handle CRLF
- Always check `.squad/templates/workflows/` when patching active workflows — otherwise `squad upgrade` reverts changes
- Warning-as-error flags belong in every xcodebuild invocation, not just test/build; archive paths must match CI build paths exactly

## Wave [next+1] — Template Action Pinning: #317 (2026-04-30)

**Task:** Pin floating `@vN` action refs in the 7 remaining `.squad/templates/workflows/` files out of scope for #305.

### Files patched
- `squad-ci.yml` — checkout@v4, setup-node@v4
- `squad-docs.yml` — checkout@v4, setup-node@v4, upload-pages-artifact@v3, deploy-pages@v4
- `squad-insider-release.yml` — checkout@v4, setup-node@v4
- `squad-label-enforce.yml` — checkout@v4, github-script@v7
- `squad-preview.yml` — checkout@v4, setup-node@v4
- `squad-promote.yml` — checkout@v4 (×2 jobs)
- `squad-release.yml` — checkout@v4, setup-node@v4

### Resolved SHAs
| Action | SHA | Version |
|---|---|---|
| actions/checkout | `34e114876b0b11c390a56381ad16ebd13914f8d5` | v4.3.1 |
| actions/setup-node | `49933ea5288caeca8642d1e84afbd3f7d6820020` | v4.4.0 |
| actions/github-script | `f28e40c7f34bde8b3046d885e986cb6290c5673b` | v7.1.0 |
| actions/upload-pages-artifact | `56afc609e74202658d3ffba0e8f6dda462b719fa` | v3.0.1 |
| actions/deploy-pages | `d6db90164ac5ed86f2b6aed7e0febac5b3c0c03e` | v4.0.5 |

### Validation
- `grep -rn "uses:.*@v[0-9]" .squad/templates/workflows/squad-{ci,docs,insider-release,label-enforce,preview,promote,release}.yml` → zero results ✅
- Only `.github/workflows/` and the 4 previously-pinned templates remain (already SHA-pinned from #305)

### Learnings
- `sed -i '' -e 's|...|...|g'` works cleanly on these YAML files (no CRLF issue unlike some macOS XCBuild scripts)
- The `@v4` / `@v7` major tags are mutable floating refs — always resolve to commit SHA via `gh api repos/<owner>/<repo>/git/refs/tags/<tag>`
- Deployed workflows were already fully pinned; #317 was template-only

## Wave [next+2] — PR #411 CI Failure Forensics + Reporting Hardening (2026-04-30)

**Context:** CI run `25155651913` on `fix/legal-disclaimer-356-357-359` (head `14657c9`) failed `Test (simulator)` with contradictory output: XCTest stream reported `Executed 508 tests, with 0 failures`, while xcodebuild exited 65.

### Findings
- This is normal for Xcode’s result-bundle aggregation under crash scenarios: live XCTest console can show suite-level pass counts, then xcodebuild marks the action failed from `testFailureSummaries` discovered in the `.xcresult` issue graph.
- Extracted CI artifact `test-results-0.2.0-build123` and confirmed action status `failed` with **32** `testFailureSummaries`.
- Failure summaries are deterministic crashes (segv) centered on `SettingsStore` (`eyesBreakDuration` getter/setter recursion), matching Livingston’s analysis and not #399 state pollution.

### CI/Script improvement implemented
- Patched `scripts/build.sh` (`cmd_test`) to handle xcodebuild test failures by parsing `TestResults.xcresult` and printing a concise `testFailureSummaries` list.
- This closes the observability gap where console stream can look green while xcresult carries crash failures.

### Local validation
- Baseline and post-change local build both pass via `./scripts/build.sh build`.
- Script syntax validated with `bash -n scripts/build.sh`.

### Handoff
- Basher: owns SettingsStore crash fix.
- Livingston: owns targeted verification for AppCoordinator fallout tests.
- Virgil: owns CI parity checks from xcresult status + summary, not console pass text alone.

## 2026-04-30 — PR #411 xcresult diagnostics enhancement (Scribe update)

Orchestration log recorded at 2026-04-30T09:27:10Z. Enhanced CI diagnostics documented in decisions.md:
- Root cause: xcodebuild exit code + .xcresult issue summaries are source of truth; live test stream can be misleading
- PR #411 run showed "0 failures" but 32 testFailureSummaries in result bundle (SEGV crashes during aggregation)
- Commit `6815fed`: Updated scripts/build.sh to print concise xcresult failure summaries on xcodebuild test failure
- Team impact: Basher can target real failures quickly from CI logs; future triage always inspects .xcresult

## 2026-04-30 — Parallel UI test shards in CI (PR #411)

- Split UI tests into matrix shards in `.github/workflows/ci.yml` (`uitest-shard`) with deterministic class-based filters:
  - `onboarding` → `EyePostureReminderUITests/OnboardingFlowTests`
  - `home` → `EyePostureReminderUITests/HomeScreenTests`
  - `settings` → `EyePostureReminderUITests/SettingsFlowTests`
  - `overlays-darkmode` → `OverlayTests`, `OverlayPresentationTests`, `OverlayPostureTests`, `DarkModeUITests`
- Kept a top-level `UI Tests` gate job that depends on all shards so downstream workflows (TestFlight deploy check polling) continue to use a stable check name.
- Extended `./scripts/build.sh uitest` with optional `--only-testing` (repeatable) and `--result-bundle-path` flags while preserving default full-suite behavior.
- Preserved build-for-testing + test-without-building flow and TEST_TARGET_NAME ambiguity workaround; shard filtering is applied via `-only-testing` during `test-without-building`.
- Added per-shard `.xcresult` paths and artifact names to prevent collisions in parallel jobs.
- Local validation performed: shell syntax checks, CI YAML parse check, `./scripts/build.sh build`, and a targeted shard run (`HomeScreenTests`) using the new flags.

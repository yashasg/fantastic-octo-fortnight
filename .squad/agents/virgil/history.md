# Virgil — History

## Core Context

- **Project:** kshana (formerly Eye & Posture Reminder) — lightweight iOS app with True Interrupt Mode via Screen Time APIs
- **Stack:** Swift, SwiftUI (iOS 16+), MVVM, UserNotifications, UIKit overlay, UserDefaults, FamilyControls (Phase 3+)
- **Owner:** Yashasg
- **Joined:** 2026-04-24

### CI/Build System Expertise (2026-04-30)

**Wave 21:** Audited CI/build enforcement. Found 2 gaps (#304, #305).
- #304 — `build_signed.sh` archive missing `SWIFT_TREAT_WARNINGS_AS_ERRORS`
- #305 — Squad infrastructure workflows using floating @v4/@v7 action refs (supply-chain risk)
- **Fix summary:** #304 fixed by adding warning-as-error flags to `build_signed.sh` and `setup-screentime.sh`. #305 fixed by pinning all action refs to commit SHAs in 11 workflow files (active + templates).
- **Key learnings:** macOS YAMLs may have CRLF line endings (use `perl -i -pe` not `sed`); always patch `.squad/templates/workflows/` when fixing active workflows or `squad upgrade` reverts changes.

**PR #411 CI Diagnostics:** Discovered xcodebuild exit code + `.xcresult` issue summaries are source of truth; live test console can lie. Patched `scripts/build.sh cmd_test` to print concise xcresult failure summaries.

**UI Test Sharding:** Split UI tests into matrix shards (onboarding, home, settings, overlays-darkmode) with deterministic class-based filters. Kept stable top-level `UI Tests` gate job for downstream workflow polling.

**Extension Signing Hardening:** Added `verify_archived_extensions()` to fail archive when extension `.appex` binaries missing from `PlugIns/` but `EXTENSION_PROFILES_AVAILABLE=YES`. Defers enforcement until #201 profiles are configured.

**Release/TestFlight Triage:** Fixed App Group identifier (`group.com.yashasg.kshana`), updated App Store SKU to `kshana`. Dependencies: #201 (entitlement approval) blocks #410.

---

## 2026-05-02 — UI shard false-green hardening

- Hardened `scripts/build.sh cmd_uitest` retry loop to gate success on xcresult truth, not command exit text alone.
- Added `xcresult_attempt_passed()` and now treat an attempt as failed when `.xcresult` is missing, unparsable, has `testFailureSummaries`, or reports non-success action status.
- Retry narrowing still targets only failed tests when available, preserving fast recovery while preventing false-green shards.

### Learnings
- **2026-05-15: Team consolidation — 7 teams collapsed to 2 (Dev + Strategy).** You are now explicitly on the **Dev team** alongside Rusty, Linus, Livingston, Saul, Basher, Yen, Benedict, Virgil. Dev team owns code, tests, build, and CI. Strategy team (Danny, Tess, Reuben, Turk, Frank, Roman, Toulour, Denham, Sponder, Bashir, Matsui, Bruiser) handles product, design, research, legal, audits, and ASO. Scribe and Ralph remain on the roster outside both teams (silent infra). Use GitHub label `team:dev` for issue routing; see .squad/streams.json for canonical Dev workstream folder scopes.
- UI shard retries must validate `.xcresult` status + failure summaries after every green exit to prevent command-stream false positives.
- Overlay-heavy shards can fail repeatedly on element hittability when setup depends on immediate tappability; gate setup on overlay root existence first, then assert tappability per-test.
- Keep CI simulator target aligned with local reproducible simulator generation (Xcode 26.4 currently stable on iPhone 17 in this repo) to reduce shard-only geometry/hit-point variance.
- `Build & Test` in `.github/workflows/ci.yml` enforces SwiftLint strictly via `./scripts/build.sh all`; lint warnings are treated as CI blockers.
- PR #516 failed solely on SwiftLint violations in `Tests/EyePostureReminderTests/Mocks/MockDateProvider.swift` (sorted imports) and `EyePostureReminder/Views/SettingsView.swift` (force unwrap + type body length over warning threshold).
- Surgical CI unblock pattern: keep behavior intact by replacing force unwraps with guarded optionals, fixing import ordering, and scoping any unavoidable lint suppression to the specific type.

## 2026-05-06 — Branch status + local validation gate (`ralph/app-store-version-guard`)

- Checked branch state before validation:
  - Current branch: `ralph/app-store-version-guard` at `5346eee`
  - No upstream tracking ref configured yet
  - Working tree is dirty with tracked edits across app/services/tests/docs/scripts plus untracked `.worktrees/` (must stay uncommitted)
- Ran required gate from repo root: `./scripts/build.sh all`
- Result: ❌ failed at lint stage (`SwiftLint --strict`) before tests, so PR/push flow should be blocked until lint debt is cleared.

### Learnings
- **2026-05-15: Team consolidation — 7 teams collapsed to 2 (Dev + Strategy).** You are now explicitly on the **Dev team** alongside Rusty, Linus, Livingston, Saul, Basher, Yen, Benedict, Virgil. Dev team owns code, tests, build, and CI. Strategy team (Danny, Tess, Reuben, Turk, Frank, Roman, Toulour, Denham, Sponder, Bashir, Matsui, Bruiser) handles product, design, research, legal, audits, and ASO. Scribe and Ralph remain on the roster outside both teams (silent infra). Use GitHub label `team:dev` for issue routing; see .squad/streams.json for canonical Dev workstream folder scopes.
- `./scripts/build.sh all` remains the correct pre-PR parity command; when it fails, the first actionable output is the SwiftLint `error:` list rather than xcodebuild output.
- For this branch snapshot, lint failures include both branch-touched files (for example `AppCoordinator+Helpers.swift` and `OverlayManagerTests.swift`) and pre-existing larger test-suite debt; CI gate status should be reported as blocked, not partially passed.

## 2026-05-06 — Scribe orchestration: Virgil branch validation blocked

- Orchestration log written: `.squad/orchestration-log/2026-05-06T00-35-56Z-virgil.md`
- Session log written: `.squad/log/2026-05-06T00-35-56Z-branch-validation.md`
- Decision merged from inbox to `.squad/decisions.md`
- Team updated via this history entry

## 2026-05-06 — Full gate pass + release automation handoff (`ralph/app-store-version-guard`)

- Ran the required parity gate from repo root: `./scripts/build.sh all`.
- Result: ✅ build, lint, and tests all passed (2075 tests, 0 failures).
- Prepared branch for push/PR while keeping `.worktrees/` untracked and out of stage.

### Learnings
- **2026-05-15: Team consolidation — 7 teams collapsed to 2 (Dev + Strategy).** You are now explicitly on the **Dev team** alongside Rusty, Linus, Livingston, Saul, Basher, Yen, Benedict, Virgil. Dev team owns code, tests, build, and CI. Strategy team (Danny, Tess, Reuben, Turk, Frank, Roman, Toulour, Denham, Sponder, Bashir, Matsui, Bruiser) handles product, design, research, legal, audits, and ASO. Scribe and Ralph remain on the roster outside both teams (silent infra). Use GitHub label `team:dev` for issue routing; see .squad/streams.json for canonical Dev workstream folder scopes.
- `./scripts/build.sh all` is now green on this branch snapshot, so merge gating can move to remote CI checks.
- Preserve reproducibility by excluding generated local result artifacts (for example `TestResults.xcresult/Info.plist`) from commits.

## 2026-05-15 — #646 fan-out

Issue #651 assigned: integrate swift-format + SwiftLint into CI pipeline. This makes Google Swift Style mechanically enforceable rather than aspirational. Depends on all remediation PRs (#647-652) merging first; enforcement gate should activate after codebase passes lint.

## 2026-05-15 — CI Clean-Build + Release-Config Speedup Audit

Conducted full audit of `scripts/build.sh`, `build-from-gitlab.yml` (main branch), `project.yml`, UITests/project.pbxproj, and ScreenTimeExtensions/project.pbxproj to identify cold-build speedup opportunities.

### Learnings

- **Double-compilation is the biggest CI waste.** `cmd_build` uses `xcodebuild build`; `cmd_test` uses `xcodebuild test` — the latter recompiles the entire app again. Switching `cmd_test` to `build-for-testing` + `test-without-building` (pattern already used correctly in `cmd_uitest`) eliminates ~40-50% of compile time from the build+test pipeline.
- **TCA + SwiftSyntax is a known expensive dependency.** 14 SPM packages pulled in; `swift-composable-architecture` brings `swift-syntax` and all its compilation units. `COMPILER_INDEX_STORE_ENABLE=NO` is a high-value CI flag because index store writes are proportional to compilation units — TCA multiplies this cost.
- **Main app project.yml has no Release config block.** `SWIFT_COMPILATION_MODE = wholemodule` exists in Release config of UITests (line 369) and ScreenTimeExtensions (line 523) pbxprojs but NOT in the XcodeGen-generated main app. Need to add `configs: Release: SWIFT_COMPILATION_MODE: wholemodule` to project.yml EyePostureReminder target.
- **108 test files use `@testable import EyePostureReminder`.** Release config defaults `ENABLE_TESTABILITY=NO`. Switching to Release for CI without forcing `ENABLE_TESTABILITY=YES` on test builds will break the build. Must be scoped to `build-for-testing`/`test` actions only.
- **UITest xctestrun PlistBuddy patch (build.sh line 663) hardcodes `Debug-iphonesimulator`.** If Release config is adopted for UI tests, this must change to `Release-iphonesimulator`. Flag for whoever applies the Release migration.
- **ModuleCache purge is unconditional in the workflow.** For cold builds (no DerivedData cache restore), the `rm -rf` is a no-op but shows up in logs. Gate it on `cache-hit` output from `actions/cache` to make it conditional. Saves ~20-30s on cold runs.
- **Workflow runner is `macos-latest`** (currently macOS 15, Apple Silicon). The `macos-15-xlarge` (M1 Pro, 6-core) costs ~8-10× more per minute but can cut cold Swift build times by 30-50%. Not recommended unless clean build time exceeds 20 min regularly.
- **`SIMULATOR: "platform=iOS Simulator,name=iPhone 17"` in workflow env** — requires iOS 18/26 runtime. Verify runner has it pre-installed or the `Ensure iOS Simulator runtime` step adds 5-10 min. Safer to use `OS=latest` and let Xcode pick.
- **No Mintfile in repo.** swift-format is managed via Homebrew only. SwiftLint also via Homebrew. No Mint toolchain to worry about for CI.
- **Skills written:** `.squad/skills/xcodebuild-fast-ci-flags/SKILL.md` — reusable pattern for fast clean CI builds.
- **Inbox notes written:** `.squad/decisions/inbox/virgil-ci-clean-release-speedups.md` and `virgil-release-config-ci.md` (for Rusty's arch review).

## 2026-05-17 — CI Clean-Build + Release-Config Speedup Audit (COMPLETED)

Completed full audit of `scripts/build.sh`, `build-from-gitlab.yml`, `project.yml`, UITests and ScreenTimeExtensions pbxprojs. Orchestration log written: `.squad/orchestration-log/2026-05-17T08-57-37Z-virgil.md`.

### Key Findings

- **Double-compilation is the biggest CI waste.** `cmd_build` → `xcodebuild build`; `cmd_test` → `xcodebuild test` (recompiles). UITests already use correct pattern: `build-for-testing` + `test-without-building`. Switching cmd_test to this pattern eliminates ~40–50% of compile time from build+test pipeline.
- **COMPILER_INDEX_STORE_ENABLE=NO, DEBUG_INFORMATION_FORMAT=dwarf:** TCA+SwiftSyntax multiplies index store writes; skipping index store + dSYM generation saves 1–3 min on cold builds.
- **ModuleCache purge gating:** Unconditional rm is no-op on cold runs; gate on cache-hit to save 20–30s.
- **main app project.yml missing Release config:** Need to add `SWIFT_COMPILATION_MODE: wholemodule` to EyePostureReminder target.
- **UITest xctestrun PlistBuddy patch:** Line 663 hardcodes `Debug-iphonesimulator` — must update to `Release-iphonesimulator` if Release adopted.

### Decision Merged

CI optimization plan merged into `.squad/decisions.md` as phased approach: Phase 0 (cmd_test refactor), Phase 1 (speedup flags), Phase 2 (Release config — blocked on Rusty source-change sign-off), Phase 3 (optional runner upgrade).

### Status

Awaiting Yashas authorization for Phase 0/1 implementation. Proposed diffs prepared but not applied.

### Learnings

- **2026-05-17: CI Architecture pre-review coordination pattern.** When proposing major CI changes with architectural implications (e.g., switching to Release config), proactively flag relevant reviewers (e.g., Rusty for app architecture) in decision inbox BEFORE Scribe merge. This enables parallel audit feedback and faster approval cycles.
- **Xcodebuild action patterns:** `build-for-testing` creates app+test binaries without running tests; `test-without-building` reuses those binaries. This is the gold standard for CI pipelines that split compile and test steps. Mirror this in all SPM+Xcode workflows.
- **SPM + Release config complexity:** SPM projects without xcodeproj (executable targets) cannot add custom Xcode configurations. Use `OTHER_SWIFT_FLAGS` to inject `"-DCI"` flag on test actions only — this flows through to SPM targets and enables `#if CI` semantics without needing a true Xcode config.

## 2026-05-17 — Release + wholemodule script implementation (APPLIED)

Directive from Yashas: no more CI YAML edits — all build config changes go through `scripts/build.sh`.

### What Changed (commit `edc772c`, branch `fix/run-sh-and-overlay-timeout`, MR #808)

1. **`CONFIGURATION=Release` default** — added near top of script, above constants. Env-var overridable: `CONFIGURATION=Debug ./scripts/build.sh build`.
2. **`SWIFT_COMPILATION_MODE=wholemodule` in XCODE_FLAGS** — injected as xcodebuild build-setting override. No project.yml edit needed.
3. **`ENABLE_TESTABILITY=YES` on `build-for-testing` only** — passed directly to the `run_xcodebuild` call in `cmd_test` and `cmd_uitest`. NOT on `cmd_build` (shippable binary stays clean).
4. **`cmd_test` refactored** to `build-for-testing` + `test-without-building` — eliminates the double-compile. `.xctestrun` is located after build-for-testing via `find "${DERIVED_DATA_PATH}/Build/Products" -name "${SCHEME}_*.xctestrun"`. Pattern mirrors the existing `cmd_uitest` logic.
5. **PlistBuddy path + `products_dir` variable** fixed: `Debug-iphonesimulator` → `${CONFIGURATION}-iphonesimulator` (both at the PlistBuddy call and the `local products_dir` assignment below it).
6. **Free CI flags added** to XCODE_FLAGS: `COMPILER_INDEX_STORE_ENABLE=NO`, `DEBUG_INFORMATION_FORMAT=dwarf`, `ONLY_ACTIVE_ARCH=YES`.
7. **Header + info lines updated**: script header comment shows CONFIGURATION override; `cmd_build`, `cmd_test`, `cmd_uitest` all print `info "Configuration: $CONFIGURATION"`. Usage function documents `CONFIGURATION` and `SIMULATOR` env vars.

### Surprises / Line Number Notes

- Original audit proposed `cmd_test` line range ~458–496; actual lines were correct at review time but shifted +2 due to the header comment addition earlier in the session. Edits applied cleanly against the string anchors, not line numbers — no drift issues.
- `cmd_clean` also had a hardcoded `xcodebuild clean` without `-configuration`; added it for completeness (not in original task scope but logically consistent).
- No `#if DEBUG` source file edits were made per directive — this remains a known follow-up item.

### Known Remaining Issue

**22 `#if DEBUG` guards** in UITestMode, AppDelegate, EyePostureReminderApp, HomeView, AnalyticsLogger will cause test failures under Release config. CI will surface these on next run. Separate Yashas authorization needed before those source edits can land.

### Learnings

- **Injecting build settings via xcodebuild CLI args (not project.yml)** is the correct pattern when CI workflow YAMLs are frozen. `XCODE_FLAGS` array in `build.sh` is the single source of truth for all build-setting overrides.
- **`ENABLE_TESTABILITY=YES` scoping is critical**: passing it only on `build-for-testing` calls (not the plain `build` action) keeps the production binary clean. Verified pattern: add it as a trailing positional arg to `run_xcodebuild`; it becomes part of `"$@"` which xcodebuild treats as a build-setting override.
- **`cmd_uitest` had TWO hardcoded `Debug-iphonesimulator` references**, not one — both the PlistBuddy `-c Set` string and the `local products_dir` variable assignment on the line below. Both must change together or SPM binary copy into .app bundle fails at runtime.

## 2026-05-17 — UI Tests Off CI Until TCA Rewrite (Directive Captured)

**Event:** User directive — UI tests disabled on CI until TCA rewrite ships (Work Item #806 filed by Livingston).

**Implication for Release+wholemodule CI (MR #808):**

✅ **No immediate impact on your work.** The `CONFIGURATION=Release` and `SWIFT_COMPILATION_MODE=wholemodule` defaults you applied in MR #808 do NOT need to worry about UITest behavior under Release config for CI purposes — UI tests are off CI now.

**Timeline:**
1. UI tests stay off CI during Livingston's TCA rewrite work (Work Item #806)
2. Once TCA rewrite ships and re-enable gate is cleared, UITest guards may need Release-config treatment (separate decision at that time)
3. For NOW: Your Release+wholemodule implementation is correct as-is

**Related Decision:** `.squad/decisions.md` — "2026-05-17 — User Directive: UI Tests Disabled on CI Until TCA Rewrite"

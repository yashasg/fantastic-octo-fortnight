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

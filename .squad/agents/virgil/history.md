# Virgil — History

## Core Context

- **Project:** Eye & Posture Reminder — lightweight iOS app with background timers and overlay reminders
- **Stack:** Swift, SwiftUI (iOS 16+), MVVM, UserNotifications, UIKit overlay, UserDefaults
- **Owner:** Yashas
- **Joined:** 2026-04-24

## Wave 8 — CI/CD Full Audit Fix #66 (2026-04-25)

**Task:** Fix all P0/P1/P2 issues from `.squad/decisions/inbox/virgil-full-audit.md`  
**Outcome:** ✅ All fixes confirmed in HEAD (36a5071)

**Fixes applied:**
- **P0-1:** Added `permissions: contents: read, actions: read` to both `ci.yml` and `testflight.yml`
- **P1-1:** Added `brew install swiftlint` step to `ci.yml` before the lint step — lint was a silent no-op on every CI run
- **P1-2:** Replaced `xcrun altool --upload-app` (removed in Xcode 15) with `xcodebuild -exportArchive` using modern `-authenticationKeyPath/-authenticationKeyID/-authenticationKeyIssuerID` flags and inline `ExportOptions.plist` with `destination: upload`
- **P1-3:** Added `-enableCodeCoverage YES` to `cmd_test` in `build.sh`; added `xcrun xccov view --report` step in `ci.yml`
- **P1-4:** Added CI-pass guard step to `testflight.yml` that checks `gh api .../check-runs` before deploying
- **P1-5:** Added `if: always()` cleanup step to remove `asc_api_key.p8` from runner temp
- **P2-1:** Fixed DerivedData cache key from `hashFiles('**/*.swift')` → `hashFiles('Package.swift', 'Package.resolved')`
- **P2-2:** Switched both workflows from `macos-14` to `macos-15` (native Xcode 16.x lifecycle)
- **P2-3:** Added `echo "MARKETING_VERSION=unknown"` in the else branch of Info.plist check
- **P2-4:** Removed the broken commented-out `upload-testflight` job block from `ci.yml`
- **P2-5:** Collapsed `cmd_check` in `build.sh` to an explicit alias for `cmd_build` with a warning message


### 2026-04-26 — Quality Sweep: CI/CD & Build Config Quality Audit

**Quality sweep findings from 8-agent parallel audit (read-only, no changes made):**

**1 Critical Issue:**

1. **Doubled path in scripts/set-build-info.sh L34** — Fallback path resolves to `EyePostureReminder/EyePostureReminder/Info.plist` (doubled segment). Should be `EyePostureReminder/Info.plist`. Low probability in current usage (fires when `INFOPLIST_FILE`/`SRCROOT`/`BUILT_PRODUCTS_DIR`/`PRODUCT_NAME` all unset), but latent bug. Script exits `warning:` with code 0, masking misconfiguration. **Action:** Fix line 34.

**5 Warnings (Config Hygiene):**

1. **Stale audit scripts committed** — 6 one-off audit scripts from review session pollute repo root. Not project build/run tools: `audit_workflows.sh`, `detailed_audit.py`, `detailed_manual_audit.sh`, `edge_case_audit.sh`, `final_audit.sh`, `script_validation.sh`. **Action:** `git rm` all six.

2. **No concurrency group in `.github/workflows/ci.yml`** — Rapid commits to PR branch trigger parallel runs, wasting CI minutes on stale jobs. **Action:** Add concurrency group with `cancel-in-progress: true`.

3. **Coverage enforcement threshold 50% vs stated target 80%+** — CI gate too lenient. decisions.md records 80%+ coverage across all modules. **Action:** Raise threshold to 75% (headroom for new untested code), stretch goal 80%.

4. **deploy-testflight job has no timeout-minutes** — Archive + App Store Connect upload can hang indefinitely during Apple delays. Job consumes macOS runner slot until GitHub's 6-hour limit kills it. **Action:** Add `timeout-minutes: 45`.

5. **Untracked build artifacts not in .gitignore** — `audit_check` (compiled Mach-O), `build_check.log`, `build_output.log` in working tree. Risk accidental future commits. **Action:** Add to `.gitignore`.

**4 Suggestions (Optimization/Safety):**

1. **Cache SwiftLint brew install** — `brew install swiftlint@0.57.0` takes 30-60s per run. Wrap with `actions/cache` keyed on version to skip re-download.

2. **Poll instead of fixed sleep for simulator boot** — `ensure_booted()` sleeps 2s after `xcrun simctl boot`. Too short on cold CI. Consider polling `xcrun simctl list devices | grep Booted` in loop.

3. **Consider exit 1 (not exit 0) on missing plist** — `set-build-info.sh` L39 exits 0 when plist not found. Future Xcode setup would silently no-op during build phase, masking config error. Non-zero exit safer.

4. **Consider force_try: error (not warning)** — `.swiftlint.yml` allows `try!` in app code. Consider `error` severity for non-test code (or use custom rules to exclude tests).

**What's Working Well:**
- Package.swift clean and minimal
- All scripts use `set -euo pipefail`
- xcpretty fallback correct with pipefail
- GitHub Actions versions pinned at v4/v7
- testflight.yml uses modern xcodebuild API (not deprecated altool)
- Permissions scoped (`contents: read`, not `write-all`)
- DerivedData cache key uses Package.swift + Package.resolved
- .swiftlint.yml SwiftUI-appropriate with well-reasoned rules
- API key and keychain cleanup use `if: always()` guards

**Immediate actions (ASAP):**
1. Fix doubled path in set-build-info.sh L34
2. git rm 6 stale audit scripts
3. Add concurrency group to ci.yml
4. Add `.gitignore` entries for build artifacts

**Next priority (before Phase 2):**
1. Raise coverage threshold to 75%
2. Add timeout-minutes to deploy-testflight
3. Cache SwiftLint install

**Next owner action:** Address critical path bug and remove stale scripts this week.

## Wave 10 — Issues #122/#123/#124 (CI/Build Improvements)

**Task:** Fix three GitHub Issues: remove stale audit scripts (#122), add CI concurrency group (#123), raise coverage threshold (#124)
**Outcome:** ✅ All three committed to main

**Changes made:**
- **#122:** `git rm`'d 6 tracked audit scripts (`audit_workflows.sh`, `detailed_audit.py`, `detailed_manual_audit.sh`, `edge_case_audit.sh`, `final_audit.sh`, `script_validation.sh`). Added `.gitignore` entries for all 6 plus `audit_check`, `build_check.log`, `build_output.log`. Note: scripts were already removed from tracking in a prior commit (`673066d`); the key deliverable here is the `.gitignore` guard.
- **#123:** Added `concurrency: group: ci-${{ github.ref }}, cancel-in-progress: true` to `.github/workflows/ci.yml` at the top-level workflow scope (between `permissions` and `env`).
- **#124:** Raised coverage gate in `.github/workflows/ci.yml` from 50% → 80%, aligning CI enforcement with the team's stated 80%+ target.

**Learnings:**
- **Concurrency group placement in GitHub Actions:** The `concurrency` key must be at the top-level workflow scope (same level as `on`, `permissions`, `env`, `jobs`), NOT inside a job. This cancels all concurrent runs for the same ref across all jobs in the workflow.
- **Pre-flight git ls-files check:** Before running `git rm`, always verify with `git ls-files <path>` to confirm the file is actually tracked. Avoids confusing no-op `git rm` calls when files were already removed in a prior commit.
- **Coverage threshold is 80%:** The enforced CI gate in `ci.yml` is now 80% (`$COVERAGE < 80`). Any PR that drops coverage below 80% will fail CI.

## Wave 10 — Fix #113: set-build-info.sh doubled path (2026-04-26)

**Task:** Fix GitHub Issue #113 — doubled path segment in `scripts/set-build-info.sh` L34  
**Outcome:** ✅ Fixed and committed (640c970)

**Changes made:**
1. **L34 — Doubled path fixed:** `EyePostureReminder/EyePostureReminder/Info.plist` → `EyePostureReminder/Info.plist`. Fallback branch now resolves correctly when all Xcode env vars are unset.
2. **L38-39 — Exit 1 on missing plist:** Changed `warning:` + `exit 0` to `error:` + `exit 1`. Silent no-op on missing plist would mask misconfiguration in future Xcode build phase setups; failing loudly is safer and aligns with `set -euo pipefail` philosophy already used in the script.

**Learning:** When a script uses `set -euo pipefail` for resilience, soft-failing with `exit 0` in error branches is an anti-pattern — it defeats the purpose of strict mode. Errors on missing required resources should always be non-zero exits.

## Wave 11 — Issues #139/#140 (SwiftLint + Test Typo)

**Task:** Fix GitHub Issues #139 (invalid swiftlint key) and #140 (test method name typo)
**Outcome:** ✅ Both committed to main (364cf4a, 8cbe352)

**Changes made:**
- **#139:** Removed `only_single_mutable_parameter: true` from `trailing_closure` config in `.swiftlint.yml` — this key does not exist in current SwiftLint and causes a config validation error. Moved `trailing_closure` from `opt_in_rules` to `disabled_rules` with a comment explaining the intent (SwiftUI DSL multi-argument calls).
- **#140:** Renamed `test_showOverlay_withNoActiveWindowScene_isOverlayVisibleRemainsFlase` → `test_showOverlay_withNoActiveWindowScene_isOverlayVisibleRemainsFalse` in `Tests/EyePostureReminderTests/RegressionTests.swift` L873.

**Learnings:**
- **`trailing_closure` has no rule-level config options in current SwiftLint:** The rule is a simple opt-in/opt-out. Any key under `trailing_closure:` in the YAML will cause a config parse error. The SwiftUI-friendly intent (don't enforce on multi-arg calls) is better achieved by disabling the rule entirely.
- **Test method names are part of the public API surface for CI:** Typos in test names surface in CI logs and coverage reports; they should be treated as code defects, not cosmetic issues.

## Wave 12 — UI Test Infrastructure (#110)

**Task:** Implement UI test infrastructure per Rusty's architecture proposal (Issue #110)  
**Outcome:** ✅ All three parts committed to main (fe241ac)

**Changes made:**
- **Part 1:** `UITests/project.yml` — XcodeGen spec for minimal UITest bundle target. References local Package.swift via `packages: path: ..` so the app builds from SPM. No app target in xcodeproj (Package.swift stays source of truth).
- **Part 1:** `scripts/setup-uitests.sh` — installs xcodegen via Homebrew if missing, then runs `xcodegen generate`. Generates both `.xcodeproj` and `.xcworkspace`.
- **Part 2:** Added `uitest` job to `.github/workflows/ci.yml` — parallel to `build-and-test`, `macos-15`, installs xcodegen, runs setup, boots simulator, runs xcodebuild with `-parallel-testing-enabled YES -maximum-concurrent-test-simulator-destinations 3`. xcpretty fallback pattern. Uploads `UITestResults.xcresult`.
- **Part 3:** Added `cmd_uitest()` to `scripts/build.sh`. Uses `-workspace` (required for local package resolution). Auto-runs setup if workspace not present. Uses same `detect_destination()` and `DERIVED_DATA_PATH` as other subcommands.
- **Supporting:** `.gitignore` updated with `UITests/*.xcodeproj/` and `UITests/*.xcworkspace/` (generated artefacts). `Tests/EyePostureReminderUITests/README.md` updated to remove "not yet runnable" caveat and document setup steps.

## 2026-04-28 — Code Signing & Provisioning Checklist

**Session:** 2026-04-28T22:46:23Z (Rusty + Virgil parallel)

**Task:** Provide CI/CD code signing and provisioning checklist for TestFlight/App Store distribution setup.

**Outcome:** ✅ Complete + Issue identified

**Deliverables:**
- Code signing checklist (certificates, provisioning profiles, GitHub secrets)
- Standard GitHub secret names: `ASC_API_KEY_ID`, `ASC_API_KEY_ISSUER_ID`, `ASC_API_KEY_P8`
- Xcode signing verification guidance

**Repository issue identified:**
- **Bundle ID mismatch:** Documentation uses `com.yashasg.eyeposturereminder` (lowercase); UITests/project.yml uses `com.yashasg.EyePostureReminder` (mixed case)
- **Impact:** Must be resolved before archive workflow
- **Recommendation:** Coordinate with Rusty (Apple Developer guidance) and Danny (docs owner) to unify on `com.yashasg.eyeposturereminder` and correct UITests config

**Coordination outcome:** Rusty confirmed `com.yashasg.eyeposturereminder` as canonical Bundle ID. Virgil awaits UITests correction to validate CI/CD workflows against unified ID.

## Wave 13 — Apple Developer Entity Guidance (2026-04-28)

**Task:** Explain Apple Developer/App Store Connect implications of Puzzle Quest LLC being registered in wrong state (WA instead of NM).
**Outcome:** ✅ Advisory delivered. Decision written to inbox.

## Wave 14 — Fix AUTH_FLAGS unbound variable (2026-05-XX)

**Task:** Fix `AUTH_FLAGS[@]: unbound variable` crash in `scripts/build_signed.sh` under `set -euo pipefail` on macOS Bash 3.2.  
**Outcome:** ✅ Fixed. Bug confirmed gone; archive proceeds past the crash to Xcode signing phase.

**Root cause:** macOS ships Bash 3.2.57. Under `set -u` (nounset), expanding an empty indexed array with `"${array[@]}"` throws "unbound variable". This is Bash 3.2-specific; Bash 4+ handles it cleanly.

**Fix:** Replace all three array expansions (`PROVISIONING_FLAGS`, `AUTH_FLAGS`, `SIGNING_BUILD_SETTINGS`) in every `xcodebuild` call with the `${var+value}` guard pattern:
```bash
# BEFORE (breaks on empty array with nounset + Bash 3.2)
"${AUTH_FLAGS[@]}"
# AFTER (safe: expands to nothing when empty, full array when populated)
"${AUTH_FLAGS[@]+"${AUTH_FLAGS[@]}"}"
```

**Post-fix archive result:** Archive now proceeds past the array expansion, then fails with a pre-existing Xcode signing conflict (`conflicting provisioning settings` — SPM sub-targets are automatically signed for development but `CODE_SIGN_IDENTITY=Apple Distribution` is passed). This is a separate unrelated issue.

## Learnings

- **macOS Bash 3.2 empty-array nounset pattern:** Use `"${array[@]+"${array[@]}"}"`  — the outer `${var+word}` substitution returns nothing if unset/empty, so the inner expansion is never evaluated on an empty array. This is the canonical portable fix for Bash 3.2 `set -u` + empty array. See: https://stackoverflow.com/a/61551944
- **D-U-N-S + Apple enrollment state matching:** Apple verifies D-U-N-S against the legal entity at Organization enrollment time. If the registered state is wrong, the D-U-N-S will reflect the wrong state — correct the legal entity BEFORE applying for D-U-N-S.
- **Individual → Organization migration is destructive:** Different Team ID = all existing certificates and provisioning profiles invalidated. Always enroll as Organization if an LLC is the publishing entity.
- **State of registration ≠ home office address:** Apple cares about legal formation state (for D-U-N-S match). Business mailing address can be the home office in a different state — that's fine.
- **Certificates NOT affected by state-of-registration changes** as long as the LLC name stays the same (Team ID unchanged).

### 2026-04-28 — Apple Developer Enrollment Sequencing for LLC Entity Correction

- **Task:** Assess operational implications of Puzzle Quest LLC being currently registered in Washington when user intends New Mexico, with home office in Washington.
- **Guidance:** Technical sequencing advice issued via `.squad/decisions/inbox/virgil-apple-developer-entity-state.md` (later merged to main decisions.md).
- **Key Decisions:**
  - Do NOT enroll as Organization until D-U-N-S reflects corrected (New Mexico) state
  - Organization enrollment is correct (not Individual); D-U-N-S must match final legal entity
  - State of formation matters for D-U-N-S/legal entity match; Washington home office is fine as mailing address
  - Code signing profiles/certs tied to Team ID (legal entity name + D-U-N-S), not formation state
  - All local dev and CI/CD pipeline can proceed unblocked
  - Bundle ID `com.yashasg.eyeposturereminder` is confirmed technical identifier (does not need LLC name)
- **Order of Operations:**
  1. Correct LLC registration to New Mexico
  2. Verify NM registration active
  3. Request D-U-N-S
  4. Wait for D-U-N-S verification (~14 business days)
  5. Enroll as Organization ($99/year)
  6. App Store Connect & TestFlight setup
- **Blocked Items:** D-U-N-S application, Organization enrollment, App Store Connect app record, distribution certs, TestFlight upload
- **Go-Ahead Items:** All local dev, CI/CD pipeline, code signing (dev team), TestFlight workflow prep
- **Coordination:** Virgil work synchronized with Frank (legal implications) and Coordinator (team directive capture).


## Wave 9 — Focus Status Portal Capability Question (2026-04-28)

**Task:** Explain why Focus Status doesn't appear in Apple Developer portal capabilities and what to do about it.
**Outcome:** ✅ Guidance provided, skill documented.

**Key finding:** Focus Status (`com.apple.developer.focus-status`) is an **entitlement-only capability** — it does NOT appear as a checkbox in Apple Developer portal > Identifiers > Capabilities. This is expected Apple behavior. The entitlement in `.entitlements` is sufficient. Project already has it correctly set. No portal action needed; don't block App ID creation.

**Skill written:** `.squad/skills/apple-focus-status-capability/SKILL.md`

**Manifest processed:** 2026-04-28T22:56:22Z
- Orchestration log: `.squad/orchestration-log/2026-04-28T22:56:22Z-virgil.md`
- Session log: `.squad/log/2026-04-28T22:56:22Z-focus-status-capability.md`

## Learnings

### 2026-05-XX — Keychain Team ID auto-detection pattern for build scripts

- **Pattern:** Use `security find-identity -p codesigning -v | grep "Apple Distribution" | grep -oE '\([A-Z0-9]{10}\)' | tr -d '()' | sort -u` to extract unique Team IDs from Keychain code-signing identities without exposing their values.
- **Single-team detection:** If exactly one unique Team ID is extracted, it can be used silently. Never print the value in any output path. In doctor/status output, print "detected from Keychain" — not the value.
- **Ambiguous case:** If multiple Team IDs are found, fail with guidance to set `APPLE_TEAM_ID` explicitly. Do not guess or use the first match.
- **Priority order:** Explicit env var override (`APPLE_TEAM_ID` / `DEVELOPMENT_TEAM`) always wins; Keychain detection is a fallback only.
- **Provisioning profiles are not Keychain-sourced:** Always handled by Xcode automatic signing or explicit env vars — document this explicitly in scripts and README to avoid confusion.
- **Security note:** Use `|| true` after the pipeline in strict `set -euo pipefail` scripts to guard against no-match exit codes from grep.

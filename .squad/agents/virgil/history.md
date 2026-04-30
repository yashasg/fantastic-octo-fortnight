# Virgil — History

## Core Context

- **Project:** kshana (formerly Eye & Posture Reminder) — lightweight iOS app with True Interrupt Mode via Screen Time APIs
- **Stack:** Swift, SwiftUI (iOS 16+), MVVM, UserNotifications, UIKit overlay, UserDefaults, FamilyControls (Phase 3+)
- **Owner:** Yashasg
- **Joined:** 2026-04-24

## 2026-04-29 — Screen Time Shield Build/Signing Pivot

**Task:** Document build/signing implications for Screen Time Shield implementation.  
**Status:** ✅ Complete — orchestration log filed

**Key outcome:** Phase 3 requires 4 targets (main app + 3 extensions), 4 provisioning profiles, 4 entitlements files, and a root-level `project.yml` (XcodeGen). FamilyControls entitlement approval (case ID 102881605113) is the sole external blocker; all infrastructure work can proceed in parallel. Decision merged into `.squad/decisions.md`.

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

## Wave 15 — Fix signing conflict in build_signed.sh (CODE_SIGN_STYLE vs CODE_SIGN_IDENTITY)

**Task:** Fix Xcode exit 65 conflict: `EyePostureReminder is automatically signed for development, but a conflicting code signing identity Apple Distribution has been manually specified.`  
**Outcome:** ✅ Fixed. Conflict gone; archive progresses past signing to a separate (expected) provisioning issue.

**Root cause:** `build_signing_build_settings()` always injected `CODE_SIGN_IDENTITY=Apple Distribution` as an xcodebuild build setting override even when `CODE_SIGN_STYLE=Automatic`. Xcode treats this as a contradiction: automatic signing selects the identity itself (development for local, distribution for archive actions), but an explicit `CODE_SIGN_IDENTITY` override forces a specific cert, causing the conflict.

**Fix:** Only inject `CODE_SIGN_IDENTITY` when `SIGNING_STYLE=manual`. In automatic mode, omit it entirely — Xcode picks the appropriate identity for the action. Also normalised the `CODE_SIGN_STYLE` value to properly-cased `Automatic`/`Manual` as Xcode expects.

**Post-fix archive result:** Exit 65 conflict resolved. Archive proceeds to provisioning phase and fails with `No Accounts` / `No profiles found` — this is a separate, expected credential issue (Apple ID not signed into Xcode on this machine), not a script bug.

## Learnings

- **Never set CODE_SIGN_IDENTITY with CODE_SIGN_STYLE=Automatic:** Automatic signing owns identity selection; overriding CODE_SIGN_IDENTITY simultaneously causes Xcode exit 65 "conflicting provisioning settings". Remove CODE_SIGN_IDENTITY from the xcodebuild command entirely when using automatic signing.
- **CODE_SIGN_STYLE capitalisation:** Xcode build setting values are properly-cased: `Automatic` and `Manual` (not lowercase). While xcodebuild accepts lowercase on the command line, use the canonical form to avoid surprises.
- **Distribute via ExportOptions, not archive flags:** The signing certificate for distribution (Apple Distribution) belongs in `ExportOptions.plist` (as `signingCertificate`), not as a build setting during archive. Archive phase uses automatic signing; export phase applies the distribution identity.

## Wave 16 — Signed Build Parity Audit

**Task:** Audit and reconcile `build_signed.sh` vs `build.sh`/`run.sh` — "only difference should be signing."
**Outcome:** ✅ Fixed. Three concrete discrepancies removed (ba18867).

### Discrepancies found and resolved

**1. Missing CFBundleVersion injection (critical for TestFlight)**
- `build.sh` / `run.sh` — simulator builds, no build number needed.
- `testflight.yml` (before) — mutated *source* `Info.plist` with PlistBuddy before xcodebuild.
- `build_signed.sh` (before) — no injection at all. Every archive carried `CFBundleVersion=1`; TestFlight rejects duplicate build numbers.
- **Fix:** Added `inject_build_number()` to `build_signed.sh`. Patches the *archive's* built `Info.plist` after `xcodebuild archive` succeeds. Never touches source `Info.plist`. Uses `$BUILD_NUMBER` when set, falls back to `YYYYMMDDHHmm` timestamp.

**2. testflight.yml bypassed build_signed.sh entirely (broken CI path)**
- The CI archive step was `xcodebuild archive -scheme EyePostureReminder` with no `-project` flag on a pure SPM package. SPM `.executable` targets cannot be archived for iOS distribution without a `.xcodeproj` app-wrapper target — this would always fail.
- **Fix:** Replaced the two-step archive + export/upload with a single `./scripts/build_signed.sh upload` call. Added `brew install xcodegen`. Removed source Info.plist CFBundleVersion mutation (now handled by `inject_build_number`).

**3. Bundle ID case mismatch in UITests/project.yml**
- Canonical ID: `com.yashasg.eyeposturereminder` (confirmed Wave 13).
- `UITests/project.yml` was using mixed-case `com.yashasg.EyePostureReminder`.
- **Fix:** Aligned to `com.yashasg.eyeposturereminder` / `com.yashasg.eyeposturereminder.uitests`.

### Why XcodeGen is unavoidable in build_signed.sh

`xcodebuild archive` for iOS distribution requires a `.xcodeproj` with a signed app-wrapper (`application`) target. Swift Package `.executable` targets cannot be directly archived. The generated project mirrors the UITests project pattern (app-wrapper + SPM package dependency), differing only in signing settings. **This complexity is justified, not avoidable.**

## Learnings

- **Inject build numbers into archive, not source:** Patch `<archive>.xcarchive/Products/Applications/<App>.app/Info.plist` post-archive to avoid dirty working tree on CI. Source Info.plist should only carry the static placeholder value; build numbers are ephemeral.
- **CI workflow must use build_signed.sh:** A workflow that raw-calls `xcodebuild archive -scheme X` on an SPM package without a `-project` flag will fail silently (or with an obscure error). The script's XcodeGen wrapper is mandatory for iOS distribution archives.
- **Bundle IDs are case-sensitive in iOS:** `com.yashasg.EyePostureReminder` ≠ `com.yashasg.eyeposturereminder` from Apple's perspective. Keep all project files and scripts aligned to the canonical form registered in App Store Connect.
- **"No Accounts" from xcodebuild ≠ "not logged in to Xcode":** Logging into Xcode.app is necessary but not sufficient. `xcodebuild` requires provisioning profiles to already be downloaded to `~/Library/MobileDevice/Provisioning Profiles/`. The fix is: Xcode → Settings → Accounts → select team → **"Download Manual Profiles"**. Zero profiles in that directory reliably predicts this failure mode. Detect it early by grepping the profiles dir for the bundle ID before running the archive.
- **Redact Team IDs from xcodebuild pipeline output using Perl:** The existing `redact_stream` Perl filter handles all secret values (Team ID, profile specifier, ASC key path/ID/issuer). Pass env vars via `REDACT_*` prefix and inline the script with `-pe`. Merge stderr into stdout with `2>&1` before the pipe so redaction covers both streams.
- **Provisioning failure guidance must be in-band (not docs-only):** When `xcodebuild archive` fails, the script exits via `set -e` before any guidance can print. Wrap the call with `if ! run_xcodebuild ...; then print_hint; exit 1; fi` to fire guidance inline. `if !` suppresses `set -e` for the condition and enters the else branch on failure.
- **"No profiles for canonical app bundle ID" vs "No Accounts":** The former is a manual-signing failure (profile not installed locally). The latter is an automatic-signing failure (no Xcode account logged in AND no ASC API key). Both are provisioning failures but require different remedies. The early `ensure_manual_distribution_profile` guard catches the manual-signing case before xcodebuild runs; the "No Accounts" error surfaces only when SIGNING_STYLE=automatic.

### 2026-04-28 — Build Signing & Provisioning Enhancements (Wave 17 Parallel)

**Task:** Improve CI/CD build signing, provisioning, and error handling in `scripts/build_signed.sh`.

**Outcome:** ✅ Complete — all signing workflows refined, error guidance improved.

**Work completed:**

1. **Keychain Auto-Detection for APPLE_TEAM_ID**
   - Implemented `infer_team_id_from_keychain()` in `build_signed.sh`
   - Uses `security find-identity -p codesigning -v` to detect single Team ID
   - Pattern: explicit env var always wins; ambiguous Keychain fails with guidance
   - No sensitive output — "detected from Keychain" only

2. **Automatic Signing vs CODE_SIGN_IDENTITY Conflict Fix**
   - Pattern: do NOT inject `CODE_SIGN_IDENTITY` when `CODE_SIGN_STYLE=Automatic`
   - Fixes Xcode exit-65 error (conflicting manual/automatic identity)
   - Distribution identity now flows through `ExportOptions.plist` only (export phase)

3. **Empty Array Expansion Fix (macOS Bash 3.2 nounset crash)**
   - Replaced all array expansions with `${var[@]+"${var[@]}"}` guard pattern
   - Fixes unbound variable crash on empty `AUTH_FLAGS`, `PROVISIONING_FLAGS`, `SIGNING_BUILD_SETTINGS`
   - Validated: `bash -n scripts/build_signed.sh` ✅, manual archive ✅

4. **Provisioning Failure Guidance Pattern**
   - Added `print_archive_failure_hint()` for automatic & manual signing failures
   - Merged stderr into stdout before redaction (`2>&1`)
   - In-band guidance at point of failure (more discoverable than README)

5. **Early Profile Detection & Guidance**
   - Added `cmd_doctor` and `cmd_archive` pre-flight checks
   - Detects empty `~/Library/MobileDevice/Provisioning Profiles/` directory
   - Emits exact remediation steps (Xcode → Accounts → Download Manual Profiles)

**Decisions filed:**
- `.squad/decisions/decisions.md` — 6 decisions:
  - Keychain auto-detection
  - CODE_SIGN_IDENTITY conflict fix
  - Empty array nounset crash fix
  - Provisioning failure guidance
  - Early profile detection
  - Signed build parity (build_signed.sh vs build.sh)

**Key patterns:**
- Keychain queries for convenience, but CI/CD always explicit (no auto-detection reachable in CI)
- Error guidance inline at failure point, not README-only
- All signing workflow improvements backward-compatible

## Wave 18 — TestFlight Export (2026-04-28)

**Task:** Produce a fresh signed export suitable for TestFlight from the current HEAD (dirty worktree with pre-existing onboarding/HomeView/signing changes).
**Outcome:** ✅ Export succeeded. IPA validated and ready for upload.

**Command run:**
```
./scripts/build_signed.sh export
```

**Artifact:**
- `DerivedData/SignedBuild/Export/kshana.ipa`

**Validation results:**
| Field | Value | Status |
|---|---|---|
| CFBundleIdentifier | com.yashasg.eyeposturereminder | ✅ |
| CFBundleShortVersionString | 0.2.0 | ✅ |
| CFBundleVersion | 2 (App Store Connect managed) | ✅ |
| UIDeviceFamily | [1] — iPhone only | ✅ |
| UISupportedInterfaceOrientations | [UIInterfaceOrientationPortrait] | ✅ |
| CFBundleName | kshana | ✅ |
| Signing cert | Apple Distribution | ✅ |
| Provisioning profile | kshana App Store Distribution | ✅ |
| Architecture | arm64 | ✅ |
| Dark AppIcon appearances | 0 | ✅ |

**Build number note:** `inject_build_number()` patched the archive to `202604282122`, but `xcodebuild -exportArchive` with `manageAppVersionAndBuildNumber:true` (Xcode default for `app-store-connect` method) overrode it to `2` via App Store Connect query. This is correct — Xcode found build `1` already submitted and assigned the next sequential number. The `inject_build_number()` function is effectively superseded when `manageAppVersionAndBuildNumber=true` is active.

**Dirty worktree included:** Yes — onboarding pickers, 1-min test interval, HomeView, and signing/icon changes are included in this build as intended.

**Upload step (not automated — no ASC API key supplied):**
```
./scripts/build_signed.sh upload
```
Or drag `DerivedData/SignedBuild/Export/kshana.ipa` into Transporter.app.

## Learnings

- **`manageAppVersionAndBuildNumber=true` is Xcode's default for `app-store-connect` export:** When not explicitly set in ExportOptions.plist, Xcode contacts App Store Connect during `-exportArchive`, queries the current highest build number for that bundle ID + version, and auto-assigns the next one. This means `inject_build_number()` (which patches the archive post-archive) is silently overridden during export. For predictable build numbers in CI, set `manageVersionAndBuildNumber=false` in ExportOptions and rely solely on `inject_build_number()` / `BUILD_NUMBER`.
- **App Store Connect query during local export is silent:** The `IDEDistributionAnalyzeVersionStep` + `IDEDistributionFetchAppRecordStep` run even for a local `destination=export`. If Xcode has a signed-in Apple ID with access to the App Store Connect record, it will manage the build number automatically. Check xcdistributionlogs for `manageAppVersionAndBuildNumber` to confirm this behavior.
- **Distribution export succeeds from dirty worktree:** `./scripts/build_signed.sh export` correctly includes all working-tree changes (staged and unstaged). This is expected and correct — the export packages the current source state.
- **FamilyControls entitlement is request-only (not auto-grant):** `com.apple.developer.family-controls` requires a separate approval request at developer.apple.com/contact/request/family-controls-distribution. The entitlement is tied to the Team ID (not a single app). Without it, all FamilyControls APIs fail at runtime. File the request early — there is no SLA and it can take days to weeks.
- **Extension targets require 4 provisioning profiles, not 1:** Adding DeviceActivityMonitor + ShieldConfiguration + ShieldAction extensions to kshana means registering 3 new App IDs, enabling App Groups on all 4, and generating 4 distribution provisioning profiles. The `ExportOptions.plist` embedded in `build_signed.sh` must include an explicit `provisioningProfiles` dictionary mapping all 4 bundle IDs to their respective profile names.
- **SPM executable targets cannot host app extensions:** Extension targets (DeviceActivityMonitor, ShieldConfiguration, ShieldAction) cannot be declared in `Package.swift`. A new XcodeGen `project.yml` at the repo root is required to host all four targets (main app + 3 extensions) before extension code can be compiled or archived.

## 2026-04-29T05:05:06Z: Squad Orchestration — Interrupt Mode Pivot

**Orchestration log filed:**
- `2026-04-29T05-05-06Z-virgil-screen-time-entitlement-path.md` — entitlements, provisioning, CI/CD mapping

**Session log:** `.squad/log/2026-04-29T05-05-06Z-interrupt-mode-pivot.md`

**Decisions merged:** All 9 inbox files → canonical `.squad/decisions/decisions.md`.

**Key takeaway:** FamilyControls entitlement is the gating external dependency for Phase 3. File request immediately at developer.apple.com/contact/request/family-controls-distribution. All build system work (new project.yml, extension targets, 4 provisioning profiles, CI mapping) can proceed in parallel while waiting for approval.

## Wave 19 — FamilyControls Entitlement Deep-Dive (2026-04-29)

**Task:** Research and document everything Yashasg needs to know about `com.apple.developer.family-controls` for the Screen Time / Shield UI implementation.
**Outcome:** ✅ Comprehensive reference written. Decision filed in inbox.

**Decision filed:** `.squad/decisions/inbox/virgil-familycontrols-entitlement-requirements.md`

### Key findings

**Entitlement nature:**
- `com.apple.developer.family-controls` is a **restricted, manually-approved entitlement** — not auto-granted
- Does NOT appear as a portal capabilities checkbox (Apple Developer Portal → Identifiers)
- Does NOT appear in Xcode's Signing & Capabilities UI (as of Xcode 15/16); add manually to `.entitlements` file
- Approval is at **Team ID** level (one approval covers all targets under the same team)
- Request form: `developer.apple.com/contact/request/family-controls-distribution`
- No SLA; expect days to weeks

**Entitlement value (kshana — self-care use case):**
```xml
<key>com.apple.developer.family-controls</key>
<array><string>individual</string></array>
```
Use `individual` scope, not `system`. Individual = user manages their own screen time. System = parental controls governing other users. Apple is more permissive with `individual` for wellbeing apps.

**Target coverage:**
All 4 targets need `family-controls` entitlement + App Groups:
- Main app: `com.yashasg.eyeposturereminder`
- DeviceActivityMonitor: `com.yashasg.eyeposturereminder.monitor`
- ShieldConfiguration: `com.yashasg.eyeposturereminder.shieldconfiguration`
- ShieldAction: `com.yashasg.eyeposturereminder.shieldaction`

**Pre-approval testing scope:**
- ✅ Compile + run on personal device via development profile (APIs work in dev mode)
- ✅ Internal TestFlight (same Apple account)
- ❌ External TestFlight / App Store upload — rejected by ASC until approval

**CI/CD Phase 3 delta:**
- 4 App IDs, 4 provisioning profiles, 4 `.entitlements` files
- `ExportOptions.plist` needs explicit 4-entry `provisioningProfiles` dict
- New root-level `project.yml` (XcodeGen) for 4-target app project
- 4 GitHub Secrets for distribution profiles

**App Groups:** Self-service (no special approval), portal toggle. Required on all 4 targets for shared state between app and extensions. Group ID: `group.com.yashasg.eyeposturereminder`.

## Learnings

- **`individual` vs `system` scope for FamilyControls:** For self-care / digital wellbeing apps (user controls their own usage), use `individual`. For parental controls apps (governing other family members), use `system`. Apple is stricter about approving `system`. The kshana use case is squarely `individual`.
- **FamilyControls entitlement is not a portal toggle:** Unlike Push Notifications, HealthKit, or iCloud, Family Controls does not appear as a checkbox in the Apple Developer Portal's Identifiers → Capabilities section. It is an approval-gated entitlement that Apple enables at the Team ID level server-side. Add it manually to `.entitlements` files.
- **Approval gates distribution, not compilation:** Development provisioning profiles let you run FamilyControls APIs on a personal device immediately. Apple's gating only applies to distribution profiles (App Store / external TestFlight). Code all of Phase 3 now; file the request and wait in parallel.
- **App Groups is the data bridge for extensions:** DeviceActivityMonitor, ShieldConfiguration, and ShieldAction all need to read/write shared state from the main app. App Groups (`group.com.yashasg.eyeposturereminder`) is the standard mechanism. It IS a normal portal capability — enable it on each App ID without any special approval.

---

## Scribe Orchestration (2026-04-29)

**Action:** Orchestration log filed + decisions merged to canonical decisions.md

- Orchestration log: `.squad/orchestration-log/2026-04-29T05-19-56Z-virgil-familycontrols-entitlement.md`
- Session log: `.squad/log/2026-04-29T05-19-56Z-shield-ui-entitlement-research.md`
- Merged into: `.squad/decisions.md` — "Decision: FamilyControls Entitlement — Restricted, Manual Approval Required"
- Inbox file deleted after merge

**Team impact:** Virgil's entitlement research is now canonical reference for all team members. Yashasg can proceed with approval request form using guidance in decisions.md. Phase 3 local dev and spike work can begin immediately; external distribution blocked until Apple approval received.

---

## Wave 20 — Screen Time Shield Build/Signing Implications (2026-04-29)

**Task:** Document build and code-signing implications of Screen Time Shield pivot. Inspect current workflows/scripts, update docs where appropriate, capture Phase 3 infrastructure requirements.

**Outcome:** ✅ Comprehensive decision note filed in `.squad/decisions/inbox/virgil-screen-time-shield-build-implications.md`

### Key Findings

**Phase 3 Changes (Parallel to FamilyControls Approval Wait):**

1. **4 targets instead of 1:** Main app + 3 extensions (DeviceActivityMonitor, ShieldConfiguration, ShieldAction)
   - SPM cannot host extension targets → need new XcodeGen `.xcodeproj` at repo root
   - All 4 targets signed with same team, same FamilyControls entitlement

2. **4 provisioning profiles instead of 1:** One distribution profile per App ID + target
   - Each must include App Groups + FamilyControls capabilities (after approval)
   - `ExportOptions.plist` needs explicit 4-entry `provisioningProfiles` dict mapping bundle IDs to specifiers
   - Without this, `xcodebuild export` fails for extensions

3. **4 entitlements files instead of 1:** One `.entitlements` per target
   - All include: FamilyControls (`individual` scope) + App Groups + Focus Status
   - Use same structure; different files for clarity and per-target capability alignment

4. **CI/CD Updates Needed:**
   - `build_signed.sh`: Detect new `.xcodeproj`, validate 4 profiles present, inject into ExportOptions before export
   - `testflight.yml`: Add 3 new profile base64 secrets (monitor, config, action extensions)
   - Backward compat: Auto-detect Phase 2 vs Phase 3 based on `.xcodeproj` existence

**Pre-Approval Development Path:**
- ✅ Local dev with automatic signing + dev profiles → FamilyControls APIs work immediately
- ✅ Internal TestFlight (same account) → can upload and test even before approval
- ❌ External TestFlight / App Store → blocked until distribution profiles updated by Apple post-approval

### Current Dirty Changes Preserved

- `build_signed.sh`: Added SIGNED_ENTITLEMENTS_PATH support (Phase 2 hygiene for Focus Status flexibility)
- `testflight.yml`: Updated prerequisites comments, added SIGNING_STYLE=manual
- `UITests/project.yml`: iPhone-only (portrait) per Yashasg's device strategy
- `README.md`: Added Focus Status distribution entitlements caveat

**Note:** These changes do NOT implement Phase 3 yet — they're Phase 2 improvements. Phase 3 extension logic will be new, not modifying existing dirty changes.

### Decision Filed

`.squad/decisions/inbox/virgil-screen-time-shield-build-implications.md` — Complete reference for Phase 3:
- Extension target architecture
- 4-profile provisioning strategy
- Entitlements design (all 4 targets)
- build_signed.sh + testflight.yml enhancements needed
- Pre-approval dev + internal TestFlight flow
- Risk table + mitigation
- Action items for Yashasg (approval request, App IDs, App Groups)
- Reference to canonical FamilyControls decision

### Learning

- **XcodeGen bridge:** SPM executables work for single-app builds, but extension targets are Xcode-only. XcodeGen lets us declaratively define a multi-target project that references the SPM package for the main app — clean separation of concerns.
- **Provisioning profile explosion:** 4 targets = 4 App IDs = 4 provisioning profiles. Not a blocker, but CI secret management scales (4 base64 secrets instead of 1). Worth automating profile discovery post-approval.
- **Entitlements as per-target configuration:** Each target can have different capabilities (focus status might only apply to main app, not extensions in some designs). Separate `.entitlements` files force clarity — no surprises with inherited-vs-explicit capabilities.

---

## Wave 22 — Post-#304/#305 Read-Only CI Audit (2026-04-30)

**Task:** Read-only audit after #304/#305 fixes. Verify warning-as-error enforcement, lint/test/coverage gates, action pinning, artifact handling, signed/archive parity, and no new warnings from #311–#314 SwiftUI/localization changes.

**Outcome:** #304/#305 fixes confirmed correct. One new material gap found; one GitHub issue filed (#317, p2).

### Audit Results

**✅ Warning-as-error enforcement (post-#304):**
- `build.sh` `XCODE_FLAGS`: `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES` + `GCC_TREAT_WARNINGS_AS_ERRORS=YES` ✓
- `build_signed.sh` `cmd_archive`: now passes both flags (lines 889–890) ✓
- `setup-screentime.sh --build`: now passes both flags (lines 108–109) ✓
- Parity confirmed across all three build paths

**✅ Action pinning (post-#305):**
- All 6 deployed `.github/workflows/` are fully SHA-pinned ✓
- `squad-heartbeat`, `squad-issue-assign`, `squad-triage`, `sync-squad-labels` and their templates: pinned ✓

**✅ Lint/test/coverage gates:**
- SwiftLint `--strict` enforced in `build.sh lint` + `ci.yml` ✓
- Coverage threshold 80% via `xcrun xccov` + `python3`, `if: always()` preventing bypass ✓
- TestResults.xcresult artifact has `if-no-files-found: error`; UITestResults same ✓

**✅ Artifact handling:**
- dSYMs: `if-no-files-found: warn` (intentional — not all builds produce dSYMs)
- Test results: `if-no-files-found: error`; IPA: no flag set (acceptable — preceding `build_signed.sh upload` step would fail first)
- `retention-days: 90` for dSYMs, `30` for test/IPA ✓

**✅ TestFlight CI gate:**
- Polls both "Build & Test" AND "UI Tests" check results before deploy ✓

**✅ #311–#314 SwiftUI/localization changes:**
- `OverlayView.swift` (#313): removed `.accessibilityAddTraits(.isModal)` — correct; no deprecated API warnings
- `OnboardingInterruptModeView.swift` (#311/#314): `accessibilityHidden(true)` pattern + new `onCustomize` CTA — clean, matches existing patterns
- Localization keys: `onboarding.interrupt.customizeButton` and `.hint` added to `Localizable.xcstrings` ✓
- **Note:** `onboarding.interrupt.illustrationLabel` key remains in `Localizable.xcstrings` but is no longer referenced in any Swift file (removed with #311's `accessibilityHidden` change). Cosmetic dead-string — no compiler warning emitted, no CI gate catches orphaned xcstrings keys. Not filing a CI gap issue (no enforcement mechanism exists).

**🔴 Gap — 7 squad templates with floating @vN refs (#317, p2):**
- `.squad/templates/workflows/` has 7 templates NOT covered by #305: `squad-ci.yml`, `squad-docs.yml`, `squad-insider-release.yml`, `squad-label-enforce.yml`, `squad-preview.yml`, `squad-promote.yml`, `squad-release.yml`
- All contain `actions/checkout@v4`, `actions/setup-node@v4`, and/or `actions/github-script@v7` floating refs
- Not deployed today but latent supply-chain risk if `squad upgrade` deploys them
- **Filed:** #317

### Issues Filed

- **#317** — 7 remaining squad template workflows still have floating `@vN` refs (#305 follow-up, p2)

### Not Duplicated

- #210 (entitlement/signing blocker) — excluded per task rules
- #304/#305 — already closed/fixed; fixes verified correct

### Learnings

- **`#305` scope gap:** Template pinning work must cover ALL templates, not just the ones with active deployed counterparts. Templates without deployed siblings can be silently skipped and then propagate floating refs when eventually deployed.
- **Orphaned xcstrings keys don't trigger warnings:** Removing an `accessibilityLabel(Text("key", bundle: .module))` in favour of `accessibilityHidden(true)` leaves the key in Localizable.xcstrings as dead string. Swift compiler and SwiftLint `--strict` won't flag it. Consider a future xcstrings lint step if localization scale grows.

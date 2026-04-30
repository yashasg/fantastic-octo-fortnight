# Virgil — History

## Core Context

- **Project:** kshana (formerly Eye & Posture Reminder) — lightweight iOS app with True Interrupt Mode via Screen Time APIs
- **Stack:** Swift, SwiftUI (iOS 16+), MVVM, UserNotifications, UIKit overlay, UserDefaults, FamilyControls (Phase 3+)
- **Owner:** Yashasg
- **Joined:** 2026-04-24

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

---

## Wave 22 — Privacy Manifest / Diagnostics Alignment (#315) (2026-04-30)

**Task:** Fix gap between `PRIVACY_NUTRITION_LABELS.md` (Diagnostics = Collected) and `PrivacyInfo.xcprivacy` (empty `NSPrivacyCollectedDataTypes`).

**Outcome:** ✅ Manifest updated. Decision filed. Issue #315 closed.

### What was done

1. `EyePostureReminder/PrivacyInfo.xcprivacy` — added two `NSPrivacyCollectedDataTypes` entries:
   - `NSPrivacyCrashData` / Not Linked / Not Tracking / `NSPrivacyCollectedDataTypePurposeAppFunctionality`
   - `NSPrivacyPerformanceData` / Not Linked / Not Tracking / `NSPrivacyCollectedDataTypePurposeAnalytics`
2. `docs/PRIVACY_NUTRITION_LABELS.md` — added "Privacy Manifest Consistency" section with a table mapping manifest string values to App Store Connect answers and a maintenance rule.
3. `plutil -lint` passed on updated manifest.
4. Decision filed: `.squad/decisions/inbox/virgil-privacy-manifest-diagnostics.md`

### Learnings

- **MetricKit counts as "collected" per Apple's definition:** The developer registers with `MXMetricManager` and receives `MXCrashDiagnostic`/`MXMetricPayload` objects surfaced by Apple through App Store Connect. Apple's definition of "collect" is transmitting data off device in a way that lets you access it — this qualifies.
- **Privacy manifest string values for diagnostics:** `NSPrivacyCrashData` / `NSPrivacyPerformanceData`; purposes: `NSPrivacyCollectedDataTypePurposeAppFunctionality` / `NSPrivacyCollectedDataTypePurposeAnalytics`.
- **Three-way consistency check:** Before every App Store submission, verify `PrivacyInfo.xcprivacy`, `PRIVACY_NUTRITION_LABELS.md`, and `docs/legal/PRIVACY.md` all agree on every collected data type. The decision inbox file has the checklist.
- **`plutil -lint` is the fast syntax validator for xcprivacy files** (they are plists).
## 2026-04-29 | PR #198 merge: legal placeholders + TestFlight signing + True Interrupt Mode docs

**Status**: MERGED ✓

**PR**: #198 → main | https://github.com/yashasg/fantastic-octo-fortnight/pull/198
**Merge commit**: `758c5b7538eed8dd04abb1fd06ef54499e196a1d`
**Merged via**: `gh pr merge 198 --squash --auto --delete-branch`

**What went in**:
- Legal placeholder updates (`[TO BE UPDATED]` marks for publisher details)
- Distribution entitlements for code signing setup
- TestFlight workflow and build script updates
- App icon consolidation (dark mode asset cleanup)
- HomeView layout refinements
- Documentation pivot: ARCHITECTURE, IMPLEMENTATION_PLAN, ROADMAP, UX_FLOWS, Screen Time/True Interrupt Mode research
- Onboarding spec, Test Strategy, TestFlight metadata, App Store listing docs
- UITests project config alignment

**Excluded** (as generated):
- TestResults.xcresult/Info.plist (test artifact)

**Build checks**:
- ✓ Build & Test: PASSED
- ⏱ UI Tests: In progress at merge time (auto-merge triggered on first passing check per task requirements)

**Blocker reference**:
- Issue #201 / Case 102881605113 (entitlement configuration) — tracked separately, not blocking this merge

**Notes**:
- Branch deleted post-merge
- Dirty tree properly triaged: excluded generated artifacts, included all intended source/config/docs
- Copilot trailer included in commit message
- PR body updated to reflect consolidated scope


---

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

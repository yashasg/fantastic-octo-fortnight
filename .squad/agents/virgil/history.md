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


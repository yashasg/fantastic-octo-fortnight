# Decision: Signed Build Parity — build_signed.sh vs build.sh

**Filed by:** Virgil  
**Date:** 2026-05 (Wave 16)  
**Status:** Resolved (ba18867)

## Context

`build_signed.sh` and `build.sh` share the same core build step pattern
(SPM package → app-wrapper → xcodebuild) but the signed script had three
concrete divergences that were not signing-related.

## Decisions Made

### 1. Build number injection belongs in build_signed.sh, patching the archive

- **Decision:** `inject_build_number()` patches `<archive>.xcarchive/Products/Applications/<App>.app/Info.plist` *after* a successful `xcodebuild archive`.
- **Rationale:** Avoids mutating source `Info.plist` (no dirty working tree; safe for local ad-hoc builds). CI passes `BUILD_NUMBER=${{ github.run_number }}`; local builds fall back to a timestamp.
- **NOT chosen:** Patching source `Info.plist` before archive (used by the old `testflight.yml`). That approach leaves a modified file in the working tree and risks accidental commits.

### 2. testflight.yml must call build_signed.sh, not raw xcodebuild

- **Decision:** Replace the raw `xcodebuild archive` + `xcodebuild -exportArchive` steps in `testflight.yml` with `./scripts/build_signed.sh upload`.
- **Rationale:** SPM `.executable` targets cannot be archived for iOS distribution without a `.xcodeproj` app-wrapper. `build_signed.sh` generates that wrapper via XcodeGen. Calling raw xcodebuild without `-project` on a pure SPM repo would always fail.
- **Required additions:** `brew install xcodegen` step in the workflow; `ASC_AUTH_KEY_PATH`, `ASC_AUTH_KEY_ID`, `ASC_AUTH_ISSUER_ID` env vars passed to match `build_signed.sh` interface.

### 3. Canonical bundle ID is all-lowercase

- **Decision:** `com.yashasg.eyeposturereminder` is the canonical bundle ID across all project files and scripts.
- **Rationale:** Confirmed by Rusty (Wave 13). Bundle IDs are case-sensitive in Apple systems. `UITests/project.yml` was the only outlier; corrected.

## Interface Contract for build_signed.sh

| Env var | Required? | Notes |
|---|---|---|
| `APPLE_TEAM_ID` | Auto-detected from Keychain if unset | |
| `BUILD_NUMBER` | Optional | Defaults to `YYYYMMDDHHmm` timestamp |
| `ASC_AUTH_KEY_PATH` | Required for upload | Must be an absolute path outside the repo |
| `ASC_AUTH_KEY_ID` | Required for upload | |
| `ASC_AUTH_ISSUER_ID` | Required for upload | |
| `APP_BUNDLE_ID` | Optional | Defaults to `com.yashasg.eyeposturereminder` |


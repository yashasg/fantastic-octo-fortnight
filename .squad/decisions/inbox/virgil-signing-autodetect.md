# Decision: Keychain Auto-Detection for APPLE_TEAM_ID in build_signed.sh

**Author:** Virgil  
**Date:** 2026-05-XX  
**Status:** Implemented  

## Context

`scripts/build_signed.sh` required `APPLE_TEAM_ID` to be set explicitly for every archive/export/upload invocation. On a local macOS machine with a single Apple Distribution certificate installed, this was friction — the Team ID is already implicit in the Keychain cert.

## Decision

Implement automatic Team ID detection from the local macOS Keychain as a convenience fallback, with the following rules:

1. **Explicit env var always wins.** `APPLE_TEAM_ID` (or `DEVELOPMENT_TEAM`) set in the environment is never overridden.
2. **Single-cert auto-detection.** If `security find-identity -p codesigning -v` returns Apple Distribution identities containing exactly one unique Team ID (10-char alphanumeric), that value is used silently. Doctor prints "detected from Keychain" — not the value itself.
3. **Ambiguous Keychain fails loudly.** If multiple Team IDs are found, archive/export/upload fail with a message instructing the user to set `APPLE_TEAM_ID` explicitly.
4. **Empty Keychain fails with guidance.** No change from prior behavior; failure message now mentions Keychain cert installation as an alternative to explicit env var.
5. **No ASC API key extraction from Keychain.** App Store Connect auth keys are not looked up from Keychain — only certificate-based Team ID detection is added.
6. **Provisioning profiles stay out of scope.** Profiles are handled by Xcode automatic signing (default) or `PROVISIONING_PROFILE_SPECIFIER` env var — not Keychain lookup.

## Rationale

- Reduces friction for solo/local workflows where only one distribution cert is present.
- Does not compromise CI/CD: CI always sets `APPLE_TEAM_ID` explicitly; auto-detection is never reachable.
- No sensitive value is ever printed or logged — "detected from Keychain" is the only output.
- Consistent with Apple toolchain conventions: `security find-identity` is the canonical way to enumerate code-signing identities.

## Implementation

- `infer_team_id_from_keychain()` added to `scripts/build_signed.sh` helpers section.
- Called once at startup when `APPLE_TEAM_ID` is empty.
- `require_team_id()` updated to distinguish ambiguous vs. not-found cases.
- `cmd_doctor()` updated to display detection source without revealing the value.
- `README.md` "Signed TestFlight builds" section updated with auto-detection note and provisioning profile clarification.

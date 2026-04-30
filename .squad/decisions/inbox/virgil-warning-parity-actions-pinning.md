# Decision: Warning-as-error parity + action SHA pinning policy

**Date:** 2026-04-30  
**Author:** Virgil (CI/CD Dev)  
**Issues:** #304, #305  
**Commit:** `5e2ab9786c50617b648ebf9650db092a2f180f24`

## Warning-as-error must be present in every xcodebuild invocation

`SWIFT_TREAT_WARNINGS_AS_ERRORS=YES` and `GCC_TREAT_WARNINGS_AS_ERRORS=YES` must be passed to **every** `xcodebuild` call in any project script — including archive, export, and validation builds. It is not sufficient to:
- rely on grep-based post-build log scanning, or
- assume the build scheme has these set by default.

Reference implementation: `scripts/build.sh` XCODE_FLAGS array. Any new script that calls `xcodebuild` must include these flags.

## GitHub Actions refs must be pinned to commit SHAs

All `uses:` references to third-party GitHub Actions must use a full 40-character commit SHA with a comment noting the version. Floating major-version tags (`@v4`, `@v7`) are not acceptable in any workflow that has write permissions on issues, contents, or packages.

Format:
```yaml
uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5 # v4.3.1
```

Current pinned versions (verified 2026-04-30):
- `actions/checkout`: `34e114876b0b11c390a56381ad16ebd13914f8d5` (v4.3.1)
- `actions/github-script`: `60a0d83039c74a4aee543508d2ffcb1c3799cdea` (v7.0.1)

## Template parity

When patching active workflows in `.github/workflows/`, the matching files in `.squad/templates/workflows/` must be updated in the same commit. Otherwise `squad upgrade` will revert the fix.

## CRLF note for future maintainers

The squad workflow YAML files use Windows line endings (CRLF). Use `perl -i -pe` with `\r?$` anchoring rather than `sed` when doing line-end-anchored substitutions on these files.

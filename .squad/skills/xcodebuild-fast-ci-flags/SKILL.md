---
name: "xcodebuild-fast-ci-flags"
description: "xcodebuild flags and patterns for fast cold-start CI builds on GitHub-hosted macOS runners"
domain: "ci"
confidence: "high"
source: "earned"
---

## Context

When running `xcodebuild` on cold CI runners (GitHub-hosted macOS, no cached DerivedData from prior run), several default behaviours waste significant time. Apply these flags to reduce cold-build wall time by 3–8 minutes on a typical TCA-heavy iOS project.

## Patterns

### Must-have flags for any CI xcodebuild invocation

```bash
COMPILER_INDEX_STORE_ENABLE=NO   # Skip index store writes — CI has no IDE. ~1-3 min saved.
DEBUG_INFORMATION_FORMAT=dwarf   # Skip dSYM bundle generation for non-archive builds. ~30-90s saved.
ONLY_ACTIVE_ARCH=YES             # Simulator builds: compile only arm64, not x86_64+arm64. ~10-20% saved.
ENABLE_BITCODE=NO                # Already deprecated, but explicit is safe.
```

### Release configuration for CI

For test-only CI (not archive/distribution), `-configuration Release` gives:
- `SWIFT_COMPILATION_MODE = wholemodule` → whole-module optimisation, fewer re-compiles on incremental runs
- Optimized binary → faster test execution (especially UI tests)

**Required companion flag when using Release for tests (108+ test files use `@testable import`):**
```bash
ENABLE_TESTABILITY=YES   # Must be set for test build actions only, NOT for the app build step
```

### Eliminate double-compilation on CI

The pattern `xcodebuild build` followed by `xcodebuild test` pays compile cost twice — `test` action recompiles everything. Use instead:

```bash
# Step 1 — build app + test bundles
xcodebuild build-for-testing -scheme MyScheme -destination ... -derivedDataPath DerivedData

# Step 2 — run tests (no recompile)
xcodebuild test-without-building -xctestrun DerivedData/Build/Products/MyScheme_*.xctestrun \
  -destination ... -derivedDataPath DerivedData
```

This is ~40-50% faster than build + test in sequence.

### ModuleCache purge — conditional, not unconditional

If restoring a DerivedData cache from a prior run, purge module caches that are bound to SDK/Xcode version:

```bash
# Only purge when cache was actually restored (check actions/cache cache-hit output)
if [[ "${{ steps.cache-dd.outputs.cache-hit }}" == "true" ]]; then
  rm -rf DerivedData/ModuleCache.noindex DerivedData/SDKStatCaches.noindex
fi
```

For fully cold builds (no cache restored), skipping the rm saves ~20-30s.

### Skip macro validation on CI

Always pass `-skipMacroValidation` to suppress interactive trust prompts for Swift macros (TCA `@Reducer`, `@DependencyClient`):

```bash
xcodebuild -skipMacroValidation build -scheme ...
```

### Release config: xctestrun path adjustment

When running UI tests in Release mode, the `build-for-testing` output lands in `Release-iphonesimulator/` not `Debug-iphonesimulator/`. Update any PlistBuddy patches or hardcoded paths accordingly:

```bash
# Debug (default):
__TESTROOT__/Debug-iphonesimulator/MyApp.app

# Release:
__TESTROOT__/Release-iphonesimulator/MyApp.app
```

## Examples

### XCODE_FLAGS array for CI (build.sh pattern)

```bash
XCODE_FLAGS=(
  MARKETING_VERSION="${MARKETING_VERSION}"
  CURRENT_PROJECT_VERSION="${CURRENT_PROJECT_VERSION}"
  CODE_SIGN_IDENTITY=""
  CODE_SIGNING_REQUIRED=NO
  CODE_SIGNING_ALLOWED=NO
  ENABLE_BITCODE=NO
  ENABLE_APP_INTENTS_METADATA_EXTRACTION=NO
  ENABLE_APPINTENTS_METADATA_EXTRACTION=NO
  COMPILER_INDEX_STORE_ENABLE=NO       # CI: no IDE indexing needed
  DEBUG_INFORMATION_FORMAT=dwarf       # CI: skip dSYM for non-archive
  ONLY_ACTIVE_ARCH=YES                 # Simulator: arm64 only
)

# For test-only actions (build-for-testing), add:
TEST_XCODE_FLAGS=("${XCODE_FLAGS[@]}" ENABLE_TESTABILITY=YES)
```

### project.yml — Release config for main app target

```yaml
settings:
  base:
    SWIFT_TREAT_WARNINGS_AS_ERRORS: "YES"
    # ... other base settings
  configs:
    Release:
      SWIFT_COMPILATION_MODE: wholemodule
      ENABLE_TESTABILITY: "YES"   # Required: @testable import in unit tests
```

## Anti-Patterns

- Running `xcodebuild build` then `xcodebuild test` in sequence — the `test` action recompiles everything. Use `build-for-testing` + `test-without-building` instead.
- Purging `ModuleCache.noindex` unconditionally — on cold builds (no cache restore), this rm is a no-op but wastes log time. Make it conditional on `cache-hit`.
- Leaving `COMPILER_INDEX_STORE_ENABLE` unset on CI — default is YES, which writes megabytes of index data for an IDE that isn't running.
- Using `-configuration Debug` (or no flag) for test-only CI pipelines — wastes optimisation that Release provides, and misses whole-module opportunity.
- Pinning `SIMULATOR` to `iPhone 17` without verifying the runner has the iOS 18/26 runtime. If the runtime isn't pre-installed, the download step adds 5-10 minutes.
- **Putting `ENABLE_TESTABILITY=YES` in the global `XCODE_FLAGS` array** — it flows into `cmd_build` and marks the production binary as testable. Pass it only as a positional arg to `run_xcodebuild` on `build-for-testing` calls.
- **Fixing only one `Debug-iphonesimulator` reference in `cmd_uitest`** — there are two: the PlistBuddy `-c Set` string AND the `local products_dir` variable assignment. Both must be updated to `${CONFIGURATION}-iphonesimulator` or the SPM binary copy into .app fails at runtime.

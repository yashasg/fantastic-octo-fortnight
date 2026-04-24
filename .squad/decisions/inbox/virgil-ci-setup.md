# Decision: CI/CD Pipeline Setup

> **Proposed by:** Virgil (CI/CD Dev)  
> **Date:** 2025-07-17  
> **Status:** Implemented  
> **Triggered by:** Yashas requested CI/CD pipeline setup

---

## Summary

Full CI/CD pipeline is in place for Eye & Posture Reminder. Simulator builds and tests run on every push to `main` and every pull request. TestFlight upload is scaffolded but disabled.

---

## Files Created

| File | Purpose |
|---|---|
| `.github/workflows/ci.yml` | GitHub Actions pipeline |
| `.swiftlint.yml` | SwiftLint rule configuration |
| `scripts/set-build-info.sh` | Xcode Run Script Build Phase for versioning |

---

## Key Decisions

### 1. Runner: `macos-14` (Apple Silicon)
- Prefer `macos-14` over `macos-latest` for explicit Apple Silicon runner selection.
- Faster for Swift/Xcode builds than Intel-based runners.
- Pinned Xcode version: `16.2` (change this when the project targets a newer SDK).

### 2. No signing in CI (simulator-only)
- No Apple Developer account exists yet.
- All builds use `CODE_SIGN_IDENTITY=""`, `CODE_SIGNING_REQUIRED=NO`, `CODE_SIGNING_ALLOWED=NO`.
- Only simulator destinations are used. Device builds require real provisioning profiles.

### 3. ENABLE_BITCODE=NO
- Bitcode deprecated by Apple in Xcode 14. Set to `NO` explicitly to suppress warnings.
- This applies in CI and should also be set in the Xcode project `Release` configuration.

### 4. DerivedData caching
- Cache key: hash of `project.pbxproj` + all `.swift` files.
- Restores on key miss using prefix `derived-data-${{ runner.os }}-`.
- Reduces cold build times significantly on cache hits.

### 5. dSYMs as build artifacts
- Collected from DerivedData after every build and uploaded as `dSYMs-{run_number}`.
- Retained for 90 days. Required for crash symbolication once TestFlight is active.
- Even for simulator builds, dSYMs are generated and worth preserving for continuity.

### 6. SwiftLint configuration choices
- Line length: 120 warning / 160 error (pragmatic for SwiftUI DSL).
- Disabled: `function_body_length`, `large_tuple`, `opening_brace` — these conflict with SwiftUI's declarative patterns.
- `force_unwrapping` enabled as warning (not error) to catch it without blocking builds during early development.

### 7. TestFlight job present but commented out
- The `upload-testflight` job exists in `ci.yml` as a fully-formed template.
- Uncomment and configure when an Apple Developer account and API key are available.
- Requires: `BUILD_CERTIFICATE_BASE64`, `P12_PASSWORD`, `BUILD_PROVISION_PROFILE_BASE64`, `KEYCHAIN_PASSWORD`, `APP_STORE_CONNECT_API_KEY`, `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_KEY_ID` secrets in GitHub.

### 8. Tag format (documented in ci.yml header comment)
- `v0.x.x` — TestFlight beta phase, before App Store launch
- `v1.0.0` — App Store launch
- Annotated tags created after successful upload, not before.

---

## What Needs to Happen Before TestFlight

1. Apple Developer account enrolled and active.
2. App ID registered in App Store Connect.
3. Distribution certificate + provisioning profile generated.
4. GitHub secrets populated (see list above).
5. `upload-testflight` job uncommented in `ci.yml`.
6. `ExportOptions.plist` created in project root (export method: `app-store`).
7. Marketing version decision: start at `0.1.0` (beta) or `1.0.0` (launch)?

---

## Open Question

The versioning decision (`virgil-versioning.md`) asked whether to start at `v0.x.x` or `v1.0.0` for TestFlight. This is still unresolved. CI is neutral — it will work with either. The starting version should be set in the Xcode project before the first TestFlight build.

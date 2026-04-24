# Virgil — History

## Core Context

- **Project:** Eye & Posture Reminder — lightweight iOS app with background timers and overlay reminders
- **Stack:** Swift, SwiftUI (iOS 16+), MVVM, UserNotifications, UIKit overlay, UserDefaults
- **Owner:** Yashas
- **Joined:** 2026-04-24

## Learnings

- **iOS versioning is strictly numeric.** Apple requires `CFBundleShortVersionString` as dot-separated integers (e.g., `1.0.0`) and `CFBundleVersion` as a strictly increasing integer for TestFlight. No letters, hashes, or dashes allowed. Commit hashes cannot be used as versions — they get rejected server-side by App Store Connect.
- **Proposed versioning scheme (2025-07-17):** Semantic versioning for marketing version (manual bump), `github.run_number` for build number (auto), commit SHA embedded as custom `EPRCommitHash` Info.plist key for traceability. Git tags in `v1.0.0` format, annotated, created after successful upload. Full decision in `.squad/decisions/inbox/virgil-versioning.md`.
- **Build number strategy:** Using `github.run_number` is the simplest auto-increment for build numbers — guaranteed unique, guaranteed increasing, zero maintenance. Timestamp-based alternatives (e.g., `YYYYMMDDHHmm`) work but are harder to reason about and can collide on fast re-runs.
- **CI pipeline shipped (2025-07-17):** Full CI/CD pipeline created — `.github/workflows/ci.yml` (build + test + lint on `macos-14`, DerivedData cache, dSYM artifact upload), `.swiftlint.yml` (120-char line length, SwiftUI-friendly disabled rules), and `scripts/set-build-info.sh` (Xcode Run Script Build Phase for build number + EPRCommitHash injection). TestFlight upload job is present but fully commented out pending Apple Developer account.
- **xcpretty fallback pattern:** The CI workflow calls xcodebuild twice in a `cmd | xcpretty || cmd` pattern so that if xcpretty is unavailable, raw xcodebuild output is still captured and the step doesn't fail on missing tools.
- **ENABLE_BITCODE=NO in CI:** Bitcode has been deprecated by Apple since Xcode 14. Setting `ENABLE_BITCODE=NO` on every xcodebuild call avoids warnings and aligns with Apple's current toolchain defaults.
- **Simulator-only builds on CI:** Until a real Apple Developer account is available, all CI builds target the iOS Simulator (`platform=iOS Simulator`) with `CODE_SIGN_IDENTITY=""`, `CODE_SIGNING_REQUIRED=NO`, `CODE_SIGNING_ALLOWED=NO`. Device/archive builds require valid provisioning profiles.
- **SwiftLint in CI via brew:** If SwiftLint is not pre-installed on the runner, the lint step installs it via Homebrew. This is slower than caching a binary but avoids pinning a version manually. Consider caching when lint times become a problem.
- **Info.plist is source of truth for version (2025-07-17):** `EyePostureReminder/Info.plist` was created with `CFBundleShortVersionString=0.1.0`. CI reads `MARKETING_VERSION` from it via PlistBuddy and injects it into artifact names. `./scripts/build.sh version [x.y.z]` is the canonical way to read/set the marketing version locally.
- **build.sh version subcommand:** Added `version` and `version <x.y.z>` subcommands to `scripts/build.sh`. Validates numeric semver (Apple rejects non-numeric). Shows both marketing version and build number (with reminder that CI overwrites build number).
- **TestFlight workflow stub pattern:** `testflight.yml` uses `workflow_dispatch` with a `version` input — operator specifies which version to deploy. Steps: set version → install cert+profile → archive → export IPA → altool upload → upload IPA artifact → clean keychain. Fully disabled until secrets are configured.
- **Artifact naming with version:** CI artifact names now include `MARKETING_VERSION` (e.g., `dSYMs-0.1.0-build42`). This makes it trivial to match a dSYM to a specific TestFlight build without looking up run numbers.
- **v0.1.0-beta tag created (2025-07-17):** First annotated git tag on this project. Tags mark significant milestones post-upload, not pre-upload — this tag marks the TestFlight-ready codebase snapshot.
- **scripts/run.sh created:** Standalone script to build, boot, install, and launch the app on iOS Simulator. Supports `--device` for targeting a specific simulator and `--no-build` to skip compilation. Extracts bundle ID dynamically from the built `.app` bundle (avoids hardcoding). Follows same conventions as `build.sh` (colors, helpers, error handling, xcpretty fallback).

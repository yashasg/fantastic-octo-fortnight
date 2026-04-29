# kshana — Eye & Posture Wellness

A calming iOS wellness app — redesigned as **Restful Grove** with a yin-yang–inspired logo — that delivers gentle eye-break and posture reminders based on actual screen time. Built exclusively with SwiftUI, UserNotifications, and UIKit to minimise battery and memory usage.

## Features

- 👁 **Eye-rest reminders** – configurable interval and break duration (e.g. 20-20-20 rule)
- 🧍 **Posture reminders** – configurable interval and break duration
- 🧠 **Smart Pause** – automatically pauses reminders during Focus Mode, CarPlay navigation, or when driving
- Full-screen dismissible overlay with countdown timer
- Dropdown pickers for reminder interval and break length
- Foreground screen-time tracking via a 1-second `Timer` — reminders fire based on actual eyes-on-screen time, not wall-clock intervals
- 🚀 **Onboarding flow** – 3-screen first-launch guide (Welcome → Permissions → Setup)
- 📳 **Haptic feedback** – tactile notifications on reminder appear and dismiss (toggle in Settings)
- 💤 **Snooze** – snooze active reminders with configurable limits
- ♿ **Accessibility** – Dynamic Type, VoiceOver labels/hints, Reduce Motion support
- ⚙️ **Data-driven configuration** – intervals, durations, and feature flags loaded from `defaults.json`
- 📄 **Legal docs in-app** – Terms of Service, Privacy Policy, and Disclaimer bundled and accessible in Settings

## Building & Testing

All build, test, and lint commands are standardised through `scripts/build.sh`.

```bash
# Compile the project (auto-detects iOS Simulator or Mac Catalyst)
./scripts/build.sh build

# Run unit tests
./scripts/build.sh test

# Run SwiftLint (skipped gracefully if not installed)
./scripts/build.sh lint

# Remove build artifacts
./scripts/build.sh clean

# Build + lint + test in one shot
./scripts/build.sh all

# Quick syntax check (compile only, no tests)
./scripts/build.sh check
```

> **Note:** `swift build` does not work for this project because SwiftUI/UIKit are iOS-only frameworks.
> The script uses `xcodebuild` and automatically falls back to Mac Catalyst if no iOS Simulator runtime is found.

### Signed TestFlight builds

Use the separate signed runner when you want a local archive, IPA export, or App Store Connect upload. It does not run unit tests or UI tests; run `./scripts/build.sh all` separately when you want validation.

```bash
# Check local signing prerequisites
./scripts/build_signed.sh doctor

# Create a signed archive
APPLE_TEAM_ID=<team-id> ./scripts/build_signed.sh archive

# Export a signed IPA
APPLE_TEAM_ID=<team-id> ./scripts/build_signed.sh export

# Upload for TestFlight
APPLE_TEAM_ID=<team-id> ./scripts/build_signed.sh upload
```

**Auto-detection:** If exactly one Apple Distribution certificate is present in your local macOS Keychain, `APPLE_TEAM_ID` is inferred automatically and you can omit it. If exactly one local App Store Connect provisioning profile matches the bundle ID, the profile specifier is inferred automatically too. Run `./scripts/build_signed.sh doctor` to check the detected state.

For TestFlight, use a **Distribution → App Store Connect** provisioning profile. Do not add devices just for TestFlight; device registration is only needed for development/ad hoc installs outside TestFlight. If multiple matching profiles exist, pass `PROVISIONING_PROFILE_SPECIFIER=<profile-name>` through the environment.

Keep private signing values in environment variables only. Do not commit Team IDs, provisioning profile UUIDs, App Store Connect API key IDs, issuer IDs, `.p8` paths, certificates, or profiles.

### Troubleshooting signed builds

| Symptom | Cause | Fix |
|---------|-------|-----|
| *"No Accounts: Add a new account in Accounts settings"* | Automatic signing with no Xcode account or API key | Log in via Xcode → Settings → Accounts **or** supply `ASC_AUTH_KEY_PATH` / `ASC_AUTH_KEY_ID` / `ASC_AUTH_ISSUER_ID` |
| *"No profiles for canonical app bundle ID"* | No App Store Connect Distribution profile installed locally | Create a Distribution → App Store Connect profile at [developer.apple.com → Profiles](https://developer.apple.com/account/resources/profiles/list), download and double-click it, or set `PROVISIONING_PROFILE_SPECIFIER` |
| *`export` or `upload` reports no signed IPA* | `export` / `upload` requires a successful `archive` first | Re-run `export`; it will re-archive automatically. Transporter only accepts a fully signed `.ipa` |
| *"conflicting provisioning settings" (exit 65)* | `CODE_SIGN_IDENTITY` injected alongside automatic signing | Use `SIGNING_STYLE=manual` (the default) to avoid the conflict |

> **Sequence reminder:** `archive` → `export` → `upload`. Each step depends on the previous one completing successfully. Running `export` or `upload` re-runs `archive` automatically.

### Prerequisites

| Tool | Install |
|------|---------|
| Xcode (includes `xcodebuild`) | Mac App Store or `xcode-select --install` |
| SwiftLint *(optional)* | `brew install swiftlint` |

## Implementation Plan

See **[IMPLEMENTATION_PLAN.md](./IMPLEMENTATION_PLAN.md)** for the full architecture, design decisions, file structure, data flow, and phased delivery plan.

## Legal & Privacy

This app is committed to user privacy and transparency:

- **[Terms of Service](./docs/legal/TERMS.md)** – legal agreement and liability disclaimer
- **[Privacy Policy](./docs/legal/PRIVACY.md)** – data collection and usage practices
- **[Disclaimer](./docs/legal/DISCLAIMER.md)** – health/medical information and liability limitations

All legal documents are included in the app bundle and linked in Settings.

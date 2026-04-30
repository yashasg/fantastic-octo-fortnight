# kshana — Eye & Posture Wellness

A calming iOS wellness app — redesigned as **Restful Grove** with a yin-yang–inspired logo — that delivers healthy app breaks based on your screen time. **Phase 3 pivot: Integrating Apple Screen Time APIs (FamilyControls + DeviceActivity + ManagedSettings) for True Interrupt Mode** — once Apple entitlement approval is complete, kshana will shield selected apps during breaks. Current builds use local reminder alerts and an in-app break screen while app-level shielding is pending. Built exclusively with SwiftUI, UserNotifications, UIKit, and ScreenTime frameworks to minimise battery and memory usage.

## Features

- 👁 **Eye-rest reminders** – configurable interval and break duration (e.g. 20-20-20 rule)
- 🧍 **Posture reminders** – configurable interval and break duration
- 🚀 **True Interrupt Mode (coming Phase 3)** – Screen Time Shield-based break suggestions over selected apps/categories; arriving when Apple entitlement approval (#201) is complete. Current builds use local alerts as the primary reminder mechanism.
- 🧠 **Smart Pause** – automatically pauses reminders during Focus Mode (requires `com.apple.developer.focus-status` entitlement), CarPlay navigation, or when driving
- Full-screen break screen with countdown timer
- Dropdown pickers for reminder interval and break length
- Foreground screen-time tracking via a 1-second `Timer` — reminders fire based on actual eyes-on-screen time, not wall-clock intervals
- 🎯 **App Selection** – choose which apps and categories will be shielded during breaks once Screen Time entitlement approval is complete (Phase 3)
- 🚀 **Onboarding flow** – 4-screen first-launch guide with calm pre-permission education
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

### UI Test Launch Arguments

| Argument | Effect | Helper |
|----------|--------|--------|
| `--skip-onboarding` | Sets `hasSeenOnboarding = true`, resets settings → Home screen | `launchWithSkippedOnboarding()` |
| `--reset-onboarding` | Clears `hasSeenOnboarding` → fresh onboarding flow | `launchWithOnboarding()` |
| `--show-overlay-eyes` | Triggers eye break overlay on launch | `launchWithEyeOverlay()` |
| `--show-overlay-posture` | Triggers posture check overlay on launch | `launchWithPostureOverlay()` |
| `--simulate-screen-time-not-determined` | Seeds `.notDetermined` Screen Time auth stub → banner/pill visible | `launchWithTrueInterruptPending()` |

### Accessibility Identifier Reference — Home Screen

| Identifier | Element | Condition |
|------------|---------|-----------|
| `home.title` | App name text | Always |
| `home.statusLabel` | Active/paused status text | Always |
| `home.settingsButton` | Settings toolbar button | Always |
| `home.trueInterrupt.skippedBanner` | TrueInterruptSkippedBanner container | `screenTimeAuthorization == .notDetermined` AND banner not dismissed |
| `home.trueInterrupt.skippedBanner.setUp` | "Set Up" CTA button | Same as banner |
| `home.trueInterrupt.skippedBanner.dismiss` | "Dismiss" CTA button | Same as banner |
| `home.trueInterrupt.setupPill` | TrueInterruptSetupPill button | `screenTimeAuthorization == .notDetermined` AND banner dismissed |

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

The signed runner uses `EyePostureReminder/EyePostureReminder.Distribution.entitlements` by default so App Store profiles that do not include Focus Status can still archive/export. If you enable the Focus Status capability on the App ID and regenerate the distribution profile, you can opt into the full app entitlements with `SIGNED_ENTITLEMENTS_PATH=EyePostureReminder/EyePostureReminder.entitlements`.

Keep private signing values in environment variables only. Do not commit Team IDs, provisioning profile UUIDs, App Store Connect API key IDs, issuer IDs, `.p8` paths, certificates, or profiles.

### Troubleshooting signed builds

| Symptom | Cause | Fix |
|---------|-------|-----|
| *"No Accounts: Add a new account in Accounts settings"* | Automatic signing with no Xcode account or API key | Log in via Xcode → Settings → Accounts **or** supply `ASC_AUTH_KEY_PATH` / `ASC_AUTH_KEY_ID` / `ASC_AUTH_ISSUER_ID` |
| *"No profiles for canonical app bundle ID"* | No App Store Connect Distribution profile installed locally | Create a Distribution → App Store Connect profile at [developer.apple.com → Profiles](https://developer.apple.com/account/resources/profiles/list), download and double-click it, or set `PROVISIONING_PROFILE_SPECIFIER` |
| *`export` or `upload` reports no signed IPA* | `export` / `upload` requires a successful `archive` first | Re-run `export`; it will re-archive automatically. Transporter only accepts a fully signed `.ipa` |
| *"conflicting provisioning settings" (exit 65)* | `CODE_SIGN_IDENTITY` injected alongside automatic signing | Use `SIGNING_STYLE=manual` (the default) to avoid the conflict |
| *"Entitlement com.apple.developer.focus-status not found"* | The App Store profile was generated without Focus Status capability | Use the default distribution entitlements, or enable Focus Status on the App ID, regenerate/download the profile, and set `SIGNED_ENTITLEMENTS_PATH=EyePostureReminder/EyePostureReminder.entitlements` |

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

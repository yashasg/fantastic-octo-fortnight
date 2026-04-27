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
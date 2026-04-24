# Decision: Xcode Project Setup via Swift Package Manager

**Author:** Basher  
**Date:** 2026-04-24  
**Status:** Adopted

## Context

We have no Xcode CLI (`xcodegen`, `xcode-select`) in the dev environment, so a `.xcodeproj` could not be generated programmatically.

## Decision

Use **Swift Package Manager** (`Package.swift`) as the project manifest:
- `Package.swift` at repo root, targeting `.iOS(.v16)`
- Source root: `EyePostureReminder/` (custom `path:` in the executable target)
- Bundle identifier placeholder: `com.yashasg.eyeposture` (must be set in Xcode signing settings before distribution)

## Consequences

- ✅ Xcode can open `Package.swift` directly — full IDE support, previews, and signing.
- ✅ No extra toolchain required for the current team.
- ⚠️ `swift build` on macOS fails (UIKit/SwiftUI are iOS-only). All builds must target a simulator or device inside Xcode.
- ⚠️ If a CI pipeline is needed, it must use `xcodebuild` with `-destination 'platform=iOS Simulator,...'`.

## Notification Routing Pattern

All UNUserNotification category identifiers are owned by `ReminderType`:
- `ReminderType.categoryIdentifier` — canonical identifier
- `ReminderType.init?(categoryIdentifier:)` — reverses the mapping in AppDelegate
This keeps notification identity co-located with the domain type rather than scattered across AppDelegate and ReminderScheduler.

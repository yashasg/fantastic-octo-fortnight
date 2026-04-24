# Decision Needed: XCUITest Requires .xcodeproj

**Filed by:** Livingston (Tester)  
**Date:** 2026-04-25  
**Related issue:** #9 — Add XCUITest suite

## Problem

XCUITest UI test bundles require a dedicated UITest target type. Swift Package Manager's `Package.swift` only supports `.testTarget` (unit tests via XCTest) — there is no `.uiTestTarget` equivalent in SPM.

The UI test files have been written and placed in `Tests/EyePostureReminderUITests/`. They are complete, follow XCUIApplication patterns, and include `launchArguments` for test state control. However, they **cannot be compiled or run** without an Xcode project.

## Options

1. **Add an `.xcodeproj`** — Generate or manually create an Xcode project alongside Package.swift. Add a UITest target that references `Tests/EyePostureReminderUITests/*.swift`. This is the standard path for shipping iOS apps anyway (App Store submission requires Xcode).

2. **Xcode Cloud / xcodebuild** — Same prerequisite: needs an `.xcodeproj` or `.xcworkspace`.

3. **Defer** — Keep the test files staged. When the team adds an Xcode project for distribution, wire the UITest target at that point.

## Recommendation

Add an `.xcodeproj`. The project is already iOS-only and App Store-bound — an Xcode project is needed for signing, entitlements, and distribution. This is the right time to add it. Basher (iOS Dev) is the right person to generate it from the existing SPM manifest.

## Required Work When .xcodeproj Added

1. Add UITest target in Xcode project settings, add `Tests/EyePostureReminderUITests/*.swift` to it.
2. Add `launchArguments` handling in `EyePostureReminderApp.swift` (see `Tests/EyePostureReminderUITests/README.md`).
3. Add `accessibilityIdentifier` modifiers to source views (full list in same README).
4. Run `xcodebuild test -scheme EyePostureReminder -destination 'platform=iOS Simulator,name=iPhone 15 Pro'`.

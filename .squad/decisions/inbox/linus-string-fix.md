# Decision: SPM Localization Bundle Strategy

**Filed by:** Linus (iOS Dev UI)  
**Date:** 2026-04-26  
**Status:** Implemented

## Decision

For this SPM `executableTarget`, ALL localization calls in SwiftUI views **must** explicitly pass `bundle: .module`. The `Bundle.module` accessor (not `Bundle.main`) is the correct bundle for SPM resource access.

## Rationale

SPM builds an `executableTarget`'s resources into a separate bundle (`EyePostureReminder_EyePostureReminder.bundle`), accessible only via `Bundle.module`. SwiftUI defaults to `Bundle.main` which has no strings — causing raw keys to appear at runtime.

## Required Patterns

| Call site | Correct form |
|-----------|-------------|
| `Text("key")` | `Text("key", bundle: .module)` |
| `String(localized: "key")` | `String(localized: "key", bundle: .module)` |
| `.navigationTitle("key")` | `.navigationTitle(Text("key", bundle: .module))` |
| `.accessibilityLabel("key")` | `.accessibilityLabel(Text("key", bundle: .module))` |
| `.accessibilityHint("key")` | `.accessibilityHint(Text("key", bundle: .module))` |
| `Toggle("key", isOn:)` | `Toggle(isOn:) { Text("key", bundle: .module) }` |
| `Button("key") { }` | `Button(action: {}) { Text("key", bundle: .module) }` |
| `Section("key")` | `Section { } header: { Text("key", bundle: .module) }` |
| `Label("key", systemImage:)` | `Label(title: { Text("key", bundle: .module) }, icon: { Image(systemName:) })` |

## run.sh Requirement

`assemble_app_bundle` in `scripts/run.sh` must embed `EyePostureReminder_EyePostureReminder.bundle` inside the `.app` bundle. Without this step, `Bundle.module` cannot resolve the bundle at simulator runtime because `xcrun simctl install` only installs the `.app`.

## Scope

Applies to all current and future SwiftUI views in `EyePostureReminder/Views/`.

# Squad History — Basher (Services Dev) + Virgil (CI/CD)
# Branch: squad/m3-true-interrupt-mode
# Issue: #203 — M3.3 Project & Extension Target Setup

## Session: 2026-04-29

### Implemented (unblocked slice)

**Extension stubs — compile clean without FamilyControls entitlement:**
- `Extensions/Shared/ShieldSessionKeys.swift` — shared UserDefaults keys; duplicates literal keys from main app `ShieldSession` (extension targets cannot import main module)
- `Extensions/ShieldConfigurationExtension/ShieldConfigurationDataSource.swift` — `ShieldConfigurationDataSource` subclass; reads App Group UserDefaults for break reason copy
- `Extensions/ShieldConfigurationExtension/Info.plist` — `com.apple.ManagedSettingsUI.ShieldConfigurationExtensionPoint`
- `Extensions/ShieldConfigurationExtension/ShieldConfigurationExtension.entitlements` — App Group only; FamilyControls absent pending #201
- `Extensions/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift` — `DeviceActivityMonitor` subclass; `intervalDidStart/End` stubs with `ManagedSettingsStore.clearAllSettings()` on end
- `Extensions/DeviceActivityMonitorExtension/Info.plist` — `com.apple.DeviceActivity.DeviceActivityMonitorExtensionPoint`
- `Extensions/DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.entitlements` — App Group only; FamilyControls absent pending #201

**Entitlements updated:**
- `EyePostureReminder/EyePostureReminder.entitlements` — added `com.apple.security.application-groups: [group.com.yashasgujjar.kshana]`
- `EyePostureReminder/EyePostureReminder.Distribution.entitlements` — added App Group; FamilyControls absent pending #201

**XcodeGen project spec:**
- `project.yml` (repo root) — development spec: app wrapper + both extensions; CODE_SIGNING_ALLOWED=NO
- `scripts/setup-screentime.sh` — generates `ScreenTimeExtensions/EyePostureReminderExtensions.xcodeproj` + optional --build validation
- `.gitignore` — `ScreenTimeExtensions/*.xcodeproj/` added

**CI/build scripts:**
- `scripts/build_signed.sh` — added `EXTENSION_PROFILES_AVAILABLE`, `SHIELD_CONFIG_PROFILE`, `DEVICE_ACTIVITY_PROFILE` env vars; `generate_project()` conditionally injects extension targets + doctor output

### Deferred (blocked)
- ShieldAction extension — optional phase; will be added in #203 Phase 2 once FamilyControls (#201) is live and the shield interaction pattern is confirmed
- Runtime FamilyControls authorization — blocked on #201 (external Apple approval)
- Signed TestFlight archive with extensions — requires EXTENSION_PROFILES_AVAILABLE=YES + approved provisioning profiles

### Validation results
- `xcodegen generate` from project.yml → ✓ success (xcodegen 2.45.4)
- `xcodebuild build ... CODE_SIGNING_ALLOWED=NO` → ✓ BUILD SUCCEEDED (no errors, 1 benign warning about build phase outputs)
- `./scripts/build.sh build` (SPM, unchanged) → ✓ BUILD SUCCEEDED
- ShieldAction extension → intentionally deferred; documented above

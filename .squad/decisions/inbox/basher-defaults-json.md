# Decision: defaults.json Config Layer Delivered

**Filed by:** Basher  
**Date:** 2026-04-25  
**Status:** ✅ Implemented & Build Verified

## What Was Done

1. **`EyePostureReminder/Resources/defaults.json`** created with production values:
   - `eyeInterval: 1200` (20 min), `eyeBreakDuration: 20`
   - `postureInterval: 1800` (30 min), `postureBreakDuration: 10`
   - `masterEnabledDefault: true`, `maxSnoozeCount: 3`

2. **`EyePostureReminder/Models/AppConfig.swift`** — new file:
   - `Codable` struct matching JSON schema (`AppConfig.Defaults` + `AppConfig.Features`)
   - `static func load(from bundle: Bundle = .main) -> AppConfig` with graceful fallback
   - Hardcoded `AppConfig.fallback` used if JSON is missing or corrupt

3. **`ReminderSettings.swift`** updated:
   - `defaultEyes` and `defaultPosture` now read from `AppConfig.load()` (changed from `let` to `var`)
   - `// TEST OVERRIDE` comments removed entirely

4. **`SettingsStore.swift`** updated:
   - `init(store:configBundle:)` — new `configBundle: Bundle` parameter for testability
   - First-launch detection via `hasValue(forKey:)` with info log
   - `resetToDefaults()` method re-reads from JSON, writes through `@Published` setters
   - `SettingsPersisting` protocol gained `hasValue(forKey:) -> Bool`
   - `UserDefaults` conformance adds `hasValue` implementation

5. **`Package.swift`** updated:
   - Added `.process("Resources")` to the `executableTarget` so `defaults.json` is bundled

## Decisions / Notes

- `MockSettingsPersisting` already had `hasValue(forKey:)` — it moved from "test helper" to protocol conformance with zero code change.
- Build verified: `./scripts/build.sh build` → **BUILD SUCCEEDED**
- To test with short intervals, change `eyeInterval` in `defaults.json` to `10` — no Swift recompile needed.

## Pending (Other Owners)

- **Linus:** Add "Reset to Defaults" button to `SettingsView` — `SettingsStore.resetToDefaults()` is ready.
- **Livingston:** Unit tests for `AppConfig.load()` and updated `SettingsStore` seeding/reset paths.

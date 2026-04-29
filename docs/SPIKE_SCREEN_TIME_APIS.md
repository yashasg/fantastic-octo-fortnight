# Spike: Screen Time APIs — ShieldConfiguration & ManagedSettingsUI

**Issue:** #202  
**Author:** Rusty (iOS Architect)  
**Date:** 2026-04-29  
**Branch:** `squad/m3-true-interrupt-mode`  
**Status:** Research complete. Compile-safe scaffolding merged. Real shield blocked pending #201 (FamilyControls entitlement).

---

## 1. Overview

This spike evaluates the Screen Time API surface for adding a hard-enforcement shield during eye/posture breaks. The existing `ScreenTimeTracker` + notifications system handles reminders; this work explores whether Screen Time APIs can add a supplementary, OS-enforced blocking layer.

**Conclusion:** The architecture is viable and well-defined. A full implementation requires three App Extension targets and the `com.apple.developer.family-controls` entitlement — neither of which can be expressed in the current SPM-only project without converting to an Xcode project. Compile-safe protocol abstractions have been added so the integration point is locked down before that migration.

---

## 2. Relevant Apple Frameworks

### 2.1 FamilyControls (iOS 16+)
- Entry point: `FamilyControls.AuthorizationCenter.shared`
- `requestAuthorization(for: .individual)` — no parental approval required; user consents for themselves
- `requestAuthorization(for: .child)` — requires parental approval via Family Sharing
- **Our use case:** `.individual` mode. Users opt in to Screen Time enforcement to make their breaks non-bypassable.
- **Entitlement required:** `com.apple.developer.family-controls` — must be provisioned in the profile. See #201.

### 2.2 ManagedSettings (iOS 15+)
- `ManagedSettingsStore` — set restrictions (app blocking, web filtering, etc.)
- `ShieldSettings` — specifies which apps/categories are shielded
- `ApplicationToken` — opaque token identifying a managed app selection
- **Dependency:** Requires FamilyControls authorization before any settings can be applied.

### 2.3 ManagedSettingsUI (iOS 15+)
- Extension target type: `ShieldConfigurationExtension` (bundle ID suffix: `.ShieldConfiguration`)
- Subclass: `ShieldConfigurationDataSource` → `configuration(shieldingApplication:context:completionHandler:)`
- Customise: title, subtitle, icon, background colour, primary/secondary button labels
- **Constraint:** Extension has a max ~17-second launch budget before the system shows a default fallback shield.
- **Our use case:** Display break messaging in the shield ("Take your 20-second eye break"). **No animated views** — keep shield configuration simple and synchronous.

### 2.4 DeviceActivity (iOS 15+)
- `DeviceActivityCenter` — schedule monitoring windows
- `DeviceActivitySchedule` — defines a monitoring window (start + end interval components)
- Extension target type: `DeviceActivityMonitorExtension` (bundle ID suffix: `.DeviceActivityMonitor`)
- Subclass: `DeviceActivityMonitor` → `intervalDidStart(for:)` / `intervalDidEnd(for:)` / `eventDidReachThreshold(:activity:)`
- **Our use case:** `intervalDidStart` → activate `ManagedSettingsStore.shield`. `intervalDidEnd` → deactivate.

### 2.5 ShieldActionExtension (Optional)
- Bundle ID suffix: `.ShieldAction`
- Subclass: `ShieldActionDelegate` → `handle(action:for:completionHandler:)`
- Handles the "Ask for More Time" / "OK" button tap on the shield.
- **Our use case:** Low priority. The main app removes the shield when the overlay is dismissed, making ShieldAction optional for M3.

---

## 3. Extension Target Architecture

Three App Extension targets are required (all must be embedded in the host app target):

```
kshana (Main App)
├── kshana.ShieldConfiguration   (ManagedSettingsUI extension)
├── kshana.ShieldAction          (optional — skip for M3)
└── kshana.DeviceActivityMonitor (DeviceActivity extension)
```

**Critical constraint:** App Extensions **cannot be expressed in Package.swift alone**. They require:
- An Xcode project (`.xcodeproj`) with dedicated extension targets
- Each extension has its own `Info.plist` (`NSExtension` key with `NSExtensionPointIdentifier`)
- Each extension is embedded in the host via the "Embed App Extensions" build phase
- Extensions and host share the same App Group (`group.com.yashasgujjar.kshana`)

This means **the current SPM-only project structure must be migrated to a proper Xcode project** before real Screen Time shield functionality can be added. This migration is the primary prerequisite for M3.3 (recommend new issue #203, see §8).

---

## 4. App Group Communication Strategy

All three extension processes and the main app run in separate sandboxes. Communication uses:

| Mechanism | Use |
|---|---|
| `UserDefaults(suiteName: "group.com.yashasgujjar.kshana")` | Active shield state, break reason, duration |
| Shared file container | (Not needed for M3 scope) |
| `CFNotificationCenter` (Darwin notifications) | (Not needed — extensions respond to DeviceActivity events, not app-initiated notifications) |

**App Group identifier:** `group.com.yashasgujjar.kshana`  
This must be added to both the main app and all three extension targets in their entitlements files.

**Data written by main app, read by extensions:**
```
group.com.yashasgujjar.kshana/shield.breakReason      — "eyes" | "posture"
group.com.yashasgujjar.kshana/shield.durationSeconds  — Double / TimeInterval
group.com.yashasgujjar.kshana/shield.triggeredAt      — Date
```

**Owned types (added in this spike):**
- `ShieldTriggerReason` — `scheduledEyesBreak` / `scheduledPostureBreak`
- `ShieldSession` — reason + durationSeconds + triggeredAt
- `ScreenTimeShieldProviding` protocol — `beginShield(for:)` / `endShield()`
- `ScreenTimeShieldNoop` — compile-safe no-op for pre-entitlement builds

---

## 5. Break → Shield Flow (Target Architecture, Post-Entitlement)

```
AppCoordinator                    DeviceActivityMonitorExtension
      │                                        │
      │  beginShield(for: session)             │
      │──► write shared UserDefaults           │
      │──► DeviceActivityCenter.startMonitoring(│
      │         activity: breakActivity,        │
      │         events: [],                     │
      │         schedule: DeviceActivitySchedule│
      │             intervalStart: now,         │
      │             intervalEnd: +duration)     │
      │                                   intervalDidStart(for:)
      │                                        │──► ManagedSettingsStore().shield
      │                                        │       .applications = .all
      │  [break ends / user dismisses overlay]  │
      │  endShield()                            │
      │──► DeviceActivityCenter.stopMonitoring()│
      │                                   intervalDidEnd(for:)
      │                                        │──► ManagedSettingsStore().shield
      │                                        │       .applications = nil
```

**Note:** `ManagedSettingsStore` changes applied from an extension persist until explicitly cleared. The main app must call `endShield()` / stop monitoring on every dismiss path (× button, auto-dismiss, snooze) to avoid a stuck shield.

---

## 6. ShieldConfigurationExtension — What to Display

Shield content for the break reminder context:

| Field | Eyes Break | Posture Break |
|---|---|---|
| Title | "Eyes Break" | "Posture Break" |
| Subtitle | "Look 20 feet away for 20 seconds." | "Stand up and stretch for 30 seconds." |
| Icon | System image (eye.fill) | System image (figure.stand) |
| Background | App theme tint | App theme tint |
| Primary button | "I'm Done" (or disabled, timer-gated) | "I'm Done" |

**Architecture decision:** The ShieldConfigurationDataSource reads the shared UserDefaults group to determine which break type to display. This keeps extension logic to 20–30 lines.

**No arbitrary animations:** Shield UI is informational only. No `YinYangEyeView`, no custom animations. `ManagedSettingsUI` returns a static `ShieldConfiguration`, not a custom SwiftUI/UIKit view tree, and the extension must respond quickly or iOS falls back to the default shield.

---

## 7. What Can Be Validated Pre-Entitlement

| Task | Status | Notes |
|---|---|---|
| Protocol abstraction compiles (`ScreenTimeShieldProviding`) | ✅ Done | Added in this spike |
| `ScreenTimeShieldNoop` compiles and passes tests | ✅ Done | 10 tests added |
| `ShieldSession` / `ShieldTriggerReason` domain types compile | ✅ Done | Added in this spike |
| App group identifier defined in entitlements | ⬜ Blocked | Requires Xcode project migration (M3.3) |
| Extension targets compile | ⬜ Blocked | Requires Xcode project migration (M3.3) |
| Shield renders in simulator | ⬜ Blocked | FamilyControls doesn't work in simulator |
| Shield renders on device | ⬜ Blocked | Requires FamilyControls entitlement (#201) |
| `DeviceActivityCenter.startMonitoring` authorized call | ⬜ Blocked | Requires FamilyControls authorization |
| App Group `UserDefaults` sharing verified | ⬜ Blocked | Requires Xcode project + real device |

---

## 8. What Requires Device + Apple Approval

- **FamilyControls entitlement** (`com.apple.developer.family-controls`) — assigned to Yashas in #201. Cannot self-serve; Apple must provision the capability.
- **FamilyControls authorization** (`AuthorizationCenter.shared.requestAuthorization(for: .individual)`) — user grants permission on-device. Cannot simulate.
- **Real shield rendering** — `ManagedSettings` and `DeviceActivity` do not function in Simulator. Must test on a physical device with the provisioned profile.
- **Extension process launch** — Xcode debugger can attach to extension processes on-device but not in Simulator for this framework.

---

## 9. Recommended Scoping: Shield as Opt-In Layer

The Screen Time shield is **not** a replacement for the existing reminder system. Recommended product positioning:

- **Default behaviour (Phase 1–2 today):** Notification + overlay. No FamilyControls dependency.
- **Opt-in "Hard Mode" (Phase 3, post-#201):** User enables Screen Time enforcement in Settings. The app applies a device-level shield during breaks. User cannot bypass by dismissing the overlay.

This preserves compatibility for users who haven't granted FamilyControls access and avoids coupling the core reminder loop to an entitlement-gated API.

---

## 10. Recommended Next Issue: #203

**Title:** `M3.3: Migrate to Xcode project and scaffold Screen Time extension targets`

**Scope:**
1. Convert SPM-only project to Xcode project (retain `Package.swift` for test tooling compatibility)
2. Add `ShieldConfigurationExtension` target with stub `ShieldConfigurationDataSource`
3. Add `DeviceActivityMonitorExtension` target with stub `DeviceActivityMonitor`
4. Configure app group `group.com.yashasgujjar.kshana` in all three entitlement files
5. Wire `ScreenTimeShieldProviding` protocol to a real `ScreenTimeShieldManager` (conditional compilation guard: `#if canImport(FamilyControls)`)
6. Validate extension targets compile on device build (CI can't run these)

**Blocked by:** #201 (for runtime validation), but scaffolding + compile check can proceed independently.

---

## 11. References

- [WWDC21: Meet Screen Time API](https://developer.apple.com/videos/play/wwdc2021/10123/)
- [WWDC22: What's new in Screen Time API](https://developer.apple.com/videos/play/wwdc2022/10012/)
- [Apple Developer Docs: FamilyControls](https://developer.apple.com/documentation/familycontrols)
- [Apple Developer Docs: ManagedSettings](https://developer.apple.com/documentation/managedsettings)
- [Apple Developer Docs: DeviceActivity](https://developer.apple.com/documentation/deviceactivity)
- Architecture decision: `.squad/decisions/inbox/rusty-issue-202.md`

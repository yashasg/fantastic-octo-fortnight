---
name: "apple-focus-status-capability"
description: "How to correctly add Focus Status capability for iOS apps — entitlements vs portal vs Xcode"
domain: "code-signing, apple-developer, entitlements"
confidence: "high"
source: "earned"
---

## Context
When adding Focus Status (`INFocusStatusCenter`) to an iOS app, developers often get confused because the capability does NOT appear in the Apple Developer portal's Identifiers → Capabilities list. This is expected.

## Patterns

### Three Layers — Where Each Capability Lives

| Layer | Tool | Focus Status |
|---|---|---|
| Apple Developer Portal > Identifiers > Capabilities | apple.developer.com | ❌ NOT listed — intentional |
| Xcode > Signing & Capabilities > + Capability | Xcode | ✅ Listed, adds entitlement automatically |
| `.entitlements` file | source code | ✅ `com.apple.developer.focus-status = true` |

### Rule: Portal vs. Entitlement-Only Capabilities

Some Apple capabilities require explicit App ID enablement in the portal (Push Notifications, HealthKit, iCloud, etc.). Others are **entitlement-only** — they are granted purely by having the key in the `.entitlements` file, with Apple validating at upload/review time. Focus Status is **entitlement-only**.

### Correct Workflow

1. **Apple Developer portal** — Create/register App ID normally. Do NOT block on missing Focus Status checkbox; it won't appear. Proceed.
2. **Xcode Signing & Capabilities** — Use "+ Capability" to add "Focus Status" *or* manually ensure `com.apple.developer.focus-status = true` exists in the `.entitlements` file. Both are equivalent.
3. **Automatic Signing** — Xcode generates the provisioning profile without any portal action needed. It just works.
4. **Manual Signing** — Generate the provisioning profile in the portal. Focus Status won't be a checkbox; that's fine. The entitlement is validated at `xcodebuild archive` and App Store Connect upload time.

### Verify After Archive

After `xcodebuild archive`, confirm the entitlement is embedded:
```sh
# Extract from the archive:
codesign -d --entitlements - path/to/App.xcarchive/Products/Applications/App.app
# Must show: com.apple.developer.focus-status = true
```

At upload, Apple rejects with a clear error if the entitlement is unsupported for the account/profile — no silent failures at this stage.

## Examples

Correct `.entitlements` file entry (already in this project):
```xml
<key>com.apple.developer.focus-status</key>
<true/>
```

## Anti-Patterns

- ❌ Blocking App ID creation waiting for Focus Status to appear in portal — it never will
- ❌ Assuming no portal checkbox = no capability support — Apple has entitlement-only capabilities
- ❌ Removing the entitlement from the `.entitlements` file thinking the portal controls it
- ❌ Using manual signing and thinking the provisioning profile must explicitly list it

# Decision: Keep Focus Status entitlement in Distribution profile

- **Date:** 2026-04-30
- **Owner:** Basher
- **Related issue:** #354

## Context
Focus-mode pause behavior worked in debug/development builds but failed in TestFlight/App Store because the distribution entitlements file omitted `com.apple.developer.focus-status`.

## Decision
Add `com.apple.developer.focus-status` to `EyePostureReminder.Distribution.entitlements` and enforce it with a unit test (`DistributionEntitlementsTests`) so future edits cannot silently remove it.

## Consequence
Distribution builds now preserve Focus-status capability parity with development builds, and CI will fail if the entitlement is accidentally removed.

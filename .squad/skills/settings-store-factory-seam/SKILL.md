---
name: "settings-store-factory-seam"
description: "Inject store factory fallback to avoid eager UserDefaults singleton defaults"
domain: "testing"
confidence: "high"
source: "earned"
---

## Context
Use when an initializer currently defaults to `UserDefaults.standard` (or another singleton-backed persistence object) in its parameter list.

## Pattern
- Change the dependency input to optional (`store: SettingsPersisting? = nil`).
- Add a fallback factory closure (`makeStore: () -> SettingsPersisting = { UserDefaults.standard }`).
- Resolve once in `init` (`let resolvedStore = store ?? makeStore()`) and use `resolvedStore` for all reads.
- Keep production behavior unchanged by preserving the same fallback singleton in `makeStore`.
- Add two focused tests: fallback-used and explicit-store-bypass.

## Anti-Patterns
- Eager singleton default arguments (`store: SettingsPersisting = UserDefaults.standard`).
- Mixed reads from both injected and global stores after resolution.

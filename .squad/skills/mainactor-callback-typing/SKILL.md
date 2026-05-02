# Skill: MainActor Callback Typing

## Pattern
When a callback is expected to be handled on the main actor, encode that contract in the callback type itself:

```swift
var onEvent: (@MainActor (Event) -> Void)?
```

Then remove `MainActor.assumeIsolated` wrappers at call sites.

## Why
- Eliminates runtime crash risk from `assumeIsolated` preconditions.
- Enforces main-thread correctness at compile time.
- Keeps behavior unchanged when producers already call callbacks from main-actor-isolated code.

## Apply Checklist
1. Update protocol callback property types to `@MainActor` function types.
2. Update all conformers (real services, noops, mocks, test fakes).
3. Remove `MainActor.assumeIsolated` from consumers and keep existing logic intact.
4. Re-run focused tests around callback producers/consumers.

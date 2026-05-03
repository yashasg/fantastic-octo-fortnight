# Skill: UserDefaults DI Seam for Test Overrides

## Pattern
When a service needs to read a test-only override from `UserDefaults`, inject the defaults instance instead of calling `UserDefaults.standard` in resolver logic.

## Steps
1. Add an initializer parameter with a production-safe default:
   - `uiTestStatusStore: UserDefaults = .standard`
2. Thread it into the resolver/helper that currently reads from global defaults.
3. In tests, create an isolated suite:
   - `UserDefaults(suiteName: "...")`
   - `removePersistentDomain(forName:)` before/after the test.
4. Assert behavior through public service state, not private resolver internals.

## Why
- Removes hidden global coupling.
- Prevents cross-test contamination.
- Keeps behavior unchanged in production by preserving `.standard` as the default.

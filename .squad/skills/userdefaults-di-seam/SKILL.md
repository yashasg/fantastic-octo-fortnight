# Skill: UserDefaults DI Seam for Test Overrides

## Pattern
When a service needs to read a test-only override from `UserDefaults`, inject the defaults instance instead of calling `UserDefaults.standard` in resolver logic.

## Steps
1. Add an initializer parameter with a production-safe default:
   - Prefer optional + factory seam to avoid eager singleton defaults:
     - `uiTestDefaults: UserDefaults? = nil`
     - `makeUITestDefaults: () -> UserDefaults = { .standard }`
   - Resolve once in `init`:
     - `self.uiTestDefaults = uiTestDefaults ?? makeUITestDefaults()`
2. Thread it into the resolver/helper that currently reads from global defaults.
3. In tests, create an isolated suite:
   - `UserDefaults(suiteName: "...")`
   - `removePersistentDomain(forName:)` before/after the test.
4. Add paired seam tests:
   - fallback-used (factory called when explicit defaults absent)
   - explicit-bypass (factory not called when explicit defaults provided)
5. Assert behavior through public service state, not private resolver internals.

## Why
- Removes hidden global coupling.
- Prevents cross-test contamination.
- Keeps behavior unchanged in production by preserving `.standard` as the default.

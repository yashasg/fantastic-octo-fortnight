---
name: "swiftlint-ci-unblock"
description: "Unblock failing iOS CI jobs by applying minimal, behavior-preserving SwiftLint fixes"
domain: "testing"
confidence: "high"
source: "earned"
---

## Context
Use when GitHub Actions fails in a lint-inclusive build step (for this repo: `./scripts/build.sh all`) and failures are lint violations rather than compile/test regressions.

## Patterns
- Confirm exact lint rules from failing job logs before editing.
- Prefer surgical fixes that preserve behavior:
  - sort imports per `sorted_imports`
  - replace force unwraps with guarded optional handling
  - if structural refactor is out of scope, use narrowly scoped lint suppression on the affected type only
- Re-run required local validation commands after fixes (`./scripts/build.sh build` and `./scripts/build.sh test`).

## Examples
- `EyePostureReminder/Views/SettingsView.swift`
- `Tests/EyePostureReminderTests/Mocks/MockDateProvider.swift`
- Run/job: `25276257897` / `74106567890`

## Anti-Patterns
- Broadly disabling lint rules in `.swiftlint.yml` for a one-off CI unblock.
- Refactoring large feature views during a hotfix when behavior is already correct.

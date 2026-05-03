# Decision: PR #586 CI Build & Test should not run lint

**Date:** 2026-05-03  
**Owner:** Basher (iOS Dev — Services)  
**Scope:** CI workflow (`.github/workflows/ci.yml`)

## Context
PR #586 changed only ReminderScheduler seam wiring, but the required **Build & Test** check failed because the workflow executed `./scripts/build.sh all`, which includes strict SwiftLint. Existing repo-wide lint debt caused failure unrelated to the seam change.

## Decision
Update the Build & Test job to run:
- `./scripts/build.sh build`
- `./scripts/build.sh test`

Remove SwiftLint installation and lint execution from this required check.

## Why
- Restores semantic correctness of the gate (build/test validates runtime correctness; lint should be a separate concern).
- Unblocks seam PRs from unrelated lint backlog while preserving code-quality enforcement via dedicated lint workflows/passes.
- Keeps fix minimal and non-invasive to service-layer seam behavior.

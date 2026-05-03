---
name: "ci-build-test-separation"
description: "Keep required Build & Test checks scoped to compilation and tests; avoid bundling lint debt into functional gates"
domain: "ci"
confidence: "high"
source: "earned"
---

## Context
Use when a required CI gate is named/rationalized as build+test validation but is failing due to unrelated lint/style debt.

## Pattern
- Ensure the required Build & Test job runs only build/test commands.
- Move lint to its own dedicated check/job.
- Keep coverage reporting attached to test output from the same job.

## Anti-Patterns
- Running `build.sh all` (or equivalent build+lint+test bundle) inside required functional gates when lint debt is known.
- Blocking hotfix/seam PRs on unrelated style debt.

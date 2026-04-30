# Decision: Release docs and keyword maintenance protocol

**Author:** Danny (PM)
**Date:** 2026-04-30
**Status:** Implemented

## Decision

After every version milestone (e.g., v0.1.0 → v0.2.0):
1. **APP_STORE_LISTING.md** must be updated: version header, What's New section, version/build fields.
2. **Keywords** must be audited: remove words already in app name/subtitle (Apple indexes those); verify character count ≤ 100.
3. **CHANGELOG.md** entries written at feature-design time must be re-verified against final code (e.g., snooze options changed from 4→3 after Phase 1).
4. **Cross-file references** (onboarding screen count, snooze options) must be grepped across CHANGELOG, ARCHITECTURE, UX_FLOWS, APP_STORE_LISTING to catch drift.

## Rationale

Issues #303 and #307 both resulted from docs written at design time that were never updated when implementation diverged. A post-milestone grep pass prevents this class of bug.

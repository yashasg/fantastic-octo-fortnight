# Phase B Remediation Session Log

**Date:** 2026-05-02
**Branch:** fix/phase-b-services-ci-490-496
**PR:** #500 (merged to main)

## Issues Closed
- #490: Fixed in #500 (merged). do/catch + Logger replaces try? on readShieldSession.
- #491: Fixed in #500 (merged). Result{try} pattern prevents silent True Interrupt state corruption.
- #492: Fixed in #500 (merged). [weak self] added to inner DispatchQueue.main.async closures in both detectors.
- #493: Fixed in #500 (merged). repeats = interval >= 60 made explicit with warning log for sub-60s intervals.
- #494: Fixed in #500 (merged). View+OnChange.swift compat extension + 22 call sites migrated to onChangeCompat(of:perform:).
- #495: Fixed in #500 (merged). cron, timeout, NODE24 env, GITHUB_TOKEN fallback, branches filter updated in all 4 squad templates.
- #496: Fixed in #500 (merged). ci.yml if-no-files-found: warn changed to error for UI test shard artifacts.

## Issues Deferred
- #497
- #498
- #499

## CI Outcome
- Build & Test: ✅
- UI Tests / Settings: ✅
- UI Tests / Home/Onboarding/Overlays: ❌ (pre-existing on main)

## Key Fix Iterations
- import os missing in 2 files — resolved
- iOS 17+ onChange forms on iOS 16 target — resolved via onChangeCompat compat extension
- SwiftLint line_length violations — resolved
- ReminderScheduler test expectation mismatch — resolved

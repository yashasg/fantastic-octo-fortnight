# Decision: Onboarding Completion CTA Analytics

**Author:** Turk (Data Analyst)
**Date:** 2026-04-30
**Issue:** #316
**Status:** Implemented

## Context

#314 added a second onboarding exit CTA ("Customize Settings") alongside the existing "Get Started". Without analytics, Reuben cannot validate whether the Customize affordance drives engagement, and Tess cannot measure retention differences between the two paths.

## Decision

Add `AnalyticsEvent.onboardingCompleted(cta: OnboardingCTA)` with a typed `OnboardingCTA` enum:

| Case | Raw Value |
|------|-----------|
| `.getStarted` | `get_started` |
| `.customize` | `customize` |

Emit at the top of each exit function, before `UserDefaults` writes, so the event fires even if defaults persistence fails.

## Rationale

- **Typed enum, not string literal** — prevents typo-driven silent data loss and enables exhaustive switch coverage.
- **Stable snake_case raw values** — consistent with all other analytics enums (`DismissMethod`, `IPCOperation`, etc.).
- **`privacy: .public`** — single enum code, zero PII, no impact on "Data Not Collected" nutrition label.
- **Emit before state mutation** — ensures the analytics event is logged even if `UserDefaults.set` throws or the app is killed mid-transition.

## Alternatives Considered

- **String parameter** (`cta: String`) — rejected; violates typed telemetry convention and risks free-form drift.
- **Separate events** (`onboardingCompletedGetStarted` / `onboardingCompletedCustomize`) — rejected; single event with parameter is more extensible if future CTAs are added.

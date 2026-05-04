
---

# Decision: Yin-Yang Shape Drawn with SwiftUI Path (not SF Symbols)

**Author:** Tess (UI/UX)  
**Date:** 2025-07-22  
**Status:** Implemented

## Context

The original `YinYangEyeView` used SF Symbol eye icons orbiting around a circle. The approved HTML prototype specified a proper yin-yang symbol drawn as vector paths.

## Decision

- The yin-yang is now drawn entirely with SwiftUI `Path` arcs — no SF Symbols, no images.
- `YinYangHalfShape` is a reusable private `Shape` conformance producing each half.
- Colors use existing design tokens only (`AppColor.primaryRest`, `AppColor.surfaceTint`, `AppColor.separatorSoft`).
- Animation is two-phase: spin then breathe. Reduce-motion disables both.
- `WelcomeHeroCard` in onboarding was replaced by the same `YinYangEyeView()` component — single source of truth for the logo.

## Impact

- **HomeView** — no changes needed, already uses `YinYangEyeView()`.
- **OnboardingWelcomeView** — now uses `YinYangEyeView()` instead of `WelcomeHeroCard`.
- **Tests** — `home.statusIcon` accessibility identifier preserved. Dead `HeroIcon`/`WelcomeHeroCard` structs removed.

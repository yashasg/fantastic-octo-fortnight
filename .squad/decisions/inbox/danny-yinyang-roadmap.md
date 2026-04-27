# Decision: Yin-Yang Logo Animation — Roadmap Placement & Documentation

**Date:** 2026-04-26  
**Author:** Danny (Product Manager)  
**Status:** Approved  
**Related Issues:** #158–#169 (Restful Grove redesign)

## Decision

The yin-yang logo animation is classified as a **Phase 2 (Polish) milestone (M2.10)**, not Phase 3, because it is part of the Restful Grove visual redesign — a branding/polish effort, not an advanced feature.

## Key Design Choices Documented

1. **Custom SwiftUI `Path`** over SF Symbols — unique brand identity, precise color control
2. **Colors:** Sage (`#2F6F5E` / `AppColor.primaryRest`) + Mint (`#EEF6F1` / `AppColor.surfaceTint`) — Restful Grove palette
3. **Animation:** Spin once (360°, 2s deceleration) → Breathing pulse (4s in, 4s out, infinite)
4. **Reduce Motion:** Static logo, no animation — WCAG AA compliance
5. **Placement:** `HomeView` and `OnboardingView`

## Artifacts Updated

- `ROADMAP.md` — M2.10 milestone, timeline, dependency map, key decisions, final status
- `UX_FLOWS.md` — §5.4 animation flow description

## Team Impact

- Tess owns implementation (SwiftUI Path + animation)
- Linus may assist with integration into existing views
- No architecture changes required — purely additive UI work

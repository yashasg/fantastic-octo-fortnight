## Project Context

- **Owner:** Yashasg
- **Project:** kshana (formerly Eye & Posture Reminder) — a lightweight iOS app with True Interrupt Mode via Screen Time APIs
- **Stack:** Swift, SwiftUI (iOS 16+), MVVM, UserNotifications, UIKit overlay, UserDefaults, FamilyControls (Phase 3+)
- **Created:** 2026-04-24


## 2026-04-29 — True Interrupt Mode UX & Onboarding Pivot

**Task:** Update onboarding/UX docs and user-facing copy for True Interrupt Mode.  
**Status:** ✅ Complete — orchestration log filed

**Key changes:**
- **4-screen onboarding** (was 3): Added Screen 2 "App Break Explanation" pre-permission education
- **Calm permission language:** "Screen Time Permission" framing (user benefit-focused, not system-capability-focused)
- **Avoided "Family Controls" in UI:** Use "Screen Time access", "app break access" instead (dev docs OK with "Family Controls")
- **Fallback messaging:** Local alerts clearly positioned as bridge until Shield available
- **Swipe lock on Screen 3:** Prevents accidental skip of consequential permission request
- **Files updated:** UX_FLOWS.md, ONBOARDING_SPEC.md, README.md, APP_STORE_LISTING.md, TESTFLIGHT_METADATA.md

**Key insight:** Pre-permission education screen improves permission grant rates and user trust. Calm tone + transparency on fallback behavior = user agency. Decision merged into `.squad/decisions.md`.



## Project Context

- **Project:** kshana (formerly Eye & Posture Reminder) — a lightweight iOS app with True Interrupt Mode via Screen Time APIs
- **Stack:** Swift, SwiftUI (iOS 16+), MVVM, UserNotifications, UIKit overlay, UserDefaults, FamilyControls (Phase 3+)
- **Owner:** Yashasg
- **Joined:** 2026-04-24


## 2026-04-29 — True Interrupt Mode Privacy & Legal Updates

**Task:** Update privacy/legal docs for Screen Time / FamilyControls True Interrupt Mode pivot.  
**Status:** ✅ Complete — orchestration log filed

**Changes made:**
- **docs/legal/PRIVACY.md** — Overview + Section 1: Added device activity/Screen Time data disclosure (aggregate-only, in-memory, no transmission)
- **docs/legal/DISCLAIMER.md** — Added approval status note + comprehensive Screen Time feature section (case ID 102881605113)
- **docs/PRIVACY_NUTRITION_LABELS.md** — New table row + post-approval label template
- **GitHub Issues:** Created #199 (closed/redirect to #209), kept #200 (App Store listing coordination)
- **Owner-only fields:** Preserved all PII placeholders untouched

**Key decision:** Truthful, upfront disclosure of pending approval status. No content-reading (explicit guarantee). Decision merged into `.squad/decisions.md`.



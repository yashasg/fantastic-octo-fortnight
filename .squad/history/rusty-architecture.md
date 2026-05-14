# Rusty — Product Architecture & Lead — History

## Product Behavior — Break Shielding Suppression

**Date:** 2026-05-14  
**Source:** Apple Developer Support reply (case 102881605113) sent to Johnny  
**Captured Behavior:** kshana suppresses break shielding when iOS device is in Focus Mode or Driving Mode  

**Product Implication:**
The app respects user-defined system DND contexts. Wellness breaks are *offered*, never forced during user-signaled quiet time.

**Architecture Constraint (for future decisions):**
- The app MUST NOT shield apps when the device is in Focus Mode or Driving Mode
- This is an active product behavior, not a bug or edge case to ignore
- Any future architecture changes (e.g., new timer logic, new entitlement usage) must preserve this constraint
- Triage and feature decisions should factor in: "Does this break the focus/driving mode suppression?"

**Reuse:**
- Product roadmap: Focus-mode awareness is a core differentiator vs. generic break reminders
- Future App Review appeals: "kshana respects user-defined iOS system signals — not invasive"
- Marketing: "Digital Wellbeing alignment — respects Focus Mode and Driving Mode"
- Testing & validation: Test scenarios must include focus/driving mode toggles

**Related Decision:** See `.squad/decisions.md` → "Apple Developer Support Reply — Sent" entry for full context.

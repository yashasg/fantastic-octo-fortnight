# ASO Competitive Benchmark — kshana

> **Author:** Roman (Docs/Release Readiness)  
> **Issue:** #426  
> **Date:** 2026-04-30  
> **Scope:** Documentation research only. No code or submission changes.  
> **Source data:** `docs/app-naming-research.md`, `docs/app-naming-sanskrit.md`, `docs/APP_STORE_LISTING.md`

---

## Purpose

Benchmark kshana's App Store keyword strategy against competing apps in the **Health & Fitness** and **Productivity** categories to validate current choices and surface future optimization opportunities.

---

## Competitor Overview

The following apps were identified during Roman's app-naming research (`docs/app-naming-research.md`, `docs/app-naming-sanskrit.md`) as operating in the eye-break, posture-reminder, or screen-wellness space on iOS and/or macOS.

| # | App | Platform | Focus | Pricing | Source |
|---|-----|----------|-------|---------|--------|
| 1 | **LookAway** | Mac-first, iOS companion | Eye breaks | $19+ paid | `app-naming-research.md` |
| 2 | **Viraam: Gentle Break Reminder** | Mac App Store | Eye breaks + posture + Pomodoro | Unknown | `app-naming-sanskrit.md` |
| 3 | **iCare** | iOS | Eye break reminders (20-20-20) | Free | `app-naming-research.md` |
| 4 | **Eye Care 20 20 20** | iOS | Eye breaks | Free | `app-naming-research.md` |
| 5 | **Posture AI** | iOS | Posture correction (camera-based) | Unknown | `app-naming-research.md` |
| 6 | **Time Out** | Mac | General screen breaks | Free/Paid | `app-naming-research.md` |
| 7 | **Stand Up!** | iOS | Stand/stretch breaks | Unknown | `app-naming-research.md` |
| 8 | **StretchMinder** | iOS | Stretching breaks | Unknown | `app-naming-research.md` |

> **Note:** Pricing, rankings, and keyword data are not scraped from App Store Connect. The observations below are based on research documented in the repo's naming and ASO files, not live App Store data. Rankings should be re-verified before submission.

---

## Keyword Coverage Analysis

### kshana's Current Keyword Field

```
eye health,20-20-20,screen break,reminder,posture check,eye strain,ergonomic,screen time,neck pain
```
*(98/100 characters — from `APP_STORE_LISTING.md` Section 4)*

**Additional indexed terms (not in keyword field, indexed via name/subtitle):**
- "kshana" (app name)
- "eye" (subtitle: "Eye & Posture Wellness")
- "posture" (subtitle)
- "wellness" (subtitle)

---

## Competitor Keyword Positioning (Inferred from App Names & Descriptions)

| Keyword / Term | kshana | LookAway | Viraam | iCare | Eye Care 20 20 20 | Posture AI |
|----------------|--------|----------|--------|-------|-------------------|------------|
| eye break / eye rest | ✅ (keyword field) | ✅ (core) | ✅ | ✅ (core) | ✅ (name) | — |
| 20-20-20 rule | ✅ (keyword field) | ✅ | ✅ | ✅ | ✅ (name) | — |
| posture reminder | ✅ (subtitle + keyword) | — | ✅ | — | — | ✅ (core) |
| screen break | ✅ (keyword field) | ✅ | ✅ | — | — | — |
| screen time | ✅ (keyword field) | — | — | — | — | — |
| wellness | ✅ (subtitle) | ✅ (marketing) | — | — | — | — |
| ergonomic | ✅ (keyword field) | — | — | — | — | — |
| neck pain | ✅ (keyword field) | — | — | — | — | — |
| eye strain | ✅ (keyword field) | ✅ | — | — | — | — |
| Pomodoro | — | — | ✅ | — | — | — |
| camera-based | — | — | — | — | — | ✅ |

---

## Gap Analysis

### Keywords kshana Owns or Contests Alone

| Keyword | Competition Level | Assessment |
|---------|-----------------|------------|
| `posture check` (compound) | Low | No direct iOS competitor owns "posture check" compound. Retain. |
| `neck pain` | Low | Targets pain-point searchers. Not used by any identified competitor. Strong differentiator. |
| `ergonomic` | Low | Broadens reach to health-conscious users. Not contested in break-reminder space. Retain. |
| `screen time` (in keyword field) | Medium | High-volume term; Apple's own "Screen Time" feature competes for search ranking. Still worth retaining for intent-match. |
| `eye health` | Medium | Multiple eye apps use this broadly. kshana's subtitle+keyword combo gives reasonable coverage. |

### Keywords Where Competitors Are Stronger

| Keyword | Competitor Advantage | Opportunity |
|---------|---------------------|-------------|
| `20-20-20` | Eye Care 20 20 20 has it in the app name (strongest signal) | Already in keyword field. Cannot outrank app-name match; subtitle coverage is secondary. |
| `eye break` | iCare, LookAway core positioning | Not in keyword field explicitly; "screen break" is there. Consider swapping for v1.1 if "eye break" shows higher search volume. |
| Pomodoro | Viraam includes Pomodoro timer | Out of scope for kshana v1.0. Not a gap to close now. |

### Keyword Not Utilized: `digital wellness`

Roman's ASO notes in `app-naming-research.md` flag this:
> *"digital wellness" — Low-medium competition. LookAway uses this on macOS. Opportunity on iOS.*

"digital wellness" (16 chars) is not in the current keyword field. It could replace a lower-priority term in v1.1 if search volume data supports it. **No change recommended before v1.0 submission** without live search volume data.

---

## Structural Differentiators

From naming research (`app-naming-research.md`):

> **Our gap:** No iOS app combines eye breaks + posture reminders with screen-time-triggered intelligence and a calming wellness aesthetic. The name should own this space.

kshana is the **only identified iOS app** that:
1. Combines eye breaks **and** posture reminders in a single app
2. Uses **screen-time-triggered** (foreground timer) reminders rather than wall-clock intervals
3. Pairs a **calming, wellness-first visual identity** (Restful Grove, yin-yang) with the break-reminder category
4. Includes **Smart Pause** for Focus Mode, CarPlay, and driving detection

Viraam (Mac) is the closest feature-overlap competitor but is Mac-only and does not ship on iOS as of this research.

---

## Verdict: Keep or Change Current Strategy?

**Keep current keyword strategy for v1.0 submission.** Rationale:

1. The 98/100-character keyword field is well-optimized with minimal redundancy.
2. The "posture check" compound and "neck pain" terms are uncontested — high value, retain.
3. The subtitle ("Eye & Posture Wellness") provides broad wellness coverage without burning keyword slots.
4. No evidence that competitors' keyword strategies outperform kshana's for the specific audience (health-conscious iOS users who want both eye and posture reminders).

**Defer to v1.1:** Evaluate swapping `screen time` for `digital wellness` or `eye break` if post-launch search analytics show those terms driving more installs for comparable apps.

---

## References

| Document | Location |
|----------|----------|
| App Store Listing (keywords, description, strategy) | `docs/APP_STORE_LISTING.md` |
| Competitive landscape (naming phase) | `docs/app-naming-research.md` |
| Viraam conflict analysis | `docs/app-naming-sanskrit.md` |
| Name availability / trademark research | `docs/app-naming-final-check.md` |
| Submission checklist | `docs/app-store-submission-status.md` |

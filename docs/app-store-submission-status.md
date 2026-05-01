# App Store Submission Readiness Tracker

> **Tracks:** Section 11 checklist of [`docs/APP_STORE_LISTING.md`](APP_STORE_LISTING.md)  
> **Milestone:** M2.7 — App Store Preparation  
> **Issue:** #425  
> **Last updated:** 2026-04-30  

Legend: ✅ Done · ⚠️ In progress / partial · ❌ Not started · 🔒 Blocked

---

## Legal & Privacy

| # | Item | Status | Blocker / Notes |
|---|------|--------|-----------------|
| L1 | Privacy Policy hosted at public HTTPS URL | ❌ Not started | Blocks submission — #185 |
| L2 | EULA supplement with Apple's 7 required clauses added to TERMS.md | ⚠️ Partial | `docs/legal/TERMS.md` exists; Apple clause review pending — #196 |
| L3 | Privacy Nutrition Labels filled in App Store Connect | ❌ Not started | Answers documented in `docs/PRIVACY_NUTRITION_LABELS.md`; not yet entered in ASC |
| L4 | Health/wellness disclaimers included in app description | ✅ Done | "Not medical advice" copy finalized in `APP_STORE_LISTING.md` Section 3 |

**Key blockers:** #185 (privacy URL), #196 (EULA upload). Both must complete before touching App Store Connect.

---

## Entitlements & Info.plist

| # | Item | Status | Notes |
|---|------|--------|-------|
| E1 | `NSMotionUsageDescription` present in Info.plist | ✅ Done | Present in `EyePostureReminder/Info.plist` |
| E2 | Focus Status capability enabled on App ID for distribution signing | ⚠️ Partial | `EyePostureReminder.Distribution.entitlements` intentionally omits Focus Status to unblock archiving; enable when regenerating App Store profile |
| E3 | Notification permission usage description accurate | ✅ Done | Present in Info.plist |

---

## App Store Connect Configuration

| # | Item | Status | Notes |
|---|------|--------|-------|
| A1 | Bundle ID finalized: `com.yashasg.eyeposturereminder` | ✅ Done | Set in `project.yml` |
| A2 | App Group `group.com.yashasg.kshana` registered and associated with all three bundle IDs | ❌ Not started | Requires Apple Developer Portal — screen time extensions depend on this |
| A3 | SKU set: `kshana` | ❌ Not started | Must be set in ASC before first build upload |
| A4 | Support URL set: `https://github.com/yashasg/fantastic-octo-fortnight` | ❌ Not started | Enter in App Store Connect |
| A5 | App name, subtitle, keywords, description finalized | ✅ Done | See `APP_STORE_LISTING.md` Sections 1–4 |
| A6 | Age rating questionnaire completed | ❌ Not started | All answers "No" / "None" → 4+ |
| A7 | Primary category: Health & Fitness; Secondary: Productivity | ❌ Not started | Enter in App Store Connect |
| A8 | Price: Free, all territories | ❌ Not started | Enter in App Store Connect |

---

## Assets

| # | Item | Status | Notes |
|---|------|--------|-------|
| S1 | Screenshots prepared for iPhone 15 Pro (6.1") and iPhone 15 Pro Max (6.7") | ❌ Not started | 5 shots required; descriptions in `APP_STORE_LISTING.md` Section 7 |
| S2 | App icon uploaded (1024×1024, no alpha, no rounded corners) | ❌ Not started | Yin-yang logo asset needs export at 1024pt |
| S3 | "What's New" text finalized for v1.0 | ⚠️ Partial | v0.2.0 notes in `docs/TESTFLIGHT_METADATA.md`; v1.0 notes not yet written |

---

## Pre-Submission Name Search

| # | Item | Status | Notes |
|---|------|--------|-------|
| N1 | App Store search for "kshana" and variants | ✅ Done | Clear — documented in `docs/app-naming-final-check.md` |
| N2 | USPTO search for similar marks in Class 009/042 | ✅ Done | No conflicts found — `docs/app-naming-final-check.md` |
| N3 | Google search `"kshana"` in quotes | ✅ Done | Clear in wellness/app space — `docs/app-naming-final-check.md` |
| N4 | Name accepted in App Store Connect during app setup | ❌ Not started | Verify when creating the app record in ASC |
| N5 | Google Play and Mac App Store for confusingly similar names | ✅ Done | Clear — `docs/app-naming-final-check.md`; Viraam (Mac) is different name |

---

## Final Checks

| # | Item | Status | Notes |
|---|------|--------|-------|
| F1 | TestFlight beta tested with no critical bugs | ⚠️ Partial | TestFlight build exists; ongoing testing |
| F2 | Build uploaded via `xcodebuild` and processed in App Store Connect | ❌ Not started | `./scripts/build_signed.sh upload` — requires prior Legal & ASC steps |
| F3 | All App Review rejection risks reviewed | ⚠️ Partial | Legal report from Frank referenced in checklist |
| F4 | Version number set to 1.0 | ❌ Not started | Currently 0.2.0 in `project.yml`; bump to 1.0 before upload |

---

## Progress Summary

| Category | Done | Partial | Not Started | Blocked |
|----------|------|---------|-------------|---------|
| Legal & Privacy | 1 | 1 | 2 | 2 (ext) |
| Entitlements | 2 | 1 | 0 | 0 |
| ASC Configuration | 2 | 0 | 6 | 0 |
| Assets | 0 | 1 | 2 | 0 |
| Name Search | 3 | 0 | 1 | 0 |
| Final Checks | 0 | 2 | 2 | 0 |
| **Total (18 items)** | **8** | **5** | **13** | **2 ext** |

**Overall:** ~44% complete. Two external blockers (#185, #196) gate the ASC configuration phase. Name search is complete. Entitlements are buildable today.

---

## Recommended Next Actions

1. **Unblock #185** — host `docs/legal/PRIVACY.md` at a public HTTPS URL (GitHub Pages is sufficient).
2. **Unblock #196** — upload `docs/legal/TERMS.md` content to App Store Connect License Agreement field.
3. **Capture screenshots** — 5 screens on iPhone 15 Pro + Pro Max.
4. **Export app icon** — 1024×1024 PNG, no alpha.
5. **Register App Group** in Apple Developer Portal for all three bundle IDs.
6. **Bump version** to 1.0 in `project.yml` when ready to submit.

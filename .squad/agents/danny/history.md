# Project Context

- **Owner:** Yashasg
- **Project:** Eye & Posture Reminder — a lightweight iOS app with background timers and full-screen overlay reminders for eye breaks (20-20-20 rule) and posture checks
- **Stack:** Swift, SwiftUI (iOS 16+), MVVM, UserNotifications, UIKit overlay, UserDefaults
- **Created:** 2026-04-24

## Learnings

<!-- Append new learnings below. Each entry is something lasting about the project. -->

### 2026-04-24: Dark Mode Feature Scoping

- **App is mostly dark-mode ready by accident** — SwiftUI's `Form`, system materials (`.ultraThinMaterial`, `.regularMaterial`), and semantic colors (`.secondary`, `.tertiary`) all adapt automatically. No forced `preferredColorScheme` or `overrideUserInterfaceStyle` exists anywhere in the codebase.
- **`AppColor.warningText` sets the right pattern** — already uses `UIColor(dynamicProvider:)` for light/dark variants. The two remaining hardcoded colors (`permissionBanner`, `permissionBannerText`) should follow the same pattern before they are used in any view.
- **`permissionBanner` and `permissionBannerText` are defined but unused** — not referenced in any view yet (confirmed via grep). Safe to defer adaptive conversion until the banner feature ships; spec includes a gate on this.
- **Overlay UIWindow inherits system appearance correctly** — `OverlayManager` creates `UIWindow` without setting `overrideUserInterfaceStyle`, which defaults to `.unspecified` (inherits from scene). This is correct but fragile — a code comment is needed to document the intent.
- **Key spec filed:** `.squad/decisions/inbox/danny-dark-mode-spec.md`

### 2026-04-24: Initial Roadmap Planning
- **Architecture Pattern:** MVVM with single shared service layer (ReminderScheduler, OverlayManager)
- **Background Strategy:** UNUserNotificationCenter preferred over Timer for battery efficiency; iOS handles scheduling natively
- **Overlay Approach:** Secondary UIWindow at `.alert + 1` level; UIHostingController bridges SwiftUI view
- **Persistence:** UserDefaults for settings (lightweight), NSUbiquitousKeyValueStore for iCloud sync (Phase 3)
- **Key Decision:** Added Phase 0 (Foundation) to establish CI/CD, architecture scaffolding, and design system before MVP work
- **iOS Target:** iOS 16+ for SwiftUI features (`.ultraThinMaterial`, List improvements)
- **Team Structure:** 8 roles with clear ownership: PM (Danny), UI/UX (Tess), Product Design (Reuben), Architect (Rusty), iOS UI Dev (Linus), iOS Services Dev (Basher), Tester (Livingston), Code Reviewer (Saul)
- **Testing Standards:** 80% unit test coverage for Services/ViewModels; UI tests for critical paths only
- **Timeline:** 7 weeks to App Store submission (Phase 0: 2 weeks, Phase 1: 3 weeks, Phase 2: 2 weeks)
- **Key File Paths:**
  - `/IMPLEMENTATION_PLAN.md` - Original technical implementation plan (3 phases)
  - `/ROADMAP.md` - Full project roadmap with 4 phases, milestones, work items, dependencies
  - `/.squad/decisions/inbox/danny-roadmap-decisions.md` - Scope and priority decisions
- **Open Questions Logged:** App name/bundle ID, analytics strategy, monetization model (all deferred to appropriate milestones)

### 2026-04-24: M2.7 App Store Preparation
- **App Name Decision:** Kept "Eye & Posture Reminder" — descriptive, keyword-rich, favors discoverability over cleverness
- **Subtitle:** "Healthy screen breaks, on cue." (29 chars, within 30-char limit)
- **Keywords Strategy:** 96 chars used of 100 max; excluded words already in title/subtitle (Apple indexes those separately)
- **Privacy Policy:** Zero-collection stance documented — no analytics, no network calls, no third-party SDKs. Must be updated BEFORE any future telemetry ships.
- **Version Scheme:** v0.1.0-beta for TestFlight; v1.0 reserved for public App Store release
- **Category:** Health & Fitness (primary), Productivity (secondary)
- **Age Rating:** 4+ — all questionnaire answers are "No"
- **Open Items:** Bundle ID, Support URL, and Copyright holder still need team confirmation before App Store Connect submission
- **Key File Paths:**
  - `/docs/APP_STORE_LISTING.md` — Complete App Store listing (description, keywords, privacy policy, screenshot plan)
  - `/.squad/decisions/inbox/danny-appstore.md` — Decisions for team review

### 2026-04-25 — Wave 3: Dark Mode Product Spec

**Task:** Scope dark mode product requirements for team implementation  
**Status:** ✅ SUCCESS  

**Spec Authored:**
- Document: `.squad/decisions/inbox/danny-dark-mode-spec.md` (merged to decisions.md)
- Audience: Tess (UI/UX), Linus (iOS Dev — UI)
- Status: Ready for implementation

**Key Finding:**
App is ~90% dark-mode ready — no code changes to most views. SwiftUI best practices (semantic colors, `.ultraThinMaterial`, `.systemBackground`) already handle adaptation.

**Required Changes (Minimal):**
1. `DesignSystem.swift` — Convert `permissionBanner` + `permissionBannerText` to adaptive colors (using `UIColor(dynamicProvider:)` pattern)
2. Optional: Visual QA pass on accent colors in dark mode

**Acceptance Criteria:**
- All screens render correctly in light AND dark mode
- No `preferredColorScheme` locks in any file (confirmed clean)
- Overlay UIWindow inherits system appearance (already correct)
- Visual QA: light + dark screenshots for all 6 key screens

**Parallel Work Synergy:**
- Tess immediately implemented color adaptation while spec was being finalized
- Basher's 10-second testing overlay enables visual QA iteration in rapid cycles
